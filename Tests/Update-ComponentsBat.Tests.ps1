# Pester 5 static tests for Scripts/Update-Components.bat.
# Runtime behavior is verified manually; these tests pin the standing
# contract: no self-elevation, no execution-policy bypass, argument
# forwarding, live streaming, and the log skeleton. Never executes the script.

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
    It 'Starts with @echo off and ends with a pause and exit code' {
        $nonEmpty = @($script:Lines | Where-Object { $_.Trim() -ne '' })
        $nonEmpty[0] | Should -Be '@echo off'
        $nonEmpty[-2] | Should -Be 'pause'
        $nonEmpty[-1] | Should -Be 'exit /b %EXITCODE%'
    }

    It 'Keeps the timestamp, log folder, index, and BOM stamp' {
        $script:Text | Should -Match 'yyyyMMdd_HHmmss'
        $script:Text | Should -Match 'Logs\\Update-Components'
        $script:Text | Should -Match 'index\.txt'
        $script:Text | Should -Match '0xEF,0xBB,0xBF'
    }

    It 'Forwards arguments to Tools/Update-Components.ps1' {
        $script:Text | Should -Match 'Tools\\Update-Components\.ps1'
        $script:Text | Should -Match '-File "%SCRIPT%" -LogPath "%LOG%" %\*'
    }

    It 'Streams updater output live instead of buffering it to a scratch file' {
        $script:Text | Should -Not -Match '>\s*"%OUT%"'
        $script:Text | Should -Not -Match 'type\s+"%OUT%"'
        $script:Text | Should -Match '-LogPath\s+"%LOG%"'
    }

    It 'Shows the exit prompt immediately with a single key press' {
        # A key-drain before pause swallowed the first press, so the message
        # appeared only after one press and a second press was needed to exit.
        $script:Text | Should -Not -Match 'KeyAvailable'
        $script:Text | Should -Not -Match 'ReadKey'
        $script:Text | Should -Match '(?m)^pause$'
    }
}
