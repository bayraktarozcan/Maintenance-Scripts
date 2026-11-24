# Pester 5 static tests for Scripts/WinGet-Upgrade.bat.
# Runtime behavior is verified manually; these tests pin the standing
# contract: no self-elevation, no execution-policy bypass, the established
# upgrade flags, and the log skeleton. Never executes the script or winget.

BeforeAll {
    $script:BatPath = Join-Path $PSScriptRoot '..\Scripts\WinGet-Upgrade.bat'
    $script:Text = [System.IO.File]::ReadAllText($script:BatPath) -replace "`r`n", "`n"
    $script:Lines = $script:Text -split "`n"
}

Describe 'WinGet-Upgrade static hygiene' {
    It 'Never self-elevates' {
        $script:Text | Should -Not -Match 'RunAs|Start-Process|-Verb RunAs'
    }

    It 'Never passes -ExecutionPolicy Bypass' {
        $script:Text | Should -Not -Match 'Bypass'
    }

    It 'Keeps the established upgrade flags' {
        $script:Text | Should -Match '--include-unknown --accept-source-agreements --accept-package-agreements'
    }

    It 'Announces each download before the winget command runs' {
        $source = [regex]::Match($script:Text, 'echo Downloading: winget source metadata\.\.\.')
        $upgrade = [regex]::Match($script:Text, 'echo Downloading: available winget packages\.\.\.')
        $source.Success | Should -BeTrue
        $upgrade.Success | Should -BeTrue
        $script:Text.IndexOf('winget source update > "%OUT%"') | Should -BeGreaterThan $source.Index
        $script:Text.IndexOf('winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements > "%OUT%"') | Should -BeGreaterThan $upgrade.Index
        $script:Text | Should -Match '>>"%LOG%" echo Downloading: winget source metadata\.\.\.'
        $script:Text | Should -Match '>>"%LOG%" echo Downloading: available winget packages\.\.\.'
    }
}

Describe 'WinGet-Upgrade log skeleton' {
    It 'Starts with @echo off and ends with a pause and exit code' {
        $nonEmpty = @($script:Lines | Where-Object { $_.Trim() -ne '' })
        $nonEmpty[0] | Should -Be '@echo off'
        $nonEmpty[-2] | Should -Be 'pause'
        $nonEmpty[-1] | Should -Be 'exit /b %EXITCODE%'
    }

    It 'Keeps the timestamp, log folder, index, and BOM stamp' {
        $script:Text | Should -Match 'yyyyMMdd_HHmmss'
        $script:Text | Should -Match 'Logs\\WinGet-Upgrade'
        $script:Text | Should -Match 'index\.txt'
        $script:Text | Should -Match '0xEF,0xBB,0xBF'
    }
}
