# A local-only layer is never named in tracked output beyond its ignore
# pattern. The canonical rule lives in AGENTS.md; this guard keeps a future
# edit from leaking the private file name back into prose or tooling.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:PrivatePatterns = @('AGENTS-TR\.md')
    $script:Allowed = @('.gitignore')

    function Test-PrivateName {
        param([string]$Text)
        foreach ($pattern in $script:PrivatePatterns) {
            if ($Text -match $pattern) { return $true }
        }
        return $false
    }
}

Describe 'Hidden layer name invariants' {
    It 'Detects a planted private name and accepts abstract prose' {
        Test-PrivateName 'the gitignored Turkish mirror' | Should -BeFalse
        Test-PrivateName 'see the gitignored mirror file' | Should -BeFalse
        Test-PrivateName ('see the gitignored AGENTS-' + 'TR' + '.md file') | Should -BeTrue
    }

    It 'Finds no undeclared tracked file that names the private layer' {
        $offenders = @()
        foreach ($path in (git -C $script:RepoRoot ls-files)) {
            if ($script:Allowed -contains $path) { continue }
            $full = Join-Path $script:RepoRoot $path
            if (-not (Test-Path -LiteralPath $full)) { continue }
            if (Test-PrivateName ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $full).Path))) {
                $offenders += $path
            }
        }
        $offenders | Should -BeNullOrEmpty -Because ('private paths leaked into: ' + ($offenders -join ', '))
    }

    It 'Keeps the ignore declaration pointed at a real pattern' {
        $ignore = [IO.File]::ReadAllText((Join-Path $script:RepoRoot '.gitignore'))
        $ignore | Should -Match 'AGENTS-TR\.md'
    }
}
