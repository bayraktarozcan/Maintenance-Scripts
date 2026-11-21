# Maintenance Scripts - published release hygiene guard
# Reads every release from both hosts through the APIs and reports named checks.
# GitLab releases are public, so the read-only audit uses the unauthenticated
# REST endpoint; the keyring-backed glab CLI is only a local fallback. No
# write-capable token is ever passed to this checker.
# Usage:
#   powershell -NoProfile -File Tools/Check-ReleaseHygiene.ps1 -Check
[CmdletBinding()]
param(
    [switch]$Check,
    [string]$Fixtures,
    [string]$ChangelogPath
)

$ErrorActionPreference = 'Stop'
if (-not $ChangelogPath) { $ChangelogPath = Join-Path $PSScriptRoot '..\CHANGELOG.md' }
$script:Repo = 'bayraktarozcan/Maintenance-Scripts'
$script:GlProject = 'bayraktarozcan%2FMaintenance-Scripts'

function Get-ReleasesFromApi {
    param([string]$HostName)
    if ($HostName -eq 'GitHub') {
        $raw = & gh api --paginate "repos/$script:Repo/releases?per_page=100" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "GitHub API failed: $($raw -join ' ')" }
        return @(($raw | ConvertFrom-Json))
    }
    # Public project: no credential belongs in a read-only audit. Keep glab
    # only as the offline/local fallback, never as the privileged path.
    try {
        $url = "https://gitlab.com/api/v4/projects/$script:GlProject/releases?per_page=100"
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 30 -UseBasicParsing
        # Decode the body as UTF-8 explicitly: PS 5.1 otherwise reads JSON
        # without a charset as Latin-1 and turns em dashes into mojibake.
        $stream = $response.RawContentStream
        $jsonText = $response.Content
        if ($null -ne $stream -and $stream.Length -gt 0) {
            $stream.Position = 0
            $bytes = New-Object byte[] $stream.Length
            [void]$stream.Read($bytes, 0, $bytes.Length)
            $jsonText = [Text.Encoding]::UTF8.GetString($bytes)
        }
        # PS 5.1 pipes a JSON array as one object; assign first, then wrap so
        # the array is enumerated identically on every engine.
        $parsed = $jsonText | ConvertFrom-Json
        $items = @($parsed)
        if ($items.Count -eq 0) { throw 'empty release list' }
        return $items
    } catch {
        $raw = & glab api --paginate "projects/$script:GlProject/releases?per_page=100" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "GitLab API failed: $_; glab: $($raw -join ' ')" }
        return @(($raw | ConvertFrom-Json))
    }
}

function Get-CurrentTag {
    $changelog = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\CHANGELOG.md'))
    $match = [regex]::Match($changelog, '(?m)^###\s*V(\d+\.\d+\.\d+\.\d+)\s*[—–-]')
    if (-not $match.Success) { throw 'current version not found in CHANGELOG.md' }
    return 'v' + $match.Groups[1].Value
}

function Convert-ToRelease {
    param($Raw, [string]$HostName)
    return [pscustomobject]@{
        Host  = $HostName
        Tag   = [string]$Raw.tag_name
        Title = [string]$(if ($HostName -eq 'GitHub') { $Raw.name } else { $Raw.name })
        Body  = [string]$(if ($HostName -eq 'GitHub') { $Raw.body } else { $Raw.description })
    }
}

function Normalize-Text {
    param([string]$Text)
    return ($Text -replace "`r`n", "`n") -replace "`r", "`n"
}

function Get-NormalizedWords {
    param([string]$Text)
    $clean = [regex]::Replace($Text, '[^\p{L}\p{N} ]', ' ')
    return @($clean.ToLowerInvariant().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))
}

function Get-ChangelogBullets {
    param([string]$Text, [string]$Version, [switch]$Turkish)
    $marker = [regex]::Match($Text, '(?m)^## Türkçe\s*$')
    $half = if ($Turkish) {
        if ($marker.Success) { $Text.Substring($marker.Index) } else { '' }
    } else {
        if ($marker.Success) { $Text.Substring(0, $marker.Index) } else { $Text }
    }
    $lines = @($half -replace "`r`n", "`n" -split "`n")
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^###\s*V' + [regex]::Escape($Version) + '\s*[—–-]') { $start = $i; break }
    }
    if ($start -lt 0) { return @() }
    $bullets = @()
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^###\s+V\d' -or $lines[$i] -match '^##\s') { break }
        if ($lines[$i] -match '^\s*-\s+(.+)$') { $bullets += $Matches[1] }
    }
    return $bullets
}

