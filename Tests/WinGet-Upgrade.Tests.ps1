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
}

Describe 'WinGet-Upgrade log skeleton' {
    It 'Starts with @echo off and ends with pause' {
        $nonEmpty = @($script:Lines | Where-Object { $_.Trim() -ne '' })
        $nonEmpty[0] | Should -Be '@echo off'
        $nonEmpty[-1] | Should -Be 'pause'
    }

    It 'Keeps the timestamp, log folder, index, and BOM stamp' {
        $script:Text | Should -Match 'yyyyMMdd_HHmmss'
        $script:Text | Should -Match 'Logs\\WinGet-Upgrade'
        $script:Text | Should -Match 'index\.txt'
        $script:Text | Should -Match '0xEF,0xBB,0xBF'
    }
}
