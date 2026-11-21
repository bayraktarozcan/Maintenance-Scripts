# The canonical version lives in CHANGELOG.md. Prose that names a concrete
# release must follow it; a stale example is a documentation defect, not a
# historical record. The gitignored mirror is checked only when present, so
# the guard works in a clean CI checkout.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    function Get-CanonicalVersion {
        $text = [IO.File]::ReadAllText((Join-Path $script:Root 'CHANGELOG.md'))
        $match = [regex]::Match($text, '(?m)^###\s*V(\d+\.\d+\.\d+\.\d+)\s*[—–-]')
        if (-not $match.Success) { throw 'current version not found in CHANGELOG.md' }
        return 'v' + $match.Groups[1].Value
    }

    function Find-StaleVersions {
        param([string]$Text, [string]$Current)
        return @([regex]::Matches($Text, 'v0\.1\.1\.\d+') |
            ForEach-Object { $_.Value } | Where-Object { $_ -cne $Current } | Select-Object -Unique)
    }
}

Describe 'Version parity' {
    It 'Derives a well-formed current version from the changelog' {
        $current = Get-CanonicalVersion
        $current | Should -Match '^v\d+\.\d+\.\d+\.\d+$'
    }

    It 'Keeps the canonical version in both agent guides' {
        $current = Get-CanonicalVersion
        $canonical = [IO.File]::ReadAllText((Join-Path $script:Root 'AGENTS.md'))
        $schemePattern = 'four-part \(`' + [regex]::Escape($current) + '`'
        $historyPattern = 'keeps the history \(`' + [regex]::Escape($current) + '`'
        $canonical | Should -Match $schemePattern
        $canonical | Should -Match $historyPattern
        Find-StaleVersions -Text $canonical -Current $current | Should -BeNullOrEmpty

        $mirror = Join-Path $script:Root ('AGENTS-' + 'TR' + '.md')
        if (Test-Path -LiteralPath $mirror) {
            $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $mirror).Path)
            $mirrorPattern = [regex]::Escape($current)
            $text | Should -Match $mirrorPattern
            Find-StaleVersions -Text $text -Current $current | Should -BeNullOrEmpty
        }
    }

    It 'Keeps user-facing docs free of concrete release versions' {
        $current = Get-CanonicalVersion
        $paths = @(git -C $script:Root ls-files 'README.md' 'Docs/*.md')
        $paths.Count | Should -BeGreaterThan 0
        foreach ($path in $paths) {
            $full = Join-Path $script:Root $path
            if (-not (Test-Path -LiteralPath $full)) { continue }
            $stale = @(Find-StaleVersions -Text ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $full).Path)) -Current $current)
            $stale | Should -BeNullOrEmpty -Because "$path names a concrete release"
        }
    }

    It 'Detects a planted stale version' {
        $current = Get-CanonicalVersion
        $stale = if ($current -eq 'v0.1.1.2') { 'v0.1.1.1' } else { 'v0.1.1.2' }
        Find-StaleVersions -Text "Scheme: four-part ($stale)" -Current $current | Should -Contain $stale
    }
}
