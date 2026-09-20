# Maintenance Scripts - Mojibake / encoding gate
# Detects double-encoded (mojibake) text and invalid UTF-8 in:
#   - tracked files           (-Files)      optionally restricted to staged
#   - explicit files or dirs  (-Path)
#   - commit messages/authors (-Commits)
#   - commit-msg hook input   (-Message)
#   - JSON payloads           (-JsonFile)   e.g. dumped GitHub/GitLab API data
# Runs on Windows PowerShell 5.1 and PowerShell 7+. Never makes network calls;
# exits 1 when any finding exists, otherwise exits 0 silently.
#
# Mojibake patterns are written as ASCII escapes so the source stays clean:
#   U+00C0-C5 followed by U+0080-BF  -> double-encoded Latin-1
#   U+FFFD                          -> Unicode replacement character
[CmdletBinding()]
param(
    [switch]$Files,
    [switch]$Staged,
    [switch]$Commits,
    [string]$CommitRange = 'HEAD',
    [string]$Message = '',
    [string]$JsonFile = '',
    [string[]]$Path = @(),
    [string]$Root = '.'
)

Set-StrictMode -Version 2.0

if (-not ($Files -or $Commits -or $Message -or $JsonFile -or $Path.Count -gt 0)) {
    $Files = $true
}

$script:Findings = 0
$script:Strict = New-Object System.Text.UTF8Encoding($false, $true)

$script:ReMojibake = [regex](
    '(?:\u00C2[\u0080-\u00BF])' +
    '|(?:\u00C3[\u0080-\u00BF])' +
    '|(?:\u00C4[\u0080-\u00BF])' +
    '|(?:\u00C5[\u0080-\u00BF])' +
    '|(?:\uFFFD)'
)

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

function Add-Finding {
    param(
        [string]$Source,
        [System.Text.RegularExpressions.Match]$Match,
        [string]$Text,
        [string]$Label = 'INVALID-UTF8'
    )
    $script:Findings++
    if ($null -eq $Match) {
        Write-Output ("{0} {1}" -f $Label, $Source)
        return
    }
    $line = 1
    if ($Match.Index -gt 0 -and $Text.Length -gt 0) {
        $upTo = $Text.Substring(0, [Math]::Min($Match.Index, $Text.Length))
        $line = ($upTo -split "`n").Count
    }
    $take = [Math]::Min(60, $Text.Length - $Match.Index)
    $ctx = if ($take -gt 0) { $Text.Substring($Match.Index, $take) -replace "`r", '' -replace "`n", ' ' } else { '' }
    Write-Output ("MOJIBAKE {0}:{1}: {2}" -f $Source, $line, $ctx)
}

function Test-String {
    param([string]$Source, [string]$Text)
    if (-not $Text) { return }
    foreach ($m in $script:ReMojibake.Matches($Text)) {
        Add-Finding -Source $Source -Match $m -Text $Text
    }
}

function Read-TextFile {
    param([string]$Path, [string]$Label)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) { return }
    $probe = [Math]::Min(1024, $bytes.Length)
    for ($i = 0; $i -lt $probe; $i++) {
        if ($bytes[$i] -eq 0) { return }
    }
    $text = ''
    try {
        $text = $script:Strict.GetString($bytes)
    } catch {
        Add-Finding -Source $Label -Match $null -Text ''
        return
    }
    Test-String -Source $Label -Text $text
}

if ($Files -or $Path.Count -gt 0) {
    $paths = @($Path)
    if ($paths.Count -eq 0) {
        if ($Staged) {
            $paths = @(& git -C $Root diff --cached --name-only --diff-filter=ACMR)
        } else {
            $paths = @(& git -C $Root ls-files)
        }
    }
    foreach ($item in $paths) {
        if (-not $item) { continue }
        $full = if ([System.IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $Root $item }
        $label = if ([System.IO.Path]::IsPathRooted($item)) { $full } else { $item }
        if (Test-Path -LiteralPath $full) {
            if ((Get-Item -LiteralPath $full).PSIsContainer) {
                $found = @(Get-ChildItem -LiteralPath $full -Recurse -File -Force |
                    Where-Object { $_.FullName -notmatch '[\\/]\.git($|[\\/])' })
                foreach ($f in $found) { Read-TextFile -Path $f.FullName -Label $f.FullName }
            } else {
                Read-TextFile -Path $full -Label $label
            }
        } else {
            Write-Output ("MISSING {0}" -f $full)
            $script:Findings++
        }
    }
}

if ($Commits) {
    $range = $CommitRange
    if ($range -match '^0+$') { $range = '--all' }
    $hashes = @(& git -C $Root log "--format=%H" $range 2>$null)
    if ($LASTEXITCODE -ne 0) {
        $hashes = @(& git -C $Root log "--format=%H" --all 2>$null)
    }
    foreach ($h in $hashes) {
        if (-not $h) { continue }
        $author = (@(& git -C $Root log -1 "--format=%an" $h 2>$null)) -join ''
        $msg = (@(& git -C $Root log -1 "--format=%B" $h 2>$null)) -join "`n"
        $source = "commit $h"
        if ($null -ne $author) { Test-String -Source ("$source author") -Text $author }
        if ($null -ne $msg) { Test-String -Source ("$source message") -Text $msg }
    }
}

if ($Message) {
    if (Test-Path -LiteralPath $Message) {
        $bytes = [System.IO.File]::ReadAllBytes($Message)
        try {
            Test-String -Source 'commit-msg' -Text ($script:Strict.GetString($bytes))
        } catch {
            Add-Finding -Source 'commit-msg' -Match $null -Text ''
        }
    } else {
        Write-Output ("MISSING message file {0}" -f $Message)
        $script:Findings++
    }
}

function Walk-Json {
    param($Node, [string]$Prefix)
    if ($null -eq $Node) { return }
    if ($Node -is [string]) {
        Test-String -Source $Prefix -Text $Node
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        $i = 0
        foreach ($item in $Node) {
            Walk-Json -Node $item -Prefix ("{0}[{1}]" -f $Prefix, $i)
            $i++
        }
        return
    }
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $Node.PSObject.Properties) {
            Walk-Json -Node $prop.Value -Prefix ("{0}.{1}" -f $Prefix, $prop.Name)
        }
    }
}

if ($JsonFile) {
    if (Test-Path -LiteralPath $JsonFile) {
        $bytes = [System.IO.File]::ReadAllBytes($JsonFile)
        try {
            $text = $script:Strict.GetString($bytes)
            $obj = $text | ConvertFrom-Json
            Walk-Json -Node $obj -Prefix ("JSON {0}" -f $JsonFile)
        } catch {
            Add-Finding -Source ("JSON {0}" -f $JsonFile) -Match $null -Text '' -Label 'JSON-PARSE'
        }
    } else {
        Write-Output ("MISSING JSON file {0}" -f $JsonFile)
        $script:Findings++
    }
}

if ($script:Findings -gt 0) {
    Write-Output ("FOUND {0} mojibake issue(s)." -f $script:Findings)
    exit 1
}
exit 0