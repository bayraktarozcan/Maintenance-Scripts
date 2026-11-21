# Published release hygiene: every named check must pass on a clean set and
# fail when its specific defect is planted. Fixtures avoid network calls.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Script = Join-Path $script:Root 'Tools/Check-ReleaseHygiene.ps1'
    . $script:Script

    $script:Changelog = Join-Path ([IO.Path]::GetTempPath()) ('hygiene-cl-' + [guid]::NewGuid().ToString('N') + '.md')
    @'
## English

### V0.1.1.2 — 2026-11-21

### V0.1.1.1 — 2026-11-21

## Türkçe

### V0.1.1.2 — 2026-11-21

### V0.1.1.1 — 2026-11-21
'@ | Set-Content -LiteralPath $script:Changelog -Encoding UTF8

    $enBody = @'
## v0.1.1.2 — Post-Release Hardening

### Summary

- Summary text.

### Added

- A feature.

### Changed

- A change.

### Removed

- None in this release.

### Fixed

- A fix.

### Files

- `Tools/File.ps1`

### Documentation

- `Docs/Page.md`

---

## v0.1.1.2 — Yayın Sonrası Sağlamlaştırma

### Özet

- Özet metni.

### Eklenenler

- Bir özellik.

### Değiştirilenler

- Bir değişiklik.

### Kaldırılanlar

- Bu sürümde yok.

### Düzeltilenler

- Bir düzeltme.

### Dosyalar

- `Tools/File.ps1`

### Belgelendirme

- `Docs/Page.md`
'@

    function New-Release {
        param([string]$Tag, [string]$Title, [string]$Body)
        return [pscustomobject]@{ Tag = $Tag; Title = $Title; Body = $Body }
    }

    function New-Sets {
        return @{
            gh      = @(
                New-Release 'v0.1.1.2' 'v0.1.1.2 — Post-Release Hardening' $enBody
                New-Release 'v0.1.1.1' '[DEPRECATED] v0.1.1.1 — Latest-Version Policy' ($enBody -replace 'v0\.1\.1\.2', 'v0.1.1.1')
            )
            gl      = @(
                New-Release 'v0.1.1.2' 'v0.1.1.2 — Post-Release Hardening' $enBody
                New-Release 'v0.1.1.1' '[DEPRECATED] v0.1.1.1 — Latest-Version Policy' ($enBody -replace 'v0\.1\.1\.2', 'v0.1.1.1')
            )
            current = 'v0.1.1.2'
        }
    }
}

Describe 'Published release hygiene' {
    AfterAll {
        if (Test-Path -LiteralPath $script:Changelog) { Remove-Item -LiteralPath $script:Changelog -Force }
    }

    It 'has a tracked guard with the seven named checks' {
        Test-Path -LiteralPath $script:Script | Should -BeTrue
        $text = [IO.File]::ReadAllText($script:Script)
        foreach ($name in @('pair-count', 'title-format', 'body-structure', 'no-garbage', 'cross-host', 'changelog-coverage', 'note-generator')) {
            $text | Should -Match $name
        }
    }

    It 'passes a clean two-host set' {
        $sets = New-Sets
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
        $problems | Should -BeNullOrEmpty
    }

    It 'fails title-format when the marker is at the end' {
        $sets = New-Sets
        $rel = $sets.gh[1]
        $rel.Title = 'v0.1.1.1 — Latest-Version Policy [DEPRECATED]'
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
        ($problems -join ' ') | Should -Match 'title-format'
    }

    It 'fails body-structure when the Turkish half is removed' {
        $sets = New-Sets
        $rel = $sets.gh[0]
        $rel.Body = ($enBody -split '---')[0]
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
        ($problems -join ' ') | Should -Match 'body-structure'
    }

    It 'fails no-garbage for a bare issue token' {
        $sets = New-Sets
        $rel = $sets.gh[0]
        $rel.Body = $enBody + "`n- fixes #5`n"
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
        ($problems -join ' ') | Should -Match 'no-garbage'
    }

    It 'fails cross-host when one body differs' {
        $sets = New-Sets
        $sets.gl[0].Body = $enBody + "`n"
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
        ($problems -join ' ') | Should -Match 'cross-host'
    }

    It 'fails pair-count when a tag is missing on one host' {
        $sets = New-Sets
        $sets.gl = @($sets.gl[0])
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
        ($problems -join ' ') | Should -Match 'pair-count'
    }

    It 'reports failures by name through the CLI with fixture input' {
        $sets = New-Sets
        $sets.gh[0].Body = $enBody + "`n- fixes #5`n"
        $file = Join-Path ([IO.Path]::GetTempPath()) ('hygiene-' + [guid]::NewGuid().ToString('N') + '.json')
        try {
            [IO.File]::WriteAllText($file, ($sets | ConvertTo-Json -Depth 8 -Compress))
            $engine = (Get-Process -Id $PID).Path
            $out = @(& $engine -NoProfile -File $script:Script -Fixtures $file -ChangelogPath $script:Changelog 2>&1)
            ($out -join "`n") | Should -Match 'FAIL no-garbage'
            $LASTEXITCODE | Should -Be 1
        } finally {
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
        }
    }

    It 'fails changelog-coverage when a released bullet is absent from the notes' {
        $sets = New-Sets
        $original = [IO.File]::ReadAllText($script:Changelog)
        try {
            $planted = $original.Replace(
                '### V0.1.1.2 — 2026-11-21',
                "### V0.1.1.2 — 2026-11-21`n`n- Unreleased capability absent from notes."
            )
            [IO.File]::WriteAllText($script:Changelog, $planted)
            $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current -ChangelogPath $script:Changelog)
            ($problems -join ' ') | Should -Match 'changelog-coverage'
        } finally {
            [IO.File]::WriteAllText($script:Changelog, $original)
        }
    }

    It 'The generator emits canonical bilingual notes for the current tag' {
        $generator = Join-Path $script:Root 'Tools/Build-ReleaseNotes.ps1'
        $problems = @(Test-NoteGenerator -CurrentTag 'v0.1.1.2' -GeneratorPath $generator -RepoRoot $script:Root)
        $problems | Should -BeNullOrEmpty
    }

    It 'Reads GitLab without a write-capable credential' {
        $workflow = [IO.File]::ReadAllText((Join-Path $script:Root '.github/workflows/hygiene.yml'))
        $workflow | Should -Not -Match 'GITLAB_PUSH_TOKEN'
        $guard = [IO.File]::ReadAllText($script:Script)
        $guard | Should -Not -Match 'PRIVATE-TOKEN'
        $guard | Should -Match 'Invoke-WebRequest'
        $guard | Should -Match 'glab api'
    }
}
