# Release metadata is derived from CHANGELOG.md, the canonical source.
# These guards pin the title/body rules added to AGENTS.md §Versioning.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Script = Join-Path $script:Root 'Tools/Build-ReleaseNotes.ps1'

    function Get-Metadata {
        param([string]$Version, [switch]$Current, [string]$RepoRoot = $script:Root)
        $out = Join-Path ([IO.Path]::GetTempPath()) ('notes-' + [guid]::NewGuid().ToString('N') + '.md')
        try {
            $argsList = @('-NoProfile', '-File', $script:Script, $Version, '-Output', $out, '-Root', $RepoRoot)
            if ($Current) { $argsList += '-Current' }
            $result = @(& powershell @argsList 2>&1)
            if ($LASTEXITCODE -ne 0) { throw ($result | Out-String) }
            $title = $result | Select-Object -First 1
            $body = if (Test-Path -LiteralPath $out) { [IO.File]::ReadAllText($out) } else { '' }
            return @{ Title = $title; Body = $body }
        } finally {
            if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force }
        }
    }

    $script:Current = Get-Metadata -Version '0.1.1.2' -Current
    $script:Older = Get-Metadata -Version '0.1.1.1'
}

Describe 'Canonical release titles' {
    It 'Names the current tag once, with no deprecation prefix' {
        $script:Current.Title | Should -Match '^v0\.1\.1\.2 — \S'
        $script:Current.Title | Should -Not -Match '\[DEPRECATED\]'
        ([regex]::Matches($script:Current.Title, 'v0\.1\.1\.2')).Count | Should -Be 1
    }

    It 'Puts the deprecation marker at the front of older titles' {
        $script:Older.Title | Should -Match '^\[DEPRECATED\] v0\.1\.1\.1 — \S'
        $script:Older.Title | Should -Not -Match 'v0\.1\.1\.1.*\[DEPRECATED\]'
    }

    It 'Keeps mixed-case names and uppercase acronyms in the title' {
        $script:Older.Title | Should -Match 'CI'
        $script:Older.Title | Should -Match 'Latest-Version Policy'
    }
}

Describe 'Canonical bilingual bodies' {
    It 'Emits both language halves with the full section set' {
        $body = $script:Current.Body
        $body | Should -Match '(?m)^## v0\.1\.1\.2 — '
        $body | Should -Match '(?m)^### Summary\s*$'
        $body | Should -Match '(?m)^### Added\s*$'
        $body | Should -Match '(?m)^### Changed\s*$'
        $body | Should -Match '(?m)^### Removed\s*$'
        $body | Should -Match '(?m)^### Fixed\s*$'
        $body | Should -Match '(?m)^### Files\s*$'
        $body | Should -Match '(?m)^### Documentation\s*$'
        $body | Should -Match '(?m)^### Özet\s*$'
        $body | Should -Match '(?m)^### Eklenenler\s*$'
        $body | Should -Match '(?m)^### Değiştirilenler\s*$'
        $body | Should -Match '(?m)^### Kaldırılanlar\s*$'
        $body | Should -Match '(?m)^### Düzeltilenler\s*$'
        $body | Should -Match '(?m)^### Dosyalar\s*$'
        $body | Should -Match '(?m)^### Belgelendirme\s*$'
    }

    It 'Writes EF/BOM-free LF text with no trailing whitespace' {
        $script:Current.Body | Should -Not -Match "`r"
        $script:Current.Body | Should -Not -Match '(?m)[ \t]+$'
    }

    It 'Rejects an empty changelog section' {
        { Get-Metadata -Version '9.9.9.9' } | Should -Throw '*no CHANGELOG section*'
    }

    It 'Strips bare issue numbers and changelog TOC rows from a planted section' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('notes-plant-' + [guid]::NewGuid().ToString('N'))
        try {
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
            $source = [IO.File]::ReadAllText((Join-Path $script:Root 'CHANGELOG.md'))
            $planted = $source.Replace(
                'Post-release hardening: dotted versions compare numerically',
                'Planted #5 row for a guard. Post-release hardening: dotted versions compare numerically'
            )
            [IO.File]::WriteAllText((Join-Path $tmp 'CHANGELOG.md'), $planted)
            $metadata = Get-Metadata -Version '0.1.1.2' -Current -RepoRoot $tmp
            $metadata.Body | Should -Not -Match '(?<!\w)#\d+\b'
            $metadata.Body | Should -Match 'Planted row for a guard'
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        }
    }
}
