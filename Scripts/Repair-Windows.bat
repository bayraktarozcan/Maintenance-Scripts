@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
set "PSEXE=powershell"
set "PW7=%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
if not exist "%PW7%" set "PW7="
if defined PW7 "%PW7%" -NoProfile -Command "exit 0" >nul 2>&1
if defined PW7 if not errorlevel 1 set "PSEXE=%PW7%"
if "%PSEXE%"=="powershell" where pwsh.exe >nul 2>&1
if "%PSEXE%"=="powershell" if not errorlevel 1 pwsh -NoProfile -Command "exit 0" >nul 2>&1
if "%PSEXE%"=="powershell" if not errorlevel 1 set "PSEXE=pwsh"
set "TSFILE=%TEMP%\ts_%RANDOM%.txt"
"%PSEXE%" -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss" > "%TSFILE%"
set /p TS=<"%TSFILE%"
del "%TSFILE%" >nul 2>&1
if not defined TS set "TS=notime"
for %%I in ("%~dp0..\Logs\Repair-Windows") do set "LOGDIR=%%~fI"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%\Repair-Windows"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\Repair-Windows_%TS%.txt"
"%PSEXE%" -NoProfile -Command "[System.IO.File]::WriteAllBytes($env:LOG, @(0xEF,0xBB,0xBF))" >nul 2>&1
set "INDEX=%LOGDIR%\index.txt"
if not exist "%INDEX%" >>"%INDEX%" echo Script: Repair-Windows - Dir: %LOGDIR% - Created: %TS%
>>"%INDEX%" echo %TS% %LOG%
echo Index: %INDEX%
>>"%LOG%" echo Index: %INDEX%
set "OUT=%TEMP%\sc_out.tmp"
set /a FAILCOUNT=0
set /a REVIEWCOUNT=0
set /a MISSINGCOUNT=0
set /a REBOOTCOUNT=0
call :StartTimer TOTAL_START

