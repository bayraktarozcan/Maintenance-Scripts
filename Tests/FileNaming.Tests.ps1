# The naming convention in AGENTS.md §Naming is a rule that can rot silently.
# This guard reads the tracked tree; only platform/tool-fixed paths are exempt.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:PlatformRoot = @(
        '.editorconfig', '.gitattributes', '.gitignore', '.gitlab-ci.yml',
        'README.md', 'CHANGELOG.md', 'AGENTS.md', 'CODEOWNERS', 'LICENSE', 'NOTICE'
    )

    function Get-NamingViolations {
        param([string[]]$Paths)
        $bad = @()
        foreach ($path in $Paths) {
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            if ($path -match '^(\.github|\.githooks)/') { continue }
            $leaf = Split-Path -Leaf $path
            if ($leaf -like '.*') { continue }
            $stem = [IO.Path]::GetFileNameWithoutExtension($leaf)
            $directory = Split-Path -Parent $path
            if (-not $directory) {
                if ($script:PlatformRoot -contains $leaf) { continue }
                if ($stem -cnotmatch '^[A-Z][A-Z0-9_-]*$') { $bad += "$path : root name is not UPPER" }
                continue
            }
            $top = ($path -split '/')[0]
            if ($top -cnotmatch '^[A-Z][A-Za-z0-9]*$') {
                $bad += "$path : top directory is not PascalCase"
                continue
            }
            if ($path -match '^Docs/') {
                foreach ($part in ($stem -split '-')) {
                    if ($part -cnotmatch '^[A-Z]') { $bad += "$path : Docs word '$part' is not capitalized" }
                }
                continue
            }
            if ($path -match '^Tests/.*\.Tests\.ps1$') {
                $name = $leaf -replace '\.Tests\.ps1$', ''
                if ($name -cnotmatch '^[A-Z]') { $bad += "$path : test name is not PascalCase" }
                continue
            }
            if ($leaf -match '\.py$') {
                if ($stem -cnotmatch '^[a-z][a-z0-9_]*$') { $bad += "$path : Python module is not snake_case" }
                continue
            }
            if ($stem -cnotmatch '^[A-Z]') { $bad += "$path : file name is not PascalCase" }
        }
        return $bad
    }
}

Describe 'File naming invariants' {
    It 'Declares the rule and the platform exemptions' {
        $canonical = [IO.File]::ReadAllText((Join-Path $script:Root 'AGENTS.md'))
        $canonical | Should -Match '### Naming'
        $canonical | Should -Match 'HyphenatedPascalCase'
        (Join-Path $script:Root 'AGENTS.md') | Should -Exist
    }

    It 'Finds no naming violation in the tracked tree' {
        $tracked = @(git -C $script:Root ls-files)
        $tracked.Count | Should -BeGreaterThan 0
        $bad = @(Get-NamingViolations $tracked)
        $bad | Should -BeNullOrEmpty -Because ('naming drift: ' + ($bad -join '; '))
    }

    It 'Detects a planted violation in each category' {
        $planted = @('tools/bad-name.ps1', 'docs/bad-name.md', 'badname.md', 'Tests/bad.Tests.ps1', 'Tools/BadModule.py')
        $found = @(Get-NamingViolations $planted)
        $found.Count | Should -BeGreaterThan 3
        ($found -join ' ') | Should -Match 'top directory'
        ($found -join ' ') | Should -Match 'not UPPER'
        ($found -join ' ') | Should -Match 'snake_case'
    }
}
