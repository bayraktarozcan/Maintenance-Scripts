# Pester 5 static checks for Repair-Windows.bat logging.
# No maintenance command is executed and no system state is touched.

BeforeAll {
    $script:Bat = Join-Path $PSScriptRoot '..\Scripts\Repair-Windows.bat'
    $script:Text = [System.IO.File]::ReadAllText($script:Bat)
    $script:Lines = [System.IO.File]::ReadAllLines($script:Bat)
}

Describe 'Repair-Windows logging' {
    It 'keeps the nine maintenance commands in their original order' {
        $expected = @(
            'DISM /Online /Cleanup-Image /CheckHealth > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /ScanHealth > "%OUT%" 2>&1',
            'net start wuauserv > "%OUT%" 2>&1',
            'net start bits > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /RestoreHealth > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase > "%OUT%" 2>&1',
            'sfc /scannow > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1'
        )
        $actual = @($script:Lines | Where-Object { $_ -match '^(DISM|net start|sfc) ' })
        $actual | Should -Be $expected
    }

    It 'captures the exit code immediately after each stage command' {
        $stageCommands = @(
            'DISM /Online /Cleanup-Image /CheckHealth > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /ScanHealth > "%OUT%" 2>&1',
            'net start wuauserv > "%OUT%" 2>&1',
            'net start bits > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /RestoreHealth > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase > "%OUT%" 2>&1',
            'sfc /scannow > "%OUT%" 2>&1',
            'DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1'
        )
        $found = 0
        for ($i = 0; $i -lt $script:Lines.Count; $i++) {
            if ($script:Lines[$i] -ne $stageCommands[$found]) { continue }
            $n = $found + 1
            $script:Lines[$i + 1] | Should -Be "set `"S$n`_RC=%ERRORLEVEL%`""
            $script:Lines[$i + 2] | Should -Be "call :StopTimer `"%S$n`_START%`" S$n`_MS"
            $found++
            if ($found -eq $stageCommands.Count) { break }
        }
        $found | Should -Be $stageCommands.Count
    }

    It 'writes start, end, exit code, and elapsed time for every stage' {
        foreach ($n in 1..9) {
            $script:Text | Should -Match ([regex]::Escape("call :StartTimer S${n}_START"))
            $script:Text | Should -Match ([regex]::Escape("[%END_HUMAN%] (${n}/9) rc=%S${n}_RC% elapsed=%S${n}_MS% ms"))
        }
        $script:Text | Should -Match ([regex]::Escape("ToString('yyyy-MM-dd HH:mm:ss.fff')"))
    }

    It 'measures total wall time around all nine stages' {
        $start = [Array]::IndexOf($script:Lines, 'call :StartTimer TOTAL_START')
        $stop = [Array]::IndexOf($script:Lines, 'call :StopTimer "%TOTAL_START%" TOTAL_MS')
        $start | Should -BeGreaterThan -1
        $stop | Should -BeGreaterThan $start
    }

    It 'prints a summary line for every stage and a total line' {
        foreach ($n in 1..9) {
            $script:Text | Should -Match ([regex]::Escape("call :SummaryLine $n "))
        }
        $script:Text | Should -Match ([regex]::Escape('TOTAL - %DUR% - %OVERALL%'))
    }
}

Describe 'Repair-Windows exit-code classification' {
    It 'treats net start code 2 as already running, not as failure' {
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="2" set "RESULT=OK"'))
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="2" set "NOTE=(already running)"'))
    }

    It 'treats DISM code 3010 as success with restart required' {
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="3010" set "RESULT=REBOOT"'))
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="3010" set "NOTE=(restart required)"'))
    }

    It 'does not blindly turn an SFC nonzero code into success or failure' {
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="1" set "RESULT=REVIEW"'))
        $script:Text | Should -Match ([regex]::Escape('if not "%RC%"=="0" if not "%RC%"=="1" if not "%RC%"=="2" if not "%RC%"=="3" set "RESULT=REVIEW"'))
    }

    It 'never reports success when stage evidence is missing' {
        $script:Text | Should -Match ([regex]::Escape('if "%MS%"=="NA" set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if not defined MS set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if not defined RC set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if %MISSINGCOUNT% GTR 0 set "OVERALL=INDETERMINATE"'))
    }
}