echo.
echo. >> "%LOG%"
call :StartTimer S1_START
echo ^> [%START_HUMAN%] (1/9) DISM /Online /Cleanup-Image /CheckHealth
>>"%LOG%" echo ^> [%START_HUMAN%] (1/9) DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /CheckHealth > "%OUT%" 2>&1
set "S1_RC=%ERRORLEVEL%"
call :StopTimer "%S1_START%" S1_MS
del "%S1_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (1/9) rc=%S1_RC% elapsed=%S1_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (1/9) rc=%S1_RC% elapsed=%S1_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S2_START
echo ^> [%START_HUMAN%] (2/9) DISM /Online /Cleanup-Image /ScanHealth
>>"%LOG%" echo ^> [%START_HUMAN%] (2/9) DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /ScanHealth > "%OUT%" 2>&1
set "S2_RC=%ERRORLEVEL%"
call :StopTimer "%S2_START%" S2_MS
del "%S2_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (2/9) rc=%S2_RC% elapsed=%S2_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (2/9) rc=%S2_RC% elapsed=%S2_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S3_START
echo ^> [%START_HUMAN%] (3/9) net start wuauserv
>>"%LOG%" echo ^> [%START_HUMAN%] (3/9) net start wuauserv
net start wuauserv > "%OUT%" 2>&1
set "S3_RC=%ERRORLEVEL%"
call :StopTimer "%S3_START%" S3_MS
del "%S3_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (3/9) rc=%S3_RC% elapsed=%S3_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (3/9) rc=%S3_RC% elapsed=%S3_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S4_START
echo ^> [%START_HUMAN%] (4/9) net start bits
>>"%LOG%" echo ^> [%START_HUMAN%] (4/9) net start bits
net start bits > "%OUT%" 2>&1
set "S4_RC=%ERRORLEVEL%"
call :StopTimer "%S4_START%" S4_MS
del "%S4_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (4/9) rc=%S4_RC% elapsed=%S4_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (4/9) rc=%S4_RC% elapsed=%S4_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S5_START
echo ^> [%START_HUMAN%] (5/9) DISM /Online /Cleanup-Image /RestoreHealth
>>"%LOG%" echo ^> [%START_HUMAN%] (5/9) DISM /Online /Cleanup-Image /RestoreHealth
DISM /Online /Cleanup-Image /RestoreHealth > "%OUT%" 2>&1
set "S5_RC=%ERRORLEVEL%"
call :StopTimer "%S5_START%" S5_MS
del "%S5_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (5/9) rc=%S5_RC% elapsed=%S5_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (5/9) rc=%S5_RC% elapsed=%S5_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S6_START
echo ^> [%START_HUMAN%] (6/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
>>"%LOG%" echo ^> [%START_HUMAN%] (6/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1
set "S6_RC=%ERRORLEVEL%"
call :StopTimer "%S6_START%" S6_MS
del "%S6_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (6/9) rc=%S6_RC% elapsed=%S6_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (6/9) rc=%S6_RC% elapsed=%S6_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S7_START
echo ^> [%START_HUMAN%] (7/9) DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
>>"%LOG%" echo ^> [%START_HUMAN%] (7/9) DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase > "%OUT%" 2>&1
set "S7_RC=%ERRORLEVEL%"
call :StopTimer "%S7_START%" S7_MS
del "%S7_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (7/9) rc=%S7_RC% elapsed=%S7_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (7/9) rc=%S7_RC% elapsed=%S7_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S8_START
echo ^> [%START_HUMAN%] (8/9) sfc /scannow
>>"%LOG%" echo ^> [%START_HUMAN%] (8/9) sfc /scannow
sfc /scannow > "%OUT%" 2>&1
set "S8_RC=%ERRORLEVEL%"
call :StopTimer "%S8_START%" S8_MS
del "%S8_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (8/9) rc=%S8_RC% elapsed=%S8_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (8/9) rc=%S8_RC% elapsed=%S8_MS% ms
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
call :StartTimer S9_START
echo ^> [%START_HUMAN%] (9/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
>>"%LOG%" echo ^> [%START_HUMAN%] (9/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1
set "S9_RC=%ERRORLEVEL%"
call :StopTimer "%S9_START%" S9_MS
del "%S9_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo ^< [%END_HUMAN%] (9/9) rc=%S9_RC% elapsed=%S9_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (9/9) rc=%S9_RC% elapsed=%S9_MS% ms
echo.
echo. >> "%LOG%"
call :StopTimer "%TOTAL_START%" TOTAL_MS
del "%TOTAL_START%" >nul 2>&1

echo.
echo. >> "%LOG%"
echo ===== SUMMARY =====
>>"%LOG%" echo ===== SUMMARY =====
call :SummaryLine 1 "DISM /CheckHealth" "%S1_MS%" "%S1_RC%" DISM
call :SummaryLine 2 "DISM /ScanHealth" "%S2_MS%" "%S2_RC%" DISM
call :SummaryLine 3 "net start wuauserv" "%S3_MS%" "%S3_RC%" NET
call :SummaryLine 4 "net start bits" "%S4_MS%" "%S4_RC%" NET
call :SummaryLine 5 "DISM /RestoreHealth" "%S5_MS%" "%S5_RC%" DISM
call :SummaryLine 6 "DISM /AnalyzeComponentStore" "%S6_MS%" "%S6_RC%" DISM
call :SummaryLine 7 "DISM /StartComponentCleanup /ResetBase" "%S7_MS%" "%S7_RC%" DISM
call :SummaryLine 8 "sfc /scannow" "%S8_MS%" "%S8_RC%" SFC
call :SummaryLine 9 "DISM /AnalyzeComponentStore" "%S9_MS%" "%S9_RC%" DISM
set "OVERALL=SUCCESS"
if %MISSINGCOUNT% GTR 0 set "OVERALL=INDETERMINATE"
if %REVIEWCOUNT% GTR 0 set "OVERALL=REVIEW REQUIRED"
if %FAILCOUNT% GTR 0 set "OVERALL=FAILED"
if %REBOOTCOUNT% GTR 0 if %FAILCOUNT%==0 if %REVIEWCOUNT%==0 if %MISSINGCOUNT%==0 set "OVERALL=SUCCESS (restart required)"
call :FormatMs "%TOTAL_MS%"
echo TOTAL - %DUR% - %OVERALL%
>>"%LOG%" echo TOTAL - %DUR% - %OVERALL%
echo.
echo. >> "%LOG%"

del "%OUT%" >nul 2>&1
echo.
echo Log: %LOG%
>>"%LOG%" echo Log: %LOG%
"%PSEXE%" -NoProfile -Command "try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch { }" >nul 2>&1
echo.
goto :End

:StartTimer
set "STARTFILE=%TEMP%\rw_start_%RANDOM%_%RANDOM%.tmp"
set "HUMANFILE=%TEMP%\rw_human_%RANDOM%_%RANDOM%.tmp"
set "RW_START=%STARTFILE%"
set "RW_HUMAN=%HUMANFILE%"
del "%STARTFILE%" >nul 2>&1
del "%HUMANFILE%" >nul 2>&1
"%PSEXE%" -NoProfile -Command "$n=[DateTime]::UtcNow; [IO.File]::WriteAllText($env:RW_HUMAN,$n.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss.fff')); [IO.File]::WriteAllText($env:RW_START,[string]$n.Ticks)" >nul 2>&1
set "START_HUMAN="
set /p START_HUMAN=<"%HUMANFILE%" 2>nul
del "%HUMANFILE%" >nul 2>&1
if not defined START_HUMAN set "START_HUMAN=unknown"
set "%~1=%STARTFILE%"
exit /b 0

:StopTimer
set "RW_START=%~1"
set "HUMANFILE=%TEMP%\rw_human_%RANDOM%_%RANDOM%.tmp"
set "ELAPSEDFILE=%TEMP%\rw_elapsed_%RANDOM%_%RANDOM%.tmp"
set "RW_HUMAN=%HUMANFILE%"
set "RW_ELAPSED=%ELAPSEDFILE%"
del "%HUMANFILE%" >nul 2>&1
del "%ELAPSEDFILE%" >nul 2>&1
"%PSEXE%" -NoProfile -Command "$start=[long]([IO.File]::ReadAllText($env:RW_START)); $n=[DateTime]::UtcNow; $ms=[int64](($n.Ticks-$start)/10000); [IO.File]::WriteAllText($env:RW_HUMAN,$n.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss.fff')); [IO.File]::WriteAllText($env:RW_ELAPSED,[string]$ms)" >nul 2>&1
set "END_HUMAN="
set /p END_HUMAN=<"%HUMANFILE%" 2>nul
set "MS="
set /p MS=<"%ELAPSEDFILE%" 2>nul
del "%HUMANFILE%" >nul 2>&1
del "%ELAPSEDFILE%" >nul 2>&1
if not defined END_HUMAN set "END_HUMAN=unknown"
if not defined MS set "MS=NA"
set "%~2=%MS%"
exit /b 0

:FormatMs
set "DUR=NA ms"
if "%~1"=="" exit /b 0
if "%~1"=="NA" exit /b 0
set "DUR=%~1 ms"
set /a DUR_SEC=%~1/1000
set /a DUR_REM=%~1-DUR_SEC*1000
set /a DUR_REM=1000+DUR_REM
set "DUR_REM=%DUR_REM:~1%"
set "DUR=%DUR_SEC%.%DUR_REM% s"
exit /b 0

:SummaryLine
set "N=%~1"
set "NAME=%~2"
set "MS=%~3"
set "RC=%~4"
set "KIND=%~5"
set "RESULT=REVIEW"
set "NOTE="
if not defined MS set "RESULT=MISSING"
if not defined RC set "RESULT=MISSING"
if "%RESULT%"=="MISSING" goto :SumEmit
if "%MS%"=="NA" set "RESULT=MISSING"
if "%RESULT%"=="MISSING" goto :SumEmit
goto :SumClassify

:SumClassify
if /i "%KIND%"=="DISM" goto :SumDISM
if /i "%KIND%"=="NET" goto :SumNET
if /i "%KIND%"=="SFC" goto :SumSFC
goto :SumEmit

:SumDISM
if "%RC%"=="0" set "RESULT=OK"
if "%RC%"=="3010" set "RESULT=REBOOT"
if "%RC%"=="3010" set "NOTE=(restart required)"
if not "%RC%"=="0" if not "%RC%"=="3010" set "RESULT=FAIL"
goto :SumEmit

:SumNET
if "%RC%"=="0" set "RESULT=OK"
if "%RC%"=="2" set "RESULT=OK"
if "%RC%"=="2" set "NOTE=(already running)"
if not "%RC%"=="0" if not "%RC%"=="2" set "RESULT=FAIL"
goto :SumEmit

:SumSFC
if "%RC%"=="0" set "RESULT=OK"
if "%RC%"=="1" set "RESULT=REVIEW"
if "%RC%"=="1" set "NOTE=(SFC reported a condition; check CBS.log)"
if "%RC%"=="2" set "RESULT=FAIL"
if "%RC%"=="3" set "RESULT=FAIL"
if not "%RC%"=="0" if not "%RC%"=="1" if not "%RC%"=="2" if not "%RC%"=="3" set "RESULT=REVIEW"
goto :SumEmit

:SumEmit
if "%RESULT%"=="REBOOT" set /a REBOOTCOUNT+=1
if "%RESULT%"=="FAIL" set /a FAILCOUNT+=1
if "%RESULT%"=="REVIEW" set /a REVIEWCOUNT+=1
if "%RESULT%"=="MISSING" set /a MISSINGCOUNT+=1
call :FormatMs "%MS%"
echo %N%^) %NAME% - %DUR% - rc=%RC% - %RESULT% %NOTE%
>>"%LOG%" echo %N%^) %NAME% - %DUR% - rc=%RC% - %RESULT% %NOTE%
exit /b 0

:End
pause
