# Maintenance Scripts - published release hygiene guard
# Reads every release from both hosts through the APIs and reports named checks.
# CI has no glab, so GitLab uses REST when GITLAB_TOKEN is injected; locally the
# keyring-backed glab CLI is the fallback. Read-only, no repository changes.
# Usage:
#   powershell -NoProfile -File Tools/Check-ReleaseHygiene.ps1 -Check
[CmdletBinding()]
param(
    [switch]$Check,
    [string]$Fixtures
)

$ErrorActionPreference = 'Stop'
$script:Repo = 'bayraktarozcan/Maintenance-Scripts'
$script:GlProject = 'bayraktarozcan%2FMaintenance-Scripts'

function Get-ReleasesFromApi {
    param([string]$HostName)
    if ($HostName -eq 'GitHub') {
        $raw = & gh api --paginate "repos/$script:Repo/releases?per_page=100" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "GitHub API failed: $($raw -join ' ')" }
        return @(($raw | ConvertFrom-Json))
    }
    if ($env:GITLAB_TOKEN) {
        $url = "https://gitlab.com/api/v4/projects/$script:GlProject/releases?per_page=100"
        $headers = @{ 'PRIVATE-TOKEN' = $env:GITLAB_TOKEN }
        $raw = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 30
        return @($raw)
    }
    $raw = & glab api --paginate "projects/$script:GlProject/releases?per_page=100" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "GitLab API failed: $($raw -join ' ')" }
    return @(($raw | ConvertFrom-Json))
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

function Test-ReleaseSet {
    param([object[]]$GitHub, [object[]]$GitLab, [string]$CurrentTag)
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
    $problems = @(Test-ReleaseSet -GitHub $gh -GitLab $gl -CurrentTag $current)
    $names = @('pair-count', 'title-format', 'body-structure', 'no-garbage', 'cross-host')
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
