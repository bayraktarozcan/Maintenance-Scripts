# Published release hygiene: every named check must pass on a clean set and
# fail when its specific defect is planted. Fixtures avoid network calls.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Script = Join-Path $script:Root 'Tools/Check-ReleaseHygiene.ps1'
    . $script:Script

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
    It 'has a tracked guard with the five named checks' {
        Test-Path -LiteralPath $script:Script | Should -BeTrue
        $text = [IO.File]::ReadAllText($script:Script)
        foreach ($name in @('pair-count', 'title-format', 'body-structure', 'no-garbage', 'cross-host')) {
            $text | Should -Match $name
        }
    }

    It 'passes a clean two-host set' {
        $sets = New-Sets
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current)
        $problems | Should -BeNullOrEmpty
    }

    It 'fails title-format when the marker is at the end' {
        $sets = New-Sets
        $rel = $sets.gh[1]
        $rel.Title = 'v0.1.1.1 — Latest-Version Policy [DEPRECATED]'
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current)
        ($problems -join ' ') | Should -Match 'title-format'
    }

    It 'fails body-structure when the Turkish half is removed' {
        $sets = New-Sets
        $rel = $sets.gh[0]
        $rel.Body = ($enBody -split '---')[0]
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current)
        ($problems -join ' ') | Should -Match 'body-structure'
    }

    It 'fails no-garbage for a bare issue token' {
        $sets = New-Sets
        $rel = $sets.gh[0]
        $rel.Body = $enBody + "`n- fixes #5`n"
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current)
        ($problems -join ' ') | Should -Match 'no-garbage'
    }

    It 'fails cross-host when one body differs' {
        $sets = New-Sets
        $sets.gl[0].Body = $enBody + "`n"
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current)
        ($problems -join ' ') | Should -Match 'cross-host'
    }

    It 'fails pair-count when a tag is missing on one host' {
        $sets = New-Sets
        $sets.gl = @($sets.gl[0])
        $problems = @(Test-ReleaseSet -GitHub $sets.gh -GitLab $sets.gl -CurrentTag $sets.current)
        ($problems -join ' ') | Should -Match 'pair-count'
    }

    It 'reports failures by name through the CLI with fixture input' {
        $sets = New-Sets
        $sets.gh[0].Body = $enBody + "`n- fixes #5`n"
        $file = Join-Path ([IO.Path]::GetTempPath()) ('hygiene-' + [guid]::NewGuid().ToString('N') + '.json')
        try {
            [IO.File]::WriteAllText($file, ($sets | ConvertTo-Json -Depth 8 -Compress))
            $out = @(& powershell -NoProfile -File $script:Script -Fixtures $file 2>&1)
            ($out -join "`n") | Should -Match 'FAIL no-garbage'
            $LASTEXITCODE | Should -Be 1
        } finally {
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
        }
    }
}
