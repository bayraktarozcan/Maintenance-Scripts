# Maintenance Scripts - Python floor currency
# Compares the Python floor declared in the CI workflow with the upstream
# release calendar and, on request, bumps every declaration. Windows-native:
# Windows PowerShell 5.1 compatible, no Python runtime needed.
# Usage:
#   powershell -NoProfile -File Tools/Check-PythonFloor.ps1 -Check
#   powershell -NoProfile -File Tools/Check-PythonFloor.ps1 -Apply -Version 3.12
[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Apply,
    [string]$Version,
    [string]$CalendarUrl = 'https://peps.python.org/api/release-cycle.json',
    [string]$Root
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }

function Get-QualityPath { param([string]$RepoRoot) (Join-Path $RepoRoot '.github/workflows/quality.yml') }
function Get-DocsPath { param([string]$RepoRoot) (Join-Path $RepoRoot 'Docs/Overview-And-Setup.md') }

function Set-TlsPolicy {
    # TLS 1.3 is preferred; TLS 1.2 stays in the allowed set for hosts that
    # cannot negotiate 1.3. Never disable certificate validation.
    $names = [Enum]::GetNames([Net.SecurityProtocolType])
    if ($names -contains 'Tls13') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        return 'Tls12+Tls13'
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    return 'Tls12'
}

function Get-Calendar {
    param([string]$Url, [int]$Attempts = 3)
    $previous = [Net.ServicePointManager]::SecurityProtocol
    $null = Set-TlsPolicy
    $lastError = $null
    try {
        for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
            try {
                $data = Invoke-RestMethod -Uri $Url -TimeoutSec 30
                if ($null -eq $data -or @($data.PSObject.Properties).Count -lt 10) {
                    throw 'release calendar looks incomplete'
                }
                return $data
            } catch {
                $lastError = $_
                if ($attempt -lt $Attempts) { Start-Sleep -Seconds (1 -shl $attempt) }
            }
        }
        throw "could not fetch $Url after $Attempts attempts: $($lastError.Exception.Message)"
    } finally {
        [Net.ServicePointManager]::SecurityProtocol = $previous
    }
}

function Test-EolEntry {
    param([object]$Detail, [datetime]$Today)
    if ([string]$Detail.status -eq 'end-of-life') { return $false }
    $raw = [string]$Detail.end_of_life
    if ($raw -match '^(\d{4})-(\d{2})-(\d{2})$') {
        $eol = [datetime]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
        return ($Today -lt $eol)
    }
    if ($raw -match '^(\d{4})-(\d{2})$') {
        $year = [int]$Matches[1]
        $month = [int]$Matches[2]
        if ($month -eq 12) { $eol = [datetime]::new($year + 1, 1, 1) }
        else { $eol = [datetime]::new($year, $month + 1, 1) }
        return ($Today -lt $eol)
    }
    return $true
}

function Get-VersionKey {
    param([string]$Version)
    return @($Version.Split('.') | ForEach-Object { [int]$_ })
}

function Compare-FloorVersion {
    param([string]$Left, [string]$Right)
    $a = Get-VersionKey $Left
    $b = Get-VersionKey $Right
    for ($i = 0; $i -lt [Math]::Max($a.Count, $b.Count); $i++) {
        $x = if ($i -lt $a.Count) { $a[$i] } else { 0 }
        $y = if ($i -lt $b.Count) { $b[$i] } else { 0 }
        if ($x -lt $y) { return -1 }
        if ($x -gt $y) { return 1 }
    }
    return 0
}

function Get-SupportedFloor {
    param([object]$Calendar, [datetime]$Today)
    $supported = @()
    foreach ($property in $Calendar.PSObject.Properties) {
        if ($property.Name -notmatch '^\d+\.\d+$') { continue }
        if (Test-EolEntry -Detail $property.Value -Today $Today) { $supported += $property.Name }
    }
    if ($supported.Count -eq 0) { throw 'no supported Python version in the release calendar' }
    $best = $supported[0]
    foreach ($candidate in $supported) {
        if ((Compare-FloorVersion -Left $candidate -Right $best) -lt 0) { $best = $candidate }
    }
    return $best
}

function Get-DeclaredFloor {
    param([string]$Text)
    $match = [regex]::Match($Text, '(?m)^[ \t]*python-version:[ \t]*\|[ \t]*\r?\n[ \t]*(?<v>\d+\.\d+)')
    if (-not $match.Success) { throw 'python-version floor not found in quality.yml' }
    return $match.Groups['v'].Value
}

