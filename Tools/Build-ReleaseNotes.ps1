# Maintenance Scripts - canonical release metadata generator
# Derives the release title and bilingual body from CHANGELOG.md, the single
# source of truth. Windows PowerShell 5.1 compatible; no external modules.
# Usage:
#   powershell -NoProfile -File Tools/Build-ReleaseNotes.ps1 0.1.1.2 -Current -Output notes.md
#   powershell -NoProfile -File Tools/Build-ReleaseNotes.ps1 0.1.1.1 -Output notes.md
# Stdout line 1 is the canonical title; older versions get the prefix in front.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [switch]$Current,
    [string]$Output,
    [string]$Root
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$bare = $Version.TrimStart('v', 'V')

$script:Acronyms = @{
    'api' = 'API'; 'ci' = 'CI'; 'cd' = 'CD'; 'dns' = 'DNS'; 'html' = 'HTML'
    'json' = 'JSON'; 'pdf' = 'PDF'; 'sha256' = 'SHA256'; 'tls' = 'TLS'
    'url' = 'URL'; 'utf8' = 'UTF8'; 'guid' = 'GUID'; 'lts' = 'LTS'
}
$script:Mixed = @{
    'changelog' = 'Changelog'; 'dependabot' = 'Dependabot'; 'github' = 'GitHub'
    'gitlab' = 'GitLab'; 'ioc' = 'IoC'; 'javascript' = 'JavaScript'
    'linux' = 'Linux'; 'markdown' = 'Markdown'; 'pester' = 'Pester'
    'powershell' = 'PowerShell'; 'python' = 'Python'; 'windows' = 'Windows'
    'node.js' = 'Node.js'; 'winget' = 'winget'; 'pip' = 'pip'; 'npm' = 'npm'
    'pipx' = 'pipx'; 'lychee' = 'lychee'; 'gitleaks' = 'gitleaks'
    'actionlint' = 'actionlint'
}
$script:Minor = @('a', 'an', 'the', 'and', 'or', 'but', 'nor', 'for', 'of', 'on', 'per',
    'to', 'via', 'with', 'as', 'at', 'by', 'in', 'if', 've', 'veya', 'ya', 'ile', 'için', 'bir', 'göre')

function Convert-ToTitleCase {
    param([string]$Text)
    $words = @()
    foreach ($token in ($Text -split '\s+')) {
        $word = $token.Trim('-/.,;:|()[]{}*"')
        if ([string]::IsNullOrEmpty($word)) { continue }
        if ($word -match '^v?\d+(\.\d+){1,3}$') { $words += $word; continue }
        $low = $word.ToLowerInvariant()
        if ($script:Acronyms.ContainsKey($low)) { $words += $script:Acronyms[$low]; continue }
        if ($script:Mixed.ContainsKey($low)) { $words += $script:Mixed[$low]; continue }
        if ($script:Minor -contains $low -and $words.Count -gt 0) { $words += $low; continue }
        $parts = @()
        foreach ($part in ($word -split '[-/]' | Where-Object { $_ -ne '' })) {
            $pl = $part.ToLowerInvariant()
            if ($script:Acronyms.ContainsKey($pl)) { $parts += $script:Acronyms[$pl] }
            elseif ($script:Mixed.ContainsKey($pl)) { $parts += $script:Mixed[$pl] }
            elseif ($script:Minor -contains $pl -and $parts.Count -gt 0) { $parts += $pl }
            elseif ($part -match '[çğıöşüÇĞİÖŞÜ]' -and $part[0] -cne [char]::ToUpperInvariant($part[0])) {
                $parts += $part[0].ToString().ToUpperInvariant() + $part.Substring(1)
            } else {
                $parts += $part[0].ToString().ToUpperInvariant() + $part.Substring(1)
            }
        }
        $words += ($parts -join '-')
    }
    return ($words -join ' ')
}

function Get-ChangelogHalf {
    param([string]$Text, [switch]$Turkish)
    $normalized = $Text.Replace("`r`n", "`n").Replace("`r", "`n")
    $marker = [regex]::Match($normalized, '(?m)^## Türkçe\s*$')
    if (-not $marker.Success) { return $(if ($Turkish) { '' } else { $normalized }) }
    return $(if ($Turkish) { $normalized.Substring($marker.Index) } else { $normalized.Substring(0, $marker.Index) })
}

function Get-VersionBody {
    param([string]$Half)
    $match = [regex]::Match($Half, '(?m)^###\s*V?' + [regex]::Escape($bare) + '\s*[—–-]\s*[^\n]*\n')
    if (-not $match.Success) { return $null }
    $start = $match.Index + $match.Length
    $next = [regex]::Match($Half.Substring($start), '(?m)^###\s*V?\d')
    if ($next.Success) { return $Half.Substring($start, $next.Index) }
    return $Half.Substring($start)
}

function Remove-Garbage {
    param([string]$Text)
    $clean = $Text -replace '(?<!\w)#\d+\b', ''
    $clean = $clean -replace 'Table of Contents|İçindekiler', ''
    $clean = $clean -replace '(?m)^\s*\d+\.\s*\[[^\]]+\]\([^)]+\)\s*', ''
    return $clean.Trim()
}

function Get-SummaryAndBullets {
    param([string]$Body)
    $lines = $Body -split "`n"
    $summary = ''
    $sections = @{}
    $current = ''
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\*\*(.+?):\*\*\s*$') {
            $current = $Matches[1].ToLowerInvariant()
            if (-not $sections.ContainsKey($current)) { $sections[$current] = @() }
            continue
        }
        if ($trimmed -match '^- (.+)$') {
            if ($current) { $sections[$current] += (Remove-Garbage $Matches[1]) }
            elseif (-not $summary) { $summary = Remove-Garbage $Matches[1] }
            continue
        }
        if (-not $summary -and -not [string]::IsNullOrWhiteSpace($trimmed) -and $trimmed -notmatch '^(---|###|##|<a)') {
            $summary = Remove-Garbage $trimmed
        }
    }
    return @{ Summary = $summary; Sections = $sections }
}

