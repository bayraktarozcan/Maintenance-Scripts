# Maintenance Scripts - line-ending gate
# Reads `git ls-files --eol` and fails on:
#   - a working-tree file whose w/ column reads `mixed`
#   - a working-tree file whose w/ disagrees with its declared eol attribute
# Files without a declared eol attribute are checked for `mixed` only.
# Runs on Windows PowerShell 5.1 and PowerShell 7+. Never modifies files.
[CmdletBinding()]
param(
    [string]$Root = '.'
)

Set-StrictMode -Version 2.0

if (-not $Root) { $Root = '.' }
try {
    $rootFull = [System.IO.Path]::GetFullPath((Join-Path $Root '.'))
} catch {
    $rootFull = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Root))
}

$rows = @(& git -C $rootFull ls-files --eol 2>$null)
if ($LASTEXITCODE -ne 0) {
    Write-Output 'GIT ERROR: git ls-files --eol failed'
    exit 1
}

$findings = 0
$rowPattern = '^i/(\S+)\s+w/(\S+)\s+attr/(\S+)(?:\s+eol=(\S+))?\s+(.+)$'

foreach ($row in $rows) {
    $match = [regex]::Match($row, $rowPattern)
    if (-not $match.Success) { continue }
    $indexEnding = $match.Groups[1].Value
    $workEnding = $match.Groups[2].Value
    $declared = $match.Groups[4].Value
    $path = $match.Groups[5].Value.Trim()
    if (-not $path) { continue }

    if ($workEnding -eq 'mixed') {
        $findings += 1
        Write-Output ("MIXED {0} (index {1})" -f $path, $indexEnding)
        continue
    }
    if ($declared -and $workEnding -ne $declared) {
        $findings += 1
        Write-Output ("MISMATCH {0}: w/{1} but attr eol={2}" -f $path, $workEnding, $declared)
    }
}

if ($findings -gt 0) {
    Write-Output ("FOUND {0} line-ending finding(s)." -f $findings)
    exit 1
}
exit 0