function Test-ChangelogCoverage {
    param([object[]]$GitHub, [string]$ChangelogPath)
    if (-not (Test-Path -LiteralPath $ChangelogPath)) { return @('changelog-coverage: CHANGELOG.md not found') }
    $changelog = [IO.File]::ReadAllText($ChangelogPath)
    $uncovered = @()
    foreach ($rel in $GitHub) {
        $version = $rel.Tag.TrimStart('v', 'V')
        $body = Normalize-Text $rel.Body
        $halves = [regex]::Split($body, '(?m)^## v')
        $enBody = if ($halves.Count -ge 2) { $halves[1] } else { '' }
        $trBody = if ($halves.Count -ge 3) { $halves[2] } else { '' }
        foreach ($lang in @(@{ Turkish = $false; Body = $enBody }, @{ Turkish = $true; Body = $trBody })) {
            $bodyWords = @(Get-NormalizedWords $lang.Body)
            foreach ($bullet in @(Get-ChangelogBullets -Text $changelog -Version $version -Turkish:$lang.Turkish)) {
                $lead = @(Get-NormalizedWords $bullet | Select-Object -First 4)
                if ($lead.Count -eq 0) { continue }
                $missing = @($lead | Where-Object { $bodyWords -notcontains $_ })
                if ($missing.Count -gt 0) {
                    $label = if ($lang.Turkish) { 'TR' } else { 'EN' }
                    $uncovered += "$($rel.Tag)/$label`: $($lead -join ' ')"
                }
            }
        }
    }
    if ($uncovered.Count -gt 0) { return @('changelog-coverage: ' + ($uncovered -join '; ')) }
    return @()
}

