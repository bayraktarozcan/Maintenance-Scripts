# Pester 5 static tests for Tools/Install-Dependencies.ps1.
# Installation itself is verified manually; these tests pin the manifest
# (exact versions, per-user scope, side-effect-free -Check) so it cannot
# rot silently. Never installs anything.

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\Tools\Install-Dependencies.ps1'
    $errs = $null
    $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$toks, [ref]$errs)
    if ($errs.Count -gt 0) { throw ('Syntax errors in Install-Dependencies.ps1: ' + ($errs.Message -join '; ')) }
    $script:Text = [System.IO.File]::ReadAllText($script:ScriptPath) -replace "`r`n", "`n"
}

Describe 'Install-Dependencies manifest' {
    It 'Pins Pester 5.7.1' {
        $script:Text | Should -Match "'Pester 5\.7\.1'"
    }

    It 'Pins PowerShell 7.6.6' {
        $script:Text | Should -Match "'PowerShell 7\.6\.6'"
    }

    It 'Pins gitleaks 8.30.1' {
        $script:Text | Should -Match "'gitleaks 8\.30\.1'"
    }

    It 'Pins actionlint 1.7.12' {
        $script:Text | Should -Match "'actionlint 1\.7\.12'"
    }

    It 'Pins lychee 0.24.2' {
        $script:Text | Should -Match "'lychee 0\.24\.2'"
    }

    It 'Supports a side-effect-free -Check switch' {
        $script:Text | Should -Match '\[switch\]\$Check'
    }

    It 'Never installs machine-wide or elevated' {
        $script:Text | Should -Not -Match 'scope machine|--scope machine|-Scope AllUsers|RunAs|Start-Process'
    }
}
