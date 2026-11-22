# Maintenance Scripts - scoped line-ending repair
# Repairs only the files handed to it (default: files changed in the working
# tree or index). The declared eol attribute is the oracle; files without one
# and binary/invalid-UTF-8 files are skipped and reported, never rewritten.
# BOM and byte encoding are preserved. Run as a file, not as an inline command.
[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [string]$Root = '.'
)

Set-StrictMode -Version 2.0

if (-not $Root) { $Root = '.' }
try {
    $rootFull = [System.IO.Path]::GetFullPath((Join-Path $Root '.'))
} catch {
    $rootFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Root))
}

if ($Path.Count -eq 0) {
    $changed = @(& git -C $rootFull diff --name-only)
    $staged = @(& git -C $rootFull diff --cached --name-only --diff-filter=ACMR)
    $Path = @($changed + $staged | Where-Object { $_ } | Sort-Object -Unique)
}

if ($Path.Count -eq 0) {
    Write-Output 'No changed tracked files to repair.'
    exit 0
}

$script:Strict = New-Object System.Text.UTF8Encoding($false, $true)
$script:Repaired = 0
$script:Skipped = 0

foreach ($item in $Path) {
    $full = if ([System.IO.Path]::IsPathRooted($item)) { $item } else { Join-Path $rootFull $item }
    if (-not [System.IO.File]::Exists($full)) {
        Write-Output ("SKIP missing: " + $item)
        $script:Skipped += 1
        continue
    }

    $attr = @(& git -C $rootFull check-attr eol -- $item)
    $declared = ''
    foreach ($line in $attr) {
        if ($line -match ':\s*eol:\s*(\S+)\s*$') { $declared = $Matches[1] }
    }
    if (-not $declared -or $declared -eq 'unspecified') {
        Write-Output ("SKIP no declared eol: " + $item)
        $script:Skipped += 1
        continue
    }

    $bytes = [System.IO.File]::ReadAllBytes($full)
    $probe = [Math]::Min(1024, $bytes.Length)
    $binary = $false
    for ($i = 0; $i -lt $probe; $i++) {
        if ($bytes[$i] -eq 0) { $binary = $true; break }
    }
    if ($binary) {
        Write-Output ("SKIP binary: " + $item)
        $script:Skipped += 1
        continue
    }

    try {
        $text = $script:Strict.GetString($bytes)
    } catch {
        Write-Output ("SKIP invalid UTF-8: " + $item)
        $script:Skipped += 1
        continue
    }

    $normalized = $text -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    $ending = if ($declared -eq 'lf') { "`n" } else { "`r`n" }
    $repaired = ($normalized -split "`n") -join $ending
    [System.IO.File]::WriteAllText($full, $repaired, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ("REPAIRED {0} -> eol={1}" -f $item, $declared)
    $script:Repaired += 1
}

Write-Output ("Repaired: {0}, skipped: {1}" -f $script:Repaired, $script:Skipped)
exit 0
