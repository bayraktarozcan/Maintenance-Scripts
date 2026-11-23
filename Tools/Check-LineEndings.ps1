# Maintenance Scripts - line-ending gate
# Reads `git ls-files --eol` and fails on:
#   - a working-tree file whose w/ column reads `mixed`
#   - a working-tree file whose w/ disagrees with its declared eol attribute
#   - a .gitattributes eol= declaration that disagrees with .editorconfig
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

function Expand-EditorConfigGlob {
    param([string]$Pattern)
    $brace = [regex]::Match($Pattern, '^(.*)\{(.+)\}(.*)$')
    if (-not $brace.Success) { return @($Pattern) }
    $expanded = @()
    foreach ($part in ($brace.Groups[2].Value -split ',')) {
        $expanded += ($brace.Groups[1].Value + $part + $brace.Groups[3].Value)
    }
    return $expanded
}

function Get-SampleForPattern {
    param([string]$Pattern)
    if ($Pattern -eq '*' -or $Pattern -eq '*.lnk') { return $null }
    if ($Pattern -like '*/') { return $null }
    if ($Pattern -like '*/\*') { return ($Pattern -replace '\*$', 'sample') }
    if ($Pattern -like '*.*') { return ($Pattern -replace '^\*\.', 'sample.') }
    return ($Pattern -replace '\*', 'sample')
}

function Test-GlobMatch {
    param([string]$Pattern, [string]$Value)
    $regex = '^' + [regex]::Escape($Pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
    return [regex]::IsMatch($Value, $regex)
}

$rows = @()
if (Test-Path -LiteralPath (Join-Path $rootFull '.git')) {
    $rows = @(& git -C $rootFull ls-files --eol 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'GIT ERROR: git ls-files --eol failed'
        exit 1
    }
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

$gitAttributesPath = Join-Path $rootFull '.gitattributes'
$editorConfigPath = Join-Path $rootFull '.editorconfig'
if ((Test-Path -LiteralPath $gitAttributesPath) -and (Test-Path -LiteralPath $editorConfigPath)) {
    $editorRules = @()
    $activePatterns = @()
    foreach ($configLine in [IO.File]::ReadAllLines($editorConfigPath)) {
        $trimmed = $configLine.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $activePatterns = @()
            foreach ($expandedSection in (Expand-EditorConfigGlob -Pattern $Matches[1])) {
                $activePatterns += @($expandedSection -split ',' | ForEach-Object { $_.Trim().Trim('"') })
            }
            continue
        }
        if ($trimmed -match '^end_of_line\s*=\s*(lf|crlf)\s*$') {
            $configEol = $Matches[1].ToLowerInvariant()
            foreach ($activePattern in $activePatterns) {
                foreach ($expanded in (Expand-EditorConfigGlob -Pattern $activePattern)) {
                    $editorRules += [pscustomobject]@{ Pattern = $expanded; Eol = $configEol }
                }
            }
        }
    }

    foreach ($attributeLine in [IO.File]::ReadAllLines($gitAttributesPath)) {
        $trimmed = $attributeLine.Trim()
        if ($trimmed -match '^([^#\s]+)\s+.*\beol=(lf|crlf)\b') {
            $attributePattern = $Matches[1]
            $attributeEol = $Matches[2].ToLowerInvariant()
            $sample = Get-SampleForPattern -Pattern $attributePattern
            if (-not $sample) { continue }
            $effectiveEol = ''
            foreach ($rule in $editorRules) {
                if (Test-GlobMatch -Pattern $rule.Pattern -Value $sample) { $effectiveEol = $rule.Eol }
            }
            if ($effectiveEol -and $effectiveEol -ne $attributeEol) {
                $findings += 1
                Write-Output ("DECL MISMATCH {0}: .gitattributes eol={1} but .editorconfig end_of_line={2}" -f $attributePattern, $attributeEol, $effectiveEol)
            }
        }
    }
}

if ($findings -gt 0) {
    Write-Output ("FOUND {0} line-ending finding(s)." -f $findings)
    exit 1
}
exit 0
