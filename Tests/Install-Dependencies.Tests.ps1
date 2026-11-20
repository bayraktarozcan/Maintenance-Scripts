# Pester static tests for Tools/Install-Dependencies.ps1.
# Installation itself is verified manually; these tests pin the manifest
# (latest versions, per-user scope, side-effect-free -Check) so it cannot
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
    It 'Uses latest Pester (no version pin)' {
        $script:Text | Should -Match "Install-Module Pester -Force"
        $script:Text | Should -Not -Match 'RequiredVersion'
        $script:Text | Should -Not -Match "'Pester [0-9]"
    }

    It 'Requires PowerShell 7+' {
        $script:Text | Should -Match "'PowerShell 7\+'"
        $script:Text | Should -Match 'Test-Pwsh7OrNewer'
        $script:Text | Should -Match "Install-Winget 'Microsoft\.PowerShell'"
    }

    It 'Installs gitleaks at latest' {
        $script:Text | Should -Match "Install-Winget 'Gitleaks\.Gitleaks'"
        $script:Text | Should -Not -Match "'gitleaks [0-9]"
    }

    It 'Installs actionlint at latest' {
        $script:Text | Should -Match "Install-Winget 'rhysd\.actionlint'"
        $script:Text | Should -Not -Match "'actionlint [0-9]"
    }

    It 'Installs lychee at latest' {
        $script:Text | Should -Match "Install-Winget 'lycheeverse\.lychee'"
        $script:Text | Should -Not -Match "'lychee [0-9]"
    }

    It 'Uses exact-version probes nowhere' {
        $script:Text | Should -Not -Match 'Test-ModuleVersion|Test-ToolVersion|Test-PwshVersion'
        $script:Text | Should -Not -Match '--exact'
    }

    It 'Supports a side-effect-free -Check switch' {
        $script:Text | Should -Match '\[switch\]\$Check'
    }

    It 'Never installs machine-wide or elevated' {
        $script:Text | Should -Not -Match 'scope machine|--scope machine|-Scope AllUsers|RunAs|Start-Process'
    }
}
