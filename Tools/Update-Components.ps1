<#
.SYNOPSIS
    Updates global Python (pip) and Node.js (npm) packages to their latest versions.

.DESCRIPTION
    This script updates globally installed packages for Python and Node.js:
    - Python: upgrades Python runtime (via winget), upgrades pip itself, then upgrades all outdated packages via pip list --outdated
    - Node.js: upgrades Node.js runtime (via winget), upgrades npm itself, then upgrades global packages to latest

    Follows the project conventions: no elevation, per-user scope only, UTF-8 output.

.EXAMPLE
    powershell -NoProfile -File Tools/Update-Components.ps1

.EXAMPLE
    powershell -NoProfile -File Tools/Update-Components.ps1 -Check

.EXAMPLE
    powershell -NoProfile -File Tools/Update-Components.ps1 -ReportPath Logs\Update-Components\run.json
#>

[CmdletBinding()]
param(
    [switch]$Check,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'

function Get-LatestFromIndexVersions {
    param([string]$Text)
    # pip index versions output (pip 26.x): "Available versions: 26.3, 26.2.2, ..."
    $m = [regex]::Match([string]$Text, '(?im)^(?:Available versions|LATEST)\s*:\s*([^\r\n,]+)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    $m = [regex]::Match([string]$Text, '(?im)Available versions\s*:\s*([^\r\n,]+)')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Write-UpdateComponentsReport {
    param([bool]$ExecutionCompleted)
    $report = [ordered]@{
        schemaVersion       = 1
        tool                = 'Update-Components'
        timestamp           = (Get-Date).ToString('o')
        mode                = $(if ($Check) { 'check' } else { 'execute' })
        executionCompleted  = $ExecutionCompleted
        host                = [ordered]@{
            machine    = $env:COMPUTERNAME
            user       = $env:USERNAME
            psVersion  = $PSVersionTable.PSVersion.ToString()
            pipVersion = $(if (Test-Command 'py') { Get-PipVersion } else { $null })
        }
        plan                = @($script:Plan | ForEach-Object { [ordered]@{ component=$_.Component; action=$_.Action; current=$_.Current; target=$_.Target; details=$_.Details } })
        result              = @($script:Result | ForEach-Object { [ordered]@{ component=$_.Component; status=$_.Status; before=$_.Before; after=$_.After; details=$_.Details } })
        success             = (-not $script:OverallFailed)
        exitCode            = $(if ($script:OverallFailed) { 1 } else { 0 })
    }
    if (-not $ReportPath) { return $report }
    try {
        $rp = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath)
        $dir = [System.IO.Path]::GetDirectoryName($rp)
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $json = $report | ConvertTo-Json -Depth 8
        [System.IO.File]::WriteAllText($rp, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Log "JSON report written: $rp" 'INFO'
    } catch {
        Write-Log "Failed to write JSON report ($ReportPath): $($_.Exception.Message)" 'WARN'
        $script:OverallFailed = $true
    }
    return $report
}

# Plan collector (what WILL be updated - detection phase)
$script:Plan = @(
    @{ Component = 'Python runtime';     Action = 'Skip';    Current = ''; Target = ''; Details = '' }
    @{ Component = 'pip';                Action = 'Skip';    Current = ''; Target = ''; Details = '' }
    @{ Component = 'pip packages';       Action = 'Skip';    Current = ''; Target = ''; Details = '' }
    @{ Component = 'Node.js runtime';    Action = 'Skip';    Current = ''; Target = ''; Details = '' }
    @{ Component = 'npm';                Action = 'Skip';    Current = ''; Target = ''; Details = '' }
    @{ Component = 'npm packages';       Action = 'Skip';    Current = ''; Target = ''; Details = '' }
)

# Result collector (what WAS updated - execution phase)
$script:Result = @(
    @{ Component = 'Python runtime';     Status = 'Skipped'; Before = ''; After = ''; Details = '' }
    @{ Component = 'pip';                Status = 'Skipped'; Before = ''; After = ''; Details = '' }
    @{ Component = 'pip packages';       Status = 'Skipped'; Before = ''; After = ''; Details = '' }
    @{ Component = 'Node.js runtime';    Status = 'Skipped'; Before = ''; After = ''; Details = '' }
    @{ Component = 'npm';                Status = 'Skipped'; Before = ''; After = ''; Details = '' }
    @{ Component = 'npm packages';       Status = 'Skipped'; Before = ''; After = ''; Details = '' }
)

function Write-Log {

    param([string]$Message, [string]$Level = 'INFO')

    $timestamp = Get-Date -Format 'HH:mm:ss'

    if ($Level -eq 'DEBUG') {

        Write-Host "[$timestamp] $Message" -ForegroundColor DarkGray

    } elseif ($Level -eq 'WARN' -or $Level -eq 'ERROR') {

        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor Yellow

    } else {

        Write-Host "[$timestamp] $Message"

    }

}

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Run-Command {
    param([string]$Command, [string[]]$Arguments, [string]$Description)
    Write-Log "Running: $Command $($Arguments -join ' ')" 'DEBUG'
    if ($Check) {
        Write-Log "[CHECK MODE] Would run: $Command $($Arguments -join ' ')" 'INFO'
        return 0
    }
    $exitCode = 0
    $output = $null
    try {
        $output = & $Command @Arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } catch {
        $exitCode = 1
        $output = $_.Exception.Message
        Write-Log "Exception: $($_.Exception.Message)" 'ERROR'
    }
    # winget returns negative codes when no updates available - treat as success
    $wingetAlreadyUpToDateCodes = @(-1978335212, -1978335189, -1978335190, -1978335191)
    if ($exitCode -eq 0 -or ($Command -eq 'winget' -and $wingetAlreadyUpToDateCodes -contains $exitCode)) {
        Write-Log "$Description completed" 'INFO'
        return 0
    }
    # npm returns exit code 1 for warnings (e.g., blocked install scripts) - check if only warnings
    if ($Command -eq 'npm' -and $exitCode -eq 1 -and $output -match '^npm (warn|notice)') {
        Write-Log "$Description completed with warnings" 'INFO'
        return 0
    }
    if ($output) {
        $firstLine = ($output -split "`n" | Where-Object { $_.Trim() })[0]
        $msg = "$Description failed with exit code $exitCode"
        Write-Log ($msg + ": " + $firstLine) 'WARN'
    } else {
        Write-Log "$Description failed with exit code $exitCode" 'WARN'
    }
    return $exitCode
}

function ConvertFrom-WingetTable {
    param([string[]]$Lines)
    # Parses fixed-width winget table output (localized headers supported via separator alignment).
    $sepIndex = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^-{8,}') { $sepIndex = $i; break }
    }
    if ($sepIndex -lt 1) { return @() }
    $header = $Lines[$sepIndex - 1]
    $sep = $Lines[$sepIndex]
    $bounds = @()
    $m = [regex]::Matches($sep, '-+')
    foreach ($x in $m) { $bounds += [pscustomobject]@{ Start = $x.Index; End = $x.Index + $x.Length } }
    if ($bounds.Count -lt 2) { return @() }
    $cols = @()
    for ($c = 0; $c -lt $bounds.Count; $c++) {
        $start = $bounds[$c].Start
        $end = if ($c -lt $bounds.Count - 1) { $bounds[$c + 1].Start } else { [Math]::Max($header.Length, $sep.Length) }
        $len = [Math]::Max(0, [Math]::Min($end, $header.Length) - $start)
        $name = if ($len -gt 0 -and $start -lt $header.Length) { $header.Substring($start, $len).Trim() } else { '' }
        $cols += [pscustomobject]@{ Name = $name; Start = $start; End = $end }
    }
    $rows = @()
    for ($i = $sepIndex + 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        if ($line -match '^\d+\s+(upgrades?|package|yükseltme)' -or $line -match '^No installed package' -or $line -match 'bulunamad') { break }
        $obj = [ordered]@{}
        foreach ($col in $cols) {
            $start = $col.Start
            $end = [Math]::Min($col.End, $line.Length)
            $val = if ($start -lt $line.Length) { $line.Substring($start, [Math]::Max(0, $end - $start)).Trim() } else { '' }
            $key = $col.Name
            if (-not $key) { $key = "Col$($cols.IndexOf($col))" }
            $obj[$key] = $val
        }
        $rows += [pscustomobject]$obj
    }
    return $rows
}

function Get-WingetTableField {
    param([psobject]$Row, [string[]]$Names)
    if (-not $Row) { return $null }
    foreach ($n in $Names) {
        $prop = $Row.PSObject.Properties | Where-Object { $_.Name -eq $n } | Select-Object -First 1
        if ($prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) { return [string]$prop.Value }
    }
    foreach ($n in $Names) {
        $prop = $Row.PSObject.Properties | Where-Object { $_.Name -like "*$n*" } | Select-Object -First 1
        if ($prop -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) { return [string]$prop.Value }
    }
    return $null
}

function Invoke-WingetList {
    param([string[]]$Arguments)
    $raw = & winget @Arguments 2>&1
    $exit = $LASTEXITCODE
    $out = ($raw | Out-String)
    $lines = @($out -split "`r?`n")
    $noMatch = ($out -match 'No installed package found matching input criteria') -or ($out -match 'Giriş ölçütleriyle eşleşen yüklü paket bulunamad')
    $rows = @(ConvertFrom-WingetTable -Lines $lines)
    return [pscustomobject]@{ ExitCode = $exit; Output = $out; Lines = $lines; NoMatch = $noMatch; Rows = $rows }
}

function Resolve-WingetPackage {
    param([string[]]$CandidateIds, [string]$NameQuery = '', [string]$ExpectedVersion = '')
    # 1) Optional structured path: Microsoft.WinGet.Client (if installed) — most reliable.
    if (Get-Command -Name Get-WinGetPackage -ErrorAction SilentlyContinue) {
        foreach ($id in @($CandidateIds | Where-Object { $_ })) {
            try {
                $pkg = Get-WinGetPackage -Id $id -Exact -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($pkg) {
                    return [pscustomobject]@{ Found = $true; Id = [string]$pkg.Id; Name = [string]$pkg.Name; InstalledVersion = [string]$pkg.InstalledVersion; AvailableVersion = $(if ($pkg.PSObject.Properties['AvailableVersions'] -and $pkg.AvailableVersions) { [string]($pkg.AvailableVersions | Select-Object -First 1) } else { $null }); Source = 'Microsoft.WinGet.Client' }
                }
            } catch { }
        }
    }
    # 2) Exact ID probes via fixed-width table parsing.
    foreach ($id in @($CandidateIds | Where-Object { $_ })) {
        $r = Invoke-WingetList -Arguments @('list', '--id', $id, '--exact')
        if (-not $r.NoMatch -and $r.Rows.Count -gt 0) {
            $row = $r.Rows | Select-Object -First 1
            $inst = Get-WingetTableField $row @('Version', 'Sürüm')
            $avail = Get-WingetTableField $row @('Available', 'Mevcut')
            $name = Get-WingetTableField $row @('Name', 'Ad')
            $rid = Get-WingetTableField $row @('Id')
            return [pscustomobject]@{ Found = $true; Id = $(if ($rid) { $rid } else { $id }); Name = $name; InstalledVersion = $inst; AvailableVersion = $avail; Source = 'winget table' }
        }
    }
    # 3) Name query fallback (handles ID/version-display mismatches, e.g. Python rows).
    if ($NameQuery) {
        $r = Invoke-WingetList -Arguments @('list', '-q', $NameQuery)
        if (-not $r.NoMatch -and $r.Rows.Count -gt 0) {
            $pick = $r.Rows | Where-Object {
                $idv = Get-WingetTableField $_ @('Id'); $vv = Get-WingetTableField $_ @('Version', 'Sürüm')
                ($idv -like 'Python.Python*' -or $idv -like 'OpenJS.NodeJS*') -and
                (-not $ExpectedVersion -or $vv -eq $ExpectedVersion -or $vv -like "*> $ExpectedVersion*" -or $vv -like "$ExpectedVersion*")
            } | Select-Object -First 1
            if (-not $pick) { $pick = $r.Rows | Select-Object -First 1 }
            $inst = Get-WingetTableField $pick @('Version', 'Sürüm')
            $avail = Get-WingetTableField $pick @('Available', 'Mevcut')
            if ($inst -match '^>\s*(\S+)$') { $inst = $matches[1] } # display quirk
            $name = Get-WingetTableField $pick @('Name', 'Ad')
            $rid = Get-WingetTableField $pick @('Id')
            return [pscustomobject]@{ Found = $true; Id = $rid; Name = $name; InstalledVersion = $inst; AvailableVersion = $avail; Source = 'winget query'; Ambiguous = ($r.Rows.Count -gt 1) }
        }
    }
    return [pscustomobject]@{ Found = $false; Id = $null; Name = $null; InstalledVersion = $null; AvailableVersion = $null; Source = $null }
}

function Get-PythonWingetId {
    # Compatibility helper; prefer Resolve-PythonWingetPackage for ID + installed state.
    $pkg = Resolve-PythonWingetPackage
    if ($pkg -and $pkg.Found) { return $pkg.Id }
    try {
        $ver = py --version 2>&1 | Select-String -Pattern 'Python (\d+\.\d+)'
        if ($ver) { return "Python.Python.$($ver.Matches[0].Groups[1].Value)" }
    } catch { }
    return $null
}

function Resolve-PythonWingetPackage {
    $current = if (Test-Command 'py') { Get-PythonVersion } else { $null }
    $mm = $null
    if ($current -and $current -match '^(\d+\.\d+)') { $mm = $matches[1] }
    $candidates = @()
    if ($mm) { $candidates += "Python.Python.$mm" }
    $candidates += @('Python.Python.3', 'Python.PythonInstallManager')
    $query = if ($mm) { "Python $mm" } else { 'Python' }
    $pkg = Resolve-WingetPackage -CandidateIds $candidates -NameQuery $query -ExpectedVersion $current
    if ($pkg.Found) { return $pkg }
    # Last resort: broad query, pick best Python.Python.* row
    $r = Invoke-WingetList -Arguments @('list')
    $rows = @($r.Rows | Where-Object { (Get-WingetTableField $_ @('Id')) -like 'Python.Python.*' })
    if ($mm) {
        $rows = @($rows | Where-Object {
            $idv = Get-WingetTableField $_ @('Id'); $vv = Get-WingetTableField $_ @('Version', 'Sürüm')
            $idv -eq "Python.Python.$mm" -or $vv -eq $current -or $vv -like "*> $current*"
        })
    }
    if ($rows.Count -gt 0) {
        $row = $rows | Select-Object -First 1
        $inst = Get-WingetTableField $row @('Version', 'Sürüm'); if ($inst -match '^>\s*(\S+)$') { $inst = $matches[1] }
        return [pscustomobject]@{ Found = $true; Id = (Get-WingetTableField $row @('Id')); Name = (Get-WingetTableField $row @('Name', 'Ad')); InstalledVersion = $inst; AvailableVersion = (Get-WingetTableField $row @('Available', 'Mevcut')); Source = 'winget list scan'; Ambiguous = ($rows.Count -gt 1) }
    }
    return [pscustomobject]@{ Found = $false; Id = $(if ($mm) { "Python.Python.$mm" } else { $null }); Name = $null; InstalledVersion = $null; AvailableVersion = $null; Source = $null }
}

function Get-PythonVersion {
    $ver = py --version 2>&1 | Select-String -Pattern 'Python (\d+\.\d+\.\d+)'
    if ($ver) { return $ver.Matches[0].Groups[1].Value }
    return 'unknown'
}

function Get-PipVersion {
    $out = py -m pip --version 2>&1
    $match = [System.Text.RegularExpressions.Regex]::Match($out, 'pip ([\d.]+)')
    if ($match.Success) { return $match.Groups[1].Value }
    return 'unknown'
}

function Get-NodeVersion {
    $ver = node --version 2>&1
    return $ver.Trim().TrimStart('v')
}

function Get-NpmVersion {
    $ver = npm --version 2>&1
    return $ver.Trim()
}

function Get-PipOutdated {
    $jsonSupported = $true
    $outdated = $null
    try {
        $outdated = py -m pip list --outdated --format=json 2>$null | ConvertFrom-Json
    } catch {
        $jsonSupported = $false
    }
    if (-not $jsonSupported -or -not $outdated) {
        $text = py -m pip list --outdated 2>$null
        if ($text -and $text -match '^\S') {
            $outdated = @()
            $text -split "`n" | ForEach-Object {
                if ($_ -match '^(\S+)\s+(\S+)\s+(\S+)') {
                    $outdated += [pscustomobject]@{ name = $matches[1]; version = $matches[2]; latest_version = $matches[3] }
                }
            }
        }
    }
    return $outdated
}

function Get-NpmOutdatedGlobal {
    # Returns array of outdated global npm packages.
    # npm outdated -g --json returns an object keyed by package name:
    # {"pkg":{"current":"1.0.0","wanted":"1.0.0","latest":"2.0.0",...}}
    $items = @()
    try {
        $raw = npm outdated -g --json 2>$null | Out-String
        if ($raw -and $raw.Trim() -and $raw.Trim() -ne '{}') {
            $obj = $raw | ConvertFrom-Json
            if ($obj) {
                foreach ($prop in @($obj.PSObject.Properties)) {
                    if (-not $prop.Name) { continue }
                    $v = $prop.Value
                    $items += [pscustomobject]@{
                        name    = [string]$prop.Name
                        current = [string]$v.current
                        wanted  = [string]$v.wanted
                        latest  = [string]$v.latest
                    }
                }
            }
        }
    } catch { }
    if ($items.Count -gt 0) { return @($items) }
    # Fallback: parse text output
    $text = npm outdated -g 2>$null
    if ($text) {
        $text -split "`n" | ForEach-Object {
            # npm outdated output: Package  Current  Wanted  Latest  Location
            if ($_ -match '^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)') {
                $items += [pscustomobject]@{ name = $matches[1]; current = $matches[2]; wanted = $matches[3]; latest = $matches[4] }
            }
        }
    }
    return @($items)
}

function Get-WingetPackageStatus {
    param([string[]]$CandidateIds, [string]$NameQuery = '', [string]$ExpectedVersion = '')
    # Returns: @{ Found; Id; Installed; Available; Parseable; NoUpgradeMatch; Source; Note }
    $pkg = Resolve-WingetPackage -CandidateIds $CandidateIds -NameQuery $NameQuery -ExpectedVersion $ExpectedVersion
    $primaryId = if ($pkg.Found -and $pkg.Id) { $pkg.Id } elseif ($CandidateIds -and $CandidateIds.Count -gt 0) { $CandidateIds[0] } else { $null }
    $result = [pscustomobject]@{ Found = [bool]$pkg.Found; Id = $primaryId; Installed = $pkg.InstalledVersion; Available = $pkg.AvailableVersion; Parseable = $false; NoUpgradeMatch = $false; Source = $pkg.Source; Note = $null }
    if ($pkg.Found -and $pkg.AvailableVersion) { $result.Parseable = $true; return $result }
    if (-not $primaryId) { $result.Note = 'winget ID çözümlenemedi'; return $result }
    # Precise upgrade probe (winget v1.29+: lists only upgradable matches).
    $ua = Invoke-WingetList -Arguments @('list', '--id', $primaryId, '--exact', '--upgrade-available')
    if ($ua.NoMatch) {
        $result.NoUpgradeMatch = $true
        $result.Parseable = $true
        if ($result.Installed) { $result.Note = 'yükseltme yok (--upgrade-available)' }
        return $result
    }
    if ($ua.Rows.Count -gt 0) {
        $row = $ua.Rows | Select-Object -First 1
        $avail = Get-WingetTableField $row @('Available', 'Mevcut')
        $inst = Get-WingetTableField $row @('Version', 'Sürüm')
        if ($inst) { $result.Installed = $inst }
        if ($avail) { $result.Available = $avail; $result.Parseable = $true; $result.Source = 'winget --upgrade-available' }
        return $result
    }
    # Fallback: parse raw head for diagnostics; never claim up-to-date from unparseable output.
    $head = (($ua.Output -split "`r?`n" | Where-Object { $_ -and $_ -notmatch '^-+$' } | Select-Object -First 3) -join ' | ')
    Write-Log "winget ($primaryId): hedef sürüm alanı ayrıştırılamadı; ham başlık: $head" 'DEBUG'
    $result.Note = "target version not determined (unparseable output)"
    return $result
}

function Check-WingetUpdateAvailable {
    param([string]$Id)
    # Compatibility wrapper: returns available version or $null; callers must treat $null as unknown, not current.
    $s = Get-WingetPackageStatus -CandidateIds @($Id)
    if ($s.Available) { return $s.Available }
    return $null
}

function Set-Plan {
    param([string]$Component, [string]$Action, [string]$Current = '', [string]$Target = '', [string]$Details = '')
    $idx = $script:Plan | Where-Object { $_.Component -eq $Component }
    if ($idx) {
        $idx.Action = $Action
        if ($Current) { $idx.Current = $Current }
        if ($Target)  { $idx.Target  = $Target }
        if ($Details) { $idx.Details = $Details }
    }
}

function Set-Result {
    param([string]$Component, [string]$Status, [string]$Before = '', [string]$After = '', [string]$Details = '')
    $idx = $script:Result | Where-Object { $_.Component -eq $Component }
    if ($idx) {
        $idx.Status = $Status
        if ($Before) { $idx.Before = $Before }
        if ($After)  { $idx.After  = $After }
        if ($Details) { $idx.Details = $Details }
    }
}

function Show-PlanTable {

    Write-Log ""

    Write-Log "Plan:"

    foreach ($row in $script:Plan) {

        $detail = if ($row.Details) { " ($($row.Details))" } else { '' }

        Write-Log "  * $($row.Component): $($row.Action)  [$($row.Current) -> $($row.Target)]$detail"

    }

    Write-Log ""

}

function Show-ResultTable {

    Write-Log ""

    Write-Log "Results:"

    foreach ($row in $script:Result) {

        $detail = if ($row.Details) { " ($($row.Details))" } else { '' }

        $after = if ($row.After) { $row.After } elseif ($row.Before) { $row.Before } else { '' }

        Write-Log "  * $($row.Component): $($row.Status)  [$after]$detail"

    }

    Write-Log ""

}

Write-Log "Component updater" 'INFO'
if ($Check) { Write-Log "CHECK MODE: no changes will be made" 'INFO' }

# ============================================================
# PHASE 1: DETECTION — Build the PLAN (what WILL be updated)
# ============================================================
Write-Log "1/2 Checking..." 'INFO'

# --- Python runtime ---
Write-Log "  - Python/winget" 'INFO'

$pyWingetId = $null
$pyCurrent = 'unknown'
if (Test-Command 'winget' -and (Test-Command 'py')) {
    $pyCurrent = Get-PythonVersion
    $pyPkg = Resolve-PythonWingetPackage
    $pyWingetId = $pyPkg.Id
    $pyStatus = Get-WingetPackageStatus -CandidateIds @($pyWingetId, 'Python.PythonInstallManager') -NameQuery $(if ($pyCurrent -match '^(\d+\.\d+)') { "Python $($matches[1])" } else { 'Python' }) -ExpectedVersion $pyCurrent
    if ($pyStatus.Id) { $pyWingetId = $pyStatus.Id }
    $pyDetail = "winget: $pyWingetId$(if ($pyStatus.Source) { "; source: $($pyStatus.Source)" })"
    if ($pyStatus.Available -and $pyStatus.Available -ne $pyCurrent) {
        Set-Plan 'Python runtime' 'Güncellenecek' $pyCurrent $pyStatus.Available $pyDetail
    } elseif ($pyStatus.Parseable -and ($pyStatus.NoUpgradeMatch -or -not $pyStatus.Available -or $pyStatus.Available -eq $pyCurrent)) {
        Set-Plan 'Python runtime' 'Up to date' $pyCurrent $pyCurrent $pyDetail
    } elseif (-not $pyWingetId) {
        Set-Plan 'Python runtime' 'Skipped' $pyCurrent '' 'Version not detected / winget ID not found'
    } else {
        Set-Plan 'Python runtime' 'Unknown' $pyCurrent '' "$pyDetail; $($pyStatus.Note)"
    }
} else {
    Set-Plan 'Python runtime' 'Skipped' '' '' $(if (-not (Test-Command 'winget')) { 'winget not found' } else { 'py not found' })
}

Write-Log "  - pip" 'INFO'

# --- pip ---
$pipCurrent = 'unknown'
if (Test-Command 'py') {
    $pipCurrent = Get-PipVersion
    # Check if pip upgrade available - use pip install --upgrade --dry-run --report for reliable JSON
    $pipLatest = $null
    $pipLatestSource = $null
    try {
        $pipReportTemp = [System.IO.Path]::GetTempFileName()
        $out = py -m pip install --upgrade --dry-run --ignore-installed --report $pipReportTemp pip 2>&1
        if ($LASTEXITCODE -eq 0 -and (Test-Path $pipReportTemp)) {
            $pipReport = Get-Content $pipReportTemp -Raw | ConvertFrom-Json
            $inst = @($pipReport.install) | Where-Object { $_.metadata.name -eq 'pip' } | Select-Object -First 1
            if (-not $inst -and $pipReport.install -and $pipReport.install.Count -gt 0) { $inst = $pipReport.install[0] }
            if ($inst -and $inst.metadata.version) { $pipLatest = [string]$inst.metadata.version; $pipLatestSource = 'pip --report' }
        }
        Remove-Item $pipReportTemp -ErrorAction SilentlyContinue
    } catch { Remove-Item $pipReportTemp -ErrorAction SilentlyContinue }
    if (-not $pipLatest) {
        # Fallback: pip index versions (verified pip 26.x: "Available versions: <latest>, ...").
        # fast-deps is not a supported --use-feature on pip 26.x; avoid speculative flags.
        try {
            $idxOut = (py -m pip index versions pip 2>&1 | Out-String)
            $pipLatest = Get-LatestFromIndexVersions -Text $idxOut
            if ($pipLatest) { $pipLatestSource = 'pip index versions' }
        } catch { }
    }
    $pipDetail = if ($pipLatestSource) { "source: $pipLatestSource" } else { 'pip target version not determined' }
    if ($pipLatest -and $pipLatest -ne $pipCurrent) {
        Set-Plan 'pip' 'Güncellenecek' $pipCurrent $pipLatest $pipDetail
    } elseif ($pipLatest) {
        Set-Plan 'pip' 'Up to date' $pipCurrent $pipCurrent $pipDetail
    } else {
        Set-Plan 'pip' 'Unknown' $pipCurrent '' $pipDetail
    }
} else {
    Set-Plan 'pip' 'Skipped' '' '' 'py not found'
}

# --- pip packages ---
if (Test-Command 'py') {
    $outdated = Get-PipOutdated
    if ($outdated -and $outdated.Count -gt 0) {
        $details = ($outdated | ForEach-Object { "$($_.name) $($_.version)→$($_.latest_version)" }) -join ', '
        Set-Plan 'pip packages' 'Güncellenecek' "$($outdated.Count) package(s)" "$($outdated.Count) package(s)" $details
    } else {
        Set-Plan 'pip packages' 'Up to date' '0 packages' '0 packages'
    }
} else {
    Set-Plan 'pip packages' 'Skipped' '' '' 'py not found'
}

# --- Node.js runtime ---
$nodeCurrent = 'unknown'
$nodeWingetId = 'OpenJS.NodeJS.LTS'
if (Test-Command 'winget' -and (Test-Command 'node')) {
    $nodeCurrent = Get-NodeVersion
    $nodeStatus = Get-WingetPackageStatus -CandidateIds @('OpenJS.NodeJS.LTS') -ExpectedVersion $nodeCurrent
    if ($nodeStatus.Id) { $nodeWingetId = $nodeStatus.Id }
    $nodeDetail = "winget: $nodeWingetId$(if ($nodeStatus.Source) { "; source: $($nodeStatus.Source)" })"
    if ($nodeStatus.Available -and $nodeStatus.Available -ne $nodeCurrent) {
        Set-Plan 'Node.js runtime' 'Güncellenecek' $nodeCurrent $nodeStatus.Available $nodeDetail
    } elseif ($nodeStatus.Parseable -and ($nodeStatus.NoUpgradeMatch -or -not $nodeStatus.Available -or $nodeStatus.Available -eq $nodeCurrent)) {
        Set-Plan 'Node.js runtime' 'Up to date' $nodeCurrent $nodeCurrent $nodeDetail
    } else {
        Set-Plan 'Node.js runtime' 'Unknown' $nodeCurrent '' "$nodeDetail; $($nodeStatus.Note)"
    }
} else {
    Set-Plan 'Node.js runtime' 'Skipped' '' '' $(if (-not (Test-Command 'winget')) { 'winget not found' } else { 'node not found' })
}

# --- npm ---
Write-Log "  - npm" 'INFO'

$npmCurrent = 'unknown'
if (Test-Command 'npm') {
    $npmCurrent = Get-NpmVersion
    $npmLatest = $null
    try {
        $out = npm view npm@latest version 2>$null
        if ($out) { $npmLatest = $out.Trim() }
    } catch { }
    if ($npmLatest -and $npmLatest -ne $npmCurrent) {
        Set-Plan 'npm' 'Güncellenecek' $npmCurrent $npmLatest
    } else {
        Set-Plan 'npm' 'Up to date' $npmCurrent $npmCurrent
    }
} else {
    Set-Plan 'npm' 'Skipped' '' '' 'npm not found'
}

# --- npm packages ---
if (Test-Command 'npm') {
    $npmOutdated = Get-NpmOutdatedGlobal
    if ($npmOutdated -and $npmOutdated.Count -gt 0) {
        $details = ($npmOutdated | ForEach-Object { "$($_.name) $($_.current)→$($_.latest)" }) -join ', '
        Set-Plan 'npm packages' 'Güncellenecek' "$($npmOutdated.Count) package(s)" "$($npmOutdated.Count) package(s)" $details
    } else {
        Set-Plan 'npm packages' 'Up to date' '0 packages' '0 packages'
    }
} else {
    Set-Plan 'npm packages' 'Skipped' '' '' 'npm not found'
}

# Show the plan
Show-PlanTable

if ($Check) {
    Write-UpdateComponentsReport -ExecutionCompleted:$false | Out-Null
    Write-Log "CHECK MODE: plan shown above; no changes will be made" 'INFO'
    exit 0
}

# ============================================================
# PHASE 2: EXECUTION — Apply updates and build RESULTS
# ============================================================
Write-Log "2/2 Applying..." 'INFO'

$script:OverallFailed = $false

# --- Python runtime ---
$pyRow = $script:Plan | Where-Object { $_.Component -eq 'Python runtime' }
if ($pyRow.Action -eq 'Güncellenecek') {
    $pyExecId = if ($pyWingetId) { $pyWingetId } else { 'Python.Python' }
    Write-Log "Updating Python runtime via winget ($pyExecId)..." 'INFO'
    $pyUpgrade = Run-Command 'winget' @('upgrade', '--id', $pyExecId, '--exact', '--accept-source-agreements', '--accept-package-agreements') "Python runtime ($pyExecId)"
    $pyAfter = Get-PythonVersion
    if ($pyUpgrade -eq 0) {
        $status = if ($pyCurrent -eq $pyAfter) { 'Up to date' } else { 'Updated' }
        Set-Result 'Python runtime' $status $pyCurrent $pyAfter
    } else {
        Set-Result 'Python runtime' 'Error' $pyCurrent '' 'winget upgrade failed'
        $script:OverallFailed = $true
    }
} else {
    Set-Result 'Python runtime' $pyRow.Action $pyCurrent $pyCurrent $pyRow.Details
}

# --- pip ---
$pipRow = $script:Plan | Where-Object { $_.Component -eq 'pip' }
if ($pipRow.Action -eq 'Güncellenecek') {
    Write-Log "Upgrading pip..." 'INFO'
    $pipUpgrade = Run-Command 'py' @('-m', 'pip', 'install', '--upgrade', 'pip') 'pip upgrade'
    $pipAfter = Get-PipVersion
    if ($pipUpgrade -eq 0) {
        $status = if ($pipCurrent -eq $pipAfter) { 'Up to date' } else { 'Updated' }
        Set-Result 'pip' $status $pipCurrent $pipAfter
    } else {
        Set-Result 'pip' 'Error' $pipCurrent '' 'pip upgrade failed'
        $script:OverallFailed = $true
    }
} else {
    Set-Result 'pip' $pipRow.Action $pipCurrent $pipCurrent $pipRow.Details
}

# --- pip packages ---
$pipPkgRow = $script:Plan | Where-Object { $_.Component -eq 'pip packages' }
if ($pipPkgRow.Action -eq 'Güncellenecek') {
    Write-Log "Checking for outdated pip packages..." 'INFO'
    $outdated = Get-PipOutdated
    if ($outdated -and $outdated.Count -gt 0) {
        $pipPkgDetails = @()
        foreach ($pkg in $outdated) {
            $name = $pkg.name
            $fromVer = $pkg.version
            $toVer = $pkg.latest_version
            Write-Log "Upgrading $name ($fromVer -> $toVer)..." 'INFO'
            $result = Run-Command 'py' @('-m', 'pip', 'install', '--upgrade', $name) "pip upgrade $name"
            if ($result -eq 0) {
                $pipPkgDetails += "$name $fromVer→$toVer"
            } else {
                $pipPkgDetails += "$name FAILED"
                $script:OverallFailed = $true
            }
        }
        $status = if ($pipPkgDetails -match 'FAILED') { 'Partially updated' } else { 'Updated' }
        Set-Result 'pip packages' $status "$($outdated.Count) package(s)" "$($pipPkgDetails.Count) processed" ($pipPkgDetails -join ', ')
    } else {
        Set-Result 'pip packages' 'Up to date' '0 packages' '0 packages'
    }
} else {
    Set-Result 'pip packages' $pipPkgRow.Action "$($pipPkgRow.Current)" "$($pipPkgRow.Target)" $pipPkgRow.Details
}

# --- Node.js runtime ---
$nodeRow = $script:Plan | Where-Object { $_.Component -eq 'Node.js runtime' }
if ($nodeRow.Action -eq 'Güncellenecek') {
    $nodeExecId = if ($nodeWingetId) { $nodeWingetId } else { 'OpenJS.NodeJS.LTS' }
    Write-Log "Checking for Node.js LTS update via winget ($nodeExecId)..." 'INFO'
    $wingetUpgrade = Run-Command 'winget' @('upgrade', '--id', $nodeExecId, '--exact', '--accept-source-agreements', '--accept-package-agreements') 'Node.js LTS winget upgrade'
    $nodeAfter = Get-NodeVersion
    if ($wingetUpgrade -eq 0) {
        $status = if ($nodeCurrent -eq $nodeAfter) { 'Up to date' } else { 'Updated' }
        Set-Result 'Node.js runtime' $status $nodeCurrent $nodeAfter
    } else {
        Set-Result 'Node.js runtime' 'Error' $nodeCurrent '' 'winget upgrade failed'
        $script:OverallFailed = $true
    }
} else {
    Set-Result 'Node.js runtime' $nodeRow.Action $nodeCurrent $nodeCurrent $nodeRow.Details
}

# --- npm ---
$npmRow = $script:Plan | Where-Object { $_.Component -eq 'npm' }
if ($npmRow.Action -eq 'Güncellenecek') {
    Write-Log "Upgrading npm..." 'INFO'
    $npmUpgrade = Run-Command 'npm' @('install', '--global', 'npm@latest') 'npm self-upgrade'
    $npmAfter = Get-NpmVersion
    if ($npmUpgrade -eq 0) {
        $status = if ($npmCurrent -eq $npmAfter) { 'Up to date' } else { 'Updated' }
        Set-Result 'npm' $status $npmCurrent $npmAfter
    } else {
        Set-Result 'npm' 'Error' $npmCurrent '' 'npm upgrade failed'
        $script:OverallFailed = $true
    }
} else {
    Set-Result 'npm' $npmRow.Action $npmCurrent $npmCurrent $npmRow.Details
}

# --- npm packages ---
$npmPkgRow = $script:Plan | Where-Object { $_.Component -eq 'npm packages' }
if ($npmPkgRow.Action -eq 'Güncellenecek') {
    Write-Log "Updating global npm packages to latest..." 'INFO'
    $npmOutdatedNow = Get-NpmOutdatedGlobal
    $npmPkgDetails = @()
    $npmPkgFailed = $false
    if ($npmOutdatedNow -and $npmOutdatedNow.Count -gt 0) {
        foreach ($pkg in @($npmOutdatedNow)) {
            $name = [string]$pkg.name
            $fromVer = [string]$pkg.current
            $toVer = [string]$pkg.latest
            if (-not $name -or -not $toVer) { continue }
            Write-Log "Upgrading $name ($fromVer -> $toVer)..." 'INFO'
            $result = Run-Command 'npm' @('install', '--global', "$name@$toVer") "npm upgrade $name"
            if ($result -eq 0) { $npmPkgDetails += "$name $fromVer→$toVer" }
            else { $npmPkgDetails += "$name FAILED"; $npmPkgFailed = $true; $script:OverallFailed = $true }
        }
    }
    $npmAfterList = Get-NpmOutdatedGlobal
    $npmAfterCount = if ($npmAfterList) { @($npmAfterList).Count } else { 0 }
    $afterDetails = if ($npmAfterCount -gt 0) { ($npmAfterList | ForEach-Object { "$($_.name) $($_.current)→$($_.latest)" }) -join ', ' } else { ($npmPkgDetails -join ', ') }
    if ($npmAfterCount -eq 0 -and -not $npmPkgFailed) {
        Set-Result 'npm packages' 'Updated' "$($npmPkgRow.Current)" '0 packages' $afterDetails
    } elseif ($npmAfterCount -gt 0) {
        Set-Result 'npm packages' 'Partially updated' "$($npmPkgRow.Current)" "$npmAfterCount package(s) left" $(if ($afterDetails) { $afterDetails } else { 'run npm outdated -g for details' })
    } else {
        Set-Result 'npm packages' 'Error' "$($npmPkgRow.Current)" '' $(if ($afterDetails) { $afterDetails } else { 'npm package upgrade failed' })
    }
} else {
    Set-Result 'npm packages' $npmPkgRow.Action "$($npmPkgRow.Current)" "$($npmPkgRow.Target)" $npmPkgRow.Details
}

# ============================================================
# FINAL: Show results
# ============================================================
Show-ResultTable

$script:ExecutionCompleted = $true
Write-UpdateComponentsReport -ExecutionCompleted:$true | Out-Null

Write-Log "Summary" 'INFO'
if ($script:OverallFailed) {
    Write-Log "Some updates failed or were skipped; review the log above" 'WARN'
    exit 1
} else {
    Write-Log "All updates completed successfully" 'INFO'
    exit 0
}