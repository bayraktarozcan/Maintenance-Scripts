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
            $script:Lines[$i + 2] | Should -Be "call :StopTimer `"%S$n`_START%`" S$n`_MS `"%TIME%`""
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
        $script:Text | Should -Match ([regex]::Escape("CreateCustomTimeZone('Europe/Istanbul'"))
        $script:Text | Should -Match ([regex]::Escape('$env:RW_END_CLOCK'))
    }

    It 'measures total wall time around all nine stages' {
        $start = [Array]::IndexOf($script:Lines, 'call :StartTimer TOTAL_START')
        $stop = [Array]::IndexOf($script:Lines, 'call :StopTimer "%TOTAL_START%" TOTAL_MS "%TIME%"')
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
    It 'treats net start code 2 as already running only when the service state is running' {
        $script:Text | Should -Match ([regex]::Escape('call :NetState wuauserv'))
        $script:Text | Should -Match ([regex]::Escape('call :NetState bits'))
        $script:Text | Should -Match ([regex]::Escape('sc query "%~1" >nul 2>&1'))
        $script:Text | Should -Match ([regex]::Escape('if "%SVC_RC%"=="1060" set "SVC_STATE=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('for /f "tokens=3" %%A in (''sc query "%~1" 2^>nul ^| findstr /r /c:"STATE"'') do set "SVC_STATE=%%A"'))
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="2" if "%DETAIL%"=="4" set "RESULT=OK"'))
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="2" if "%DETAIL%"=="4" set "NOTE=(already running)"'))
        $script:Text | Should -Match ([regex]::Escape(':SumNETMissing'))
        $script:Text | Should -Match ([regex]::Escape('set "NOTE=(service missing)"'))
    }

    It 'passes the observed service state to the summary' {
        $script:Text | Should -Match ([regex]::Escape('set "S3_STATE=%SVC_STATE%"'))
        $script:Text | Should -Match ([regex]::Escape('set "S4_STATE=%SVC_STATE%"'))
        $script:Text | Should -Match ([regex]::Escape('call :SummaryLine 3 "net start wuauserv" "%S3_MS%" "%S3_RC%" NET "%S3_STATE%"'))
        $script:Text | Should -Match ([regex]::Escape('call :SummaryLine 4 "net start bits" "%S4_MS%" "%S4_RC%" NET "%S4_STATE%"'))
        $script:Text | Should -Match ([regex]::Escape('set "DETAIL=%~6"'))
    }

    It 'treats DISM code 3010 as success with restart required' {
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="3010" set "RESULT=REBOOT"'))
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="3010" set "NOTE=(restart required)"'))
    }

    It 'treats a DISM cleanup recommendation as review evidence' {
        $script:Text | Should -Match ([regex]::Escape('call :CheckCleanup'))
        $script:Text | Should -Match ([regex]::Escape('findstr /i /c:"Cleanup Recommended" "%OUT%" 2>nul | findstr /i /c:": Yes"'))
        $script:Text | Should -Match ([regex]::Escape('set "S6_CLEANUP=%CLEANUP_STATE%"'))
        $script:Text | Should -Match ([regex]::Escape('set "S9_CLEANUP=%CLEANUP_STATE%"'))
        $script:Text | Should -Match ([regex]::Escape('call :SummaryLine 6 "DISM /AnalyzeComponentStore" "%S6_MS%" "%S6_RC%" DISM "%S6_CLEANUP%"'))
        $script:Text | Should -Match ([regex]::Escape('call :SummaryLine 9 "DISM /AnalyzeComponentStore" "%S9_MS%" "%S9_RC%" DISM "%S9_CLEANUP%"'))
        $script:Text | Should -Match ([regex]::Escape('if /i "%DETAIL%"=="YES" if not "%RESULT%"=="FAIL" set "RESULT=REVIEW"'))
        $script:Text | Should -Match ([regex]::Escape('if /i "%DETAIL%"=="UNKNOWN" if not "%RESULT%"=="FAIL" set "RESULT=REVIEW"'))
    }

    It 'does not blindly turn an SFC nonzero code into success or failure' {
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="1" set "RESULT=REVIEW"'))
        $script:Text | Should -Match ([regex]::Escape('if not "%RC%"=="0" if not "%RC%"=="1" if not "%RC%"=="2" if not "%RC%"=="3" set "RESULT=REVIEW"'))
    }

    It 'uses a unique temporary file for stage output' {
        $script:Text | Should -Match ([regex]::Escape('set "OUT=%TEMP%\rw_sc_%RANDOM%_%RANDOM%.tmp"'))
    }

    It 'appends SFC output as UTF-8 instead of raw UTF-16 bytes' {
        $script:Text | Should -Match ([regex]::Escape('call :AppendOut'))
        $script:Text | Should -Match ([regex]::Escape('[IO.StreamReader]::new($env:OUT,$true)'))
        $script:Text | Should -Match ([regex]::Escape('[IO.File]::AppendAllText($env:LOG,$text'))
        $s8 = [Array]::IndexOf($script:Lines, 'set "S8_RC=%ERRORLEVEL%"')
        $script:Lines[$s8 + 4] | Should -Be 'call :AppendOut'
    }

    It 'never reports success when stage evidence is missing' {
        $script:Text | Should -Match ([regex]::Escape('if "%MS%"=="NA" set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if "%RC%"=="NA" set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if not defined MS set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if not defined RC set "RESULT=MISSING"'))
        $script:Text | Should -Match ([regex]::Escape('if %MISSINGCOUNT% GTR 0 set "OVERALL=INDETERMINATE"'))
    }

    It 'treats a missing total measurement as indeterminate evidence' {
        $script:Text | Should -Match ([regex]::Escape('if not defined TOTAL_MS set "TOTAL_MS=NA"'))
        $script:Text | Should -Match ([regex]::Escape('if "%TOTAL_MS%"=="NA" set /a MISSINGCOUNT+=1'))
    }

    It 'returns a failing exit code unless the overall status is successful' {
        $script:Text | Should -Match ([regex]::Escape('set "EXITCODE=0"'))
        $script:Text | Should -Match ([regex]::Escape('if not "%OVERALL%"=="SUCCESS" if not "%OVERALL%"=="SUCCESS (restart required)" set "EXITCODE=1"'))
        $script:Text | Should -Match ([regex]::Escape('exit /b %EXITCODE%'))
    }
}
