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
            'DISM /Online /Cleanup-Image /StartComponentCleanup%CLEANUP_SUFFIX% > "%OUT%" 2>&1',
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
            'DISM /Online /Cleanup-Image /StartComponentCleanup%CLEANUP_SUFFIX% > "%OUT%" 2>&1',
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

Describe 'Repair-Windows cleanup mode selection' {
    It 'offers exactly two options and reads a choice before the total timer starts' {
        $script:Text | Should -Match ([regex]::Escape('echo   [1] Standard - DISM /StartComponentCleanup - keeps update uninstall capability'))
        $script:Text | Should -Match ([regex]::Escape('echo   [2] ResetBase - adds /ResetBase - existing update packages can no longer be uninstalled'))
        $script:Text | Should -Match ([regex]::Escape('set /p "CLEANUP_CHOICE=Select 1 or 2 [1]: "'))
        $call = [Array]::IndexOf($script:Lines, 'call :AskCleanupMode')
        $label = [Array]::IndexOf($script:Lines, ':AskCleanupMode')
        $prompt = [Array]::IndexOf($script:Lines, 'set /p "CLEANUP_CHOICE=Select 1 or 2 [1]: "')
        $start = [Array]::IndexOf($script:Lines, 'call :StartTimer TOTAL_START')
        $call | Should -BeGreaterThan -1
        $label | Should -BeLessThan $prompt
        $start | Should -BeGreaterThan $call
    }

    It 'defaults to Standard on empty, invalid, or closed input' {
        foreach ($line in @(
            'if defined CLEANUP_CHOICE set "CLEANUP_CHOICE=%CLEANUP_CHOICE:"=%"',
            'if not defined CLEANUP_CHOICE goto :ModeStandard',
            'if "%CLEANUP_CHOICE%"=="1" goto :ModeStandard',
            'if "%CLEANUP_CHOICE%"=="2" goto :ModeResetBase',
            'echo Invalid selection; using Standard.',
            'set "CLEANUP_SUFFIX="'
        )) {
            $script:Lines | Should -Contain $line
        }
    }

    It 'keeps ResetBase opt-in only through the selected suffix' {
        $command = @($script:Lines | Where-Object { $_ -like 'DISM /Online /Cleanup-Image /StartComponentCleanup*' })
        $command.Count | Should -Be 1
        $command[0] | Should -Not -Match '/ResetBase'
        $script:Lines | Should -Contain 'set "CLEANUP_SUFFIX= /ResetBase"'
    }

    It 'logs the choice and warns only in ResetBase mode' {
        $script:Text | Should -Match ([regex]::Escape('echo Selected mode: %CLEANUP_DESC%'))
        $script:Text | Should -Match ([regex]::Escape('>>"%LOG%" echo Selected mode: %CLEANUP_DESC%'))
        $script:Text | Should -Match ([regex]::Escape('if "%CLEANUP_MODE%"=="resetbase" ('))
        $script:Text | Should -Match ([regex]::Escape('echo WARNING: existing update packages can no longer be uninstalled.'))
        $script:Text | Should -Match ([regex]::Escape('>>"%LOG%" echo WARNING: existing update packages can no longer be uninstalled.'))
    }

    It 'mirrors every startup menu line to the log' {
        foreach ($line in @('Component store cleanup mode:',
                            '  [1] Standard - DISM /StartComponentCleanup - keeps update uninstall capability',
                            '  [2] ResetBase - adds /ResetBase - existing update packages can no longer be uninstalled')) {
            $script:Lines | Should -Contain ('echo ' + $line)
            $script:Lines | Should -Contain ('>>"%LOG%" echo ' + $line)
        }
    }
}

Describe 'Repair-Windows cleanup mode runtime behavior' {
    # Executes the real selection subroutine with real cmd.exe, but never
    # reaches the maintenance stages: only :AskCleanupMode .. :End is copied.
    # The probe and its log live under the git-ignored Logs/ tree and are
    # removed in AfterAll even when an assertion fails.
    BeforeAll {
        $script:SourceText = [IO.File]::ReadAllLines((Join-Path $PSScriptRoot '..\Scripts\Repair-Windows.bat'))
        $begin = [Array]::IndexOf($script:SourceText, ':AskCleanupMode')
        $finish = [Array]::IndexOf($script:SourceText, ':End')
        $begin | Should -BeGreaterThan -1
        $finish | Should -BeGreaterThan $begin
        $subroutine = $script:SourceText[$begin..($finish - 1)]

        $logDir = Join-Path (Join-Path $PSScriptRoot '..\Logs') 'Repair-Windows'
        if (-not (Test-Path -LiteralPath $logDir)) {
            $null = New-Item -ItemType Directory -Path $logDir -Force
        }
        $script:Probe = Join-Path $logDir ("menu-probe-$PID.bat")
        $script:ProbeLog = Join-Path $logDir ("menu-probe-$PID.log")
        $header = @(
            '@echo off',
            'setlocal EnableExtensions',
            ('set "LOG=' + $script:ProbeLog + '"'),
            'call :AskCleanupMode',
            'echo RESULT_MODE=%CLEANUP_MODE%',
            'echo RESULT_SUFFIX=[%CLEANUP_SUFFIX%]',
            'exit /b 0',
            ''
        )
        [IO.File]::WriteAllText($script:Probe, (($header + $subroutine) -join "`r`n") + "`r`n")
    }

    AfterAll {
        Remove-Item -LiteralPath $script:Probe -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $script:ProbeLog -Force -ErrorAction SilentlyContinue
    }

    It 'selects Standard silently on empty or closed input' {
        $out = (('' | cmd /c $script:Probe 2>&1) -join "`n")
        $out | Should -Match 'RESULT_MODE=standard'
        $out | Should -Match 'RESULT_SUFFIX=\[\]'
        $out | Should -Not -Match 'Invalid selection'
        $out | Should -Not -Match 'unexpected at this time'
    }

    It 'selects Standard on an explicit 1' {
        $out = (('1' | cmd /c $script:Probe 2>&1) -join "`n")
        $out | Should -Match 'RESULT_MODE=standard'
        $out | Should -Match 'RESULT_SUFFIX=\[\]'
    }

    It 'selects ResetBase with its suffix on an explicit 2' {
        $out = (('2' | cmd /c $script:Probe 2>&1) -join "`n")
        $out | Should -Match 'RESULT_MODE=resetbase'
        $out | Should -Match 'RESULT_SUFFIX=\[ /ResetBase\]'
        $out | Should -Not -Match 'unexpected at this time'
    }

    It 'falls back to Standard and logs the reason on invalid input' {
        $out = (('garbage' | cmd /c $script:Probe 2>&1) -join "`n")
        $out | Should -Match 'Invalid selection; using Standard.'
        $out | Should -Match 'RESULT_MODE=standard'
        (Get-Content -LiteralPath $script:ProbeLog -Raw) | Should -Match 'Invalid selection'
    }

    It 'strips a stray quote before matching the choice' {
        $out = (('2"' | cmd /c $script:Probe 2>&1) -join "`n")
        $out | Should -Match 'RESULT_MODE=resetbase'
        $out | Should -Match 'RESULT_SUFFIX=\[ /ResetBase\]'
    }
}