function Get-ShortTitle {
    param([string]$Summary)
    $text = $Summary -replace '\*\*', ''
    $head = ($text -split ':', 2)[0].Trim()
    if ($head.Length -lt 3 -or $head.Length -gt 90) {
        $head = $text
        if ($head.Length -gt 100) {
            $head = $head.Substring(0, 100).TrimEnd()
            $cut = $head.LastIndexOf(' ')
            if ($cut -gt 0) { $head = $head.Substring(0, $cut) }
        }
    }
    return (Convert-ToTitleCase $head).Trim(' ', '.', ':', '-')
}

function Get-FileLists {
    param([hashtable]$Sections)
    $files = @()
    $docs = @()
    foreach ($key in $Sections.Keys) {
        foreach ($bullet in $Sections[$key]) {
            foreach ($token in [regex]::Matches($bullet, '`([^`]+)`')) {
                $value = $token.Groups[1].Value
                if ($value -match '\.(md)$') {
                    if ($docs -notcontains $value) { $docs += $value }
                } elseif ($value -match '(\.ps1$|\.bat$|\.yml$|\.py$|\.gitignore$|^Logs/)') {
                    if ($files -notcontains $value) { $files += $value }
                }
            }
        }
    }
    return @{ Files = @($files | Select-Object -First 8); Docs = @($docs | Select-Object -First 8) }
}

function New-Body {
    param([string]$Heading, [hashtable]$Data, [bool]$Turkish)
    $names = if ($Turkish) {
        @('Özet', 'Eklenenler', 'Değiştirilenler', 'Kaldırılanlar', 'Düzeltilenler', 'Dosyalar', 'Belgelendirme')
    } else {
        @('Summary', 'Added', 'Changed', 'Removed', 'Fixed', 'Files', 'Documentation')
    }
    $keys = if ($Turkish) {
        @('summary', 'eklenen', 'eklenenler', 'değişen', 'değiştirilen', 'kaldırılan', 'kaldırılanlar', 'düzeltilen', 'düzeltilenler', 'altyapı', 'dosyalar', 'belgelendirme')
    } else {
        @('summary', 'added', 'changed', 'infrastructure', 'removed', 'fixed', 'files', 'documentation')
    }
    $map = @{
        $names[1] = @('added', 'eklenen', 'eklenenler')
        $names[2] = @('changed', 'infrastructure', 'değişen', 'değiştirilen')
        $names[3] = @('removed', 'kaldırılan', 'kaldırılanlar')
        $names[4] = @('fixed', 'düzeltilen', 'düzeltilenler')
    }
    $lists = Get-FileLists -Sections $Data.Sections
    $none = if ($Turkish) { 'Bu sürümde yok.' } else { 'None in this release.' }
    $parts = @(('## ' + $Heading).TrimEnd(), '')
    $parts += '### ' + $names[0]
    $parts += ''
    $parts += '- ' + ($Data.Summary -replace '\s+', ' ').Trim()
    $parts += ''
    for ($i = 1; $i -le 4; $i++) {
        $parts += '### ' + $names[$i]
        $parts += ''
        $bullets = @()
        foreach ($key in $map[$names[$i]]) {
            if ($Data.Sections.ContainsKey($key)) { $bullets += $Data.Sections[$key] }
        }
        if ($bullets.Count -eq 0) { $bullets = @($none) }
        foreach ($bullet in $bullets) { $parts += '- ' + ($bullet -replace '\s+', ' ').Trim() }
        $parts += ''
    }
    $parts += '### ' + $names[5]
    $parts += ''
    if ($lists.Files.Count -eq 0) { $parts += '- ' + $none } else { foreach ($f in $lists.Files) { $parts += '- `' + $f + '`' } }
    $parts += ''
    $parts += '### ' + $names[6]
    $parts += ''
    if ($lists.Docs.Count -eq 0) { $parts += '- ' + $none } else { foreach ($d in $lists.Docs) { $parts += '- `' + $d + '`' } }
    return ($parts -join "`n")
}

$changelogPath = Join-Path $Root 'CHANGELOG.md'
if (-not (Test-Path -LiteralPath $changelogPath)) { throw "CHANGELOG.md not found: $changelogPath" }
$text = [IO.File]::ReadAllText($changelogPath)
$enHalf = Get-ChangelogHalf $text
$trHalf = Get-ChangelogHalf $text -Turkish
$enBody = Get-VersionBody $enHalf
if ($null -eq $enBody) { throw "no CHANGELOG section for v$bare" }
$trBody = Get-VersionBody $trHalf
$enData = Get-SummaryAndBullets $enBody
$trData = if ($null -ne $trBody) { Get-SummaryAndBullets $trBody } else { $enData }

$enTitle = Get-ShortTitle $enData.Summary
$trTitle = if ($null -ne $trBody -and $trData.Summary) { Get-ShortTitle $trData.Summary } else { $enTitle }
$title = "v$bare — $enTitle"
if (-not $Current) { $title = "[DEPRECATED] $title" }

$body = (New-Body -Heading "v$bare — $enTitle" -Data $enData -Turkish $false) + "`n`n---`n`n" +
        (New-Body -Heading "v$bare — $trTitle" -Data $trData -Turkish $true) + "`n"
if ($Output) { [IO.File]::WriteAllText($Output, $body, [Text.UTF8Encoding]::new($false)) }
Write-Output $title