function Test-FloorParity {
    param([string]$RepoRoot, [string]$Floor)
    $problems = @()
    $qualityPath = Get-QualityPath $RepoRoot
    $docsPath = Get-DocsPath $RepoRoot
    if (-not (Test-Path -LiteralPath $qualityPath)) { return @('quality.yml: missing file') }
    if (-not (Test-Path -LiteralPath $docsPath)) { return @('Docs/Overview-And-Setup.md: missing file') }
    $quality = [IO.File]::ReadAllText($qualityPath)
    $docs = [IO.File]::ReadAllText($docsPath)
    $declared = Get-DeclaredFloor $quality
    if ($declared -ne $Floor) { $problems += "quality.yml: floor is $declared, expected $Floor" }
    if ($quality -notmatch '(?m)^[ \t]*3\.x[ \t]*$') { $problems += 'quality.yml: latest 3.x channel missing' }
    $expectedDoc = "Python $Floor+"
    if (-not $docs.Contains($expectedDoc)) { $problems += "Docs/Overview-And-Setup.md: missing '$expectedDoc'" }
    return $problems
}

function Set-Floor {
    param([string]$RepoRoot, [string]$Old, [string]$New)
    if ((Compare-FloorVersion -Left $New -Right $Old) -lt 0) {
        throw "refusing to downgrade Python floor from $Old to $New"
    }
    $changed = @()
    foreach ($path in @((Get-QualityPath $RepoRoot), (Get-DocsPath $RepoRoot))) {
        $original = [IO.File]::ReadAllText($path)
        $updated = [regex]::Replace(
            $original,
            '(?m)^(?<prefix>[ \t]*python-version:[ \t]*\|[ \t]*\r?\n[ \t]*)\d+\.\d+',
            '${prefix}' + $New
        )
        $updated = $updated.Replace("Python $Old+", "Python $New+")
        if ($updated -ne $original) {
            [IO.File]::WriteAllText($path, $updated)
            $changed += (Split-Path -Leaf $path)
        }
    }
    return $changed
}

function Write-GitHubOutput {
    param([string]$Name, [string]$Value)
    if (-not $env:GITHUB_OUTPUT) { return }
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "$Name=$Value"
}

function Invoke-Main {
    if ($Check -and $Apply) { throw 'Choose -Check or -Apply, not both.' }
    if (-not $Check -and -not $Apply) { $script:Check = $true }

    if ($Apply) {
        if (-not $Version -or $Version -notmatch '^\d+\.\d+$') {
            throw 'Apply requires -Version in the form 3.12'
        }
        $quality = [IO.File]::ReadAllText((Get-QualityPath $Root))
        $current = Get-DeclaredFloor $quality
        $changed = Set-Floor -RepoRoot $Root -Old $current -New $Version
        $problems = Test-FloorParity -RepoRoot $Root -Floor $Version
        if ($problems.Count -gt 0) { throw "parity problems after apply: $($problems -join '; ')" }
        Write-Host "Python floor ${current} -> ${Version}: $($changed -join ', ')"
        Write-GitHubOutput 'desired' $Version
        Write-GitHubOutput 'current' $current
        Write-GitHubOutput 'changed' 'true'
        return 0
    }

    $calendar = Get-Calendar -Url $CalendarUrl
    $desired = Get-SupportedFloor -Calendar $calendar -Today (Get-Date)
    $quality = [IO.File]::ReadAllText((Get-QualityPath $Root))
    $current = Get-DeclaredFloor $quality
    if ((Compare-FloorVersion -Left $desired -Right $current) -lt 0) {
        Write-Warning "upstream floor $desired is below declared $current; refusing to downgrade"
        $desired = $current
    }
    Write-GitHubOutput 'desired' $desired
    Write-GitHubOutput 'current' $current
    Write-GitHubOutput 'changed' $(if ($desired -ne $current) { 'true' } else { 'false' })
    Write-Host "desired=$desired current=$current"
    $problems = Test-FloorParity -RepoRoot $Root -Floor $current
    if ($problems.Count -gt 0) {
        Write-Error "floor parity problems:`n  $($problems -join "`n  ")"
        return 2
    }
    return 0
}

# Pester dot-sources this file to reach the functions; only run the CLI path
# when the file is invoked directly.
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-Main)
}
