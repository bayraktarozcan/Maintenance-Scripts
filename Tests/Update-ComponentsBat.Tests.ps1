# Pester 5 static tests for Scripts/Update-Components.bat.
# Runtime behavior is verified manually; these tests pin the standing
# contract: no self-elevation, no execution-policy bypass, argument
# forwarding, and the log skeleton. Never executes the script.

BeforeAll {
    $script:BatPath = Join-Path $PSScriptRoot '..\Scripts\Update-Components.bat'
    $script:Text = [System.IO.File]::ReadAllText($script:BatPath) -replace "`r`n", "`n"
    $script:Lines = $script:Text -split "`n"
}

Describe 'Update-Components.bat static hygiene' {
    It 'Never self-elevates' {
        $script:Text | Should -Not -Match 'RunAs|Start-Process|-Verb RunAs'
    }

    It 'Never passes -ExecutionPolicy Bypass' {
        $script:Text | Should -Not -Match 'Bypass'
    }
}

Describe 'Update-Components.bat log skeleton' {
    It 'Starts with @echo off and ends with pause' {
        $nonEmpty = @($script:Lines | Where-Object { $_.Trim() -ne '' })
        $nonEmpty[0] | Should -Be '@echo off'
        $nonEmpty[-1] | Should -Be 'pause'
    }

    It 'Keeps the timestamp, log folder, index, and BOM stamp' {
        $script:Text | Should -Match 'yyyyMMdd_HHmmss'
        $script:Text | Should -Match 'Logs\\Update-Components'
        $script:Text | Should -Match 'index\.txt'
        $script:Text | Should -Match '0xEF,0xBB,0xBF'
    }

    It 'Forwards arguments to Tools/Update-Components.ps1' {
        $script:Text | Should -Match 'Tools\\Update-Components\.ps1'
        $script:Text | Should -Match '-File "%SCRIPT%" %\*'
    }
}