function Test-NoteGenerator {
    param([string]$CurrentTag, [string]$GeneratorPath, [string]$RepoRoot)
    if (-not (Test-Path -LiteralPath $GeneratorPath)) { return @('note-generator: Build-ReleaseNotes.ps1 missing') }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('note-gen-' + [guid]::NewGuid().ToString('N') + '.md')
    try {
        $null = & $GeneratorPath -Version $CurrentTag.TrimStart('v', 'V') -Current -Output $tmp -Root $RepoRoot
        $body = [IO.File]::ReadAllText($tmp)
        $required = @('### Summary', '### Added', '### Files', '### Documentation',
            '### Özet', '### Eklenenler', '### Dosyalar', '### Belgelendirme')
        $missing = @($required | Where-Object { -not $body.Contains($_) })
        if ($missing.Count -gt 0) { return @('note-generator: missing ' + ($missing -join ', ')) }
        if ($body -notmatch '(?ms)^### Summary\s*\n+-\s+\S') { return @('note-generator: empty English summary') }
        if ($body -notmatch '(?ms)^### Özet\s*\n+-\s+\S') { return @('note-generator: empty Turkish summary') }
        return @()
    } catch {
        return @("note-generator: $_")
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}

function Test-ReleaseSet {
    param([object[]]$GitHub, [object[]]$GitLab, [string]$CurrentTag, [string]$ChangelogPath)
    $problems = @()
    $ghTags = @($GitHub | ForEach-Object { $_.Tag })
    $glTags = @($GitLab | ForEach-Object { $_.Tag })
    $onlyGh = @($ghTags | Where-Object { $glTags -notcontains $_ })
    $onlyGl = @($glTags | Where-Object { $ghTags -notcontains $_ })
    if ($onlyGh.Count -gt 0 -or $onlyGl.Count -gt 0 -or $ghTags.Count -eq 0) {
        $problems += "pair-count: GitHub=[$($ghTags -join ',')] GitLab=[$($glTags -join ',')]"
    }

    $badTitles = @()
    foreach ($rel in $GitHub) {
        $prefixed = $rel.Title.StartsWith('[DEPRECATED] ')
        $expected = if ($rel.Tag -eq $CurrentTag) { $false } else { $true }
        $shape = '(?:\[DEPRECATED\] )?' + [regex]::Escape($rel.Tag) + ' — \S'
        if ($rel.Title -notmatch "^$shape") { $badTitles += "$($rel.Tag): shape" }
        elseif ($prefixed -ne $expected) { $badTitles += "$($rel.Tag): prefix" }
        elseif (([regex]::Matches($rel.Title, [regex]::Escape($rel.Tag))).Count -ne 1) { $badTitles += "$($rel.Tag): repeated" }
    }
    if ($badTitles.Count -gt 0) { $problems += 'title-format: ' + ($badTitles -join '; ') }

    $badBodies = @()
    foreach ($rel in $GitHub) {
        $body = $rel.Body -replace "`r`n", "`n"
        $halves = [regex]::Split($body, '(?m)^## v')
        if ($halves.Count -lt 3) { $badBodies += "$($rel.Tag): no bilingual halves"; continue }
        $en = [regex]::Matches($halves[1], '(?m)^### (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
        $tr = [regex]::Matches(($halves[2] -replace '^', '## v'), '(?m)^### (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
        foreach ($required in @('Summary', 'Files', 'Documentation')) {
            if ($en -notcontains $required) { $badBodies += "$($rel.Tag): missing $required" }
        }
        foreach ($required in @('Özet', 'Dosyalar', 'Belgelendirme')) {
            if ($tr -notcontains $required) { $badBodies += "$($rel.Tag): missing $required" }
        }
        $enContent = @($en | Where-Object { $_ -in @('Added', 'Changed', 'Removed', 'Fixed') })
        $trContent = @($tr | Where-Object { $_ -in @('Eklenenler', 'Değiştirilenler', 'Kaldırılanlar', 'Düzeltilenler') })
        if ($enContent.Count -eq 0 -or $trContent.Count -eq 0) { $badBodies += "$($rel.Tag): no content sections" }
    }
    if ($badBodies.Count -gt 0) { $problems += 'body-structure: ' + ($badBodies -join '; ') }

    $garbage = @()
    foreach ($rel in $GitHub) {
        $body = $rel.Body
        if ($body -match '(?<!\w)#\d+\b') { $garbage += "$($rel.Tag): bare #N" }
        if ($body -match '<a id=|Table of Contents|İçindekiler') { $garbage += "$($rel.Tag): embedded TOC" }
        foreach ($other in $ghTags) {
            if ($other -ne $rel.Tag -and $body -match ('(?m)^## ' + [regex]::Escape($other) + ' —')) {
                $garbage += "$($rel.Tag): other version $other"
            }
        }
        if ($body -match '(?m)^#{1,2}\s*[^\n]*[\uD800-\uDFFF]') { $garbage += "$($rel.Tag): emoji heading" }
    }
    if ($garbage.Count -gt 0) { $problems += 'no-garbage: ' + ($garbage -join '; ') }

    $mismatch = @()
    $glByTag = @{}
    foreach ($rel in $GitLab) { $glByTag[$rel.Tag] = $rel }
    foreach ($rel in $GitHub) {
        if (-not $glByTag.ContainsKey($rel.Tag)) { continue }
        $other = $glByTag[$rel.Tag]
        if ((Normalize-Text $rel.Title) -cne (Normalize-Text $other.Title)) { $mismatch += "$($rel.Tag): title" }
        if ((Normalize-Text $rel.Body) -cne (Normalize-Text $other.Body)) { $mismatch += "$($rel.Tag): body" }
    }
    if ($mismatch.Count -gt 0) { $problems += 'cross-host: ' + ($mismatch -join '; ') }

    $coverage = @(Test-ChangelogCoverage -GitHub $GitHub -ChangelogPath $ChangelogPath)
    if ($coverage.Count -gt 0) { $problems += $coverage }
    return $problems
}

function Invoke-Main {
    if ($Fixtures) {
        $data = Get-Content -LiteralPath $Fixtures -Raw | ConvertFrom-Json
        $gh = @($data.gh | ForEach-Object { Convert-ToRelease $_ 'GitHub' })
        $gl = @($data.gl | ForEach-Object { Convert-ToRelease $_ 'GitLab' })
        $current = $data.current
    } else {
        $current = Get-CurrentTag
        $gh = @(Get-ReleasesFromApi 'GitHub' | ForEach-Object { Convert-ToRelease $_ 'GitHub' })
        $gl = @(Get-ReleasesFromApi 'GitLab' | ForEach-Object { Convert-ToRelease $_ 'GitLab' })
    }
    $problems = @(Test-ReleaseSet -GitHub $gh -GitLab $gl -CurrentTag $current -ChangelogPath $ChangelogPath)
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $generator = Join-Path $PSScriptRoot 'Build-ReleaseNotes.ps1'
    $problems += @(Test-NoteGenerator -CurrentTag $current -GeneratorPath $generator -RepoRoot $repoRoot)
    $names = @('pair-count', 'title-format', 'body-structure', 'no-garbage', 'cross-host', 'changelog-coverage', 'note-generator')
    foreach ($name in $names) {
        $hits = @($problems | Where-Object { $_ -like "$name*" })
        if ($hits.Count -eq 0) { Write-Host "PASS $name"; continue }
        foreach ($hit in $hits) { Write-Host "FAIL $hit" }
    }
    if ($problems.Count -gt 0) { return 1 }
    Write-Host "OK: $($gh.Count) releases hygienic on both hosts"
    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-Main)
}
