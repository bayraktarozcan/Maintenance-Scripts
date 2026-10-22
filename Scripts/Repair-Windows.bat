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
set "OUT=%TEMP%\rw_sc_%RANDOM%_%RANDOM%.tmp"
set /a FAILCOUNT=0
set /a REVIEWCOUNT=0
set /a MISSINGCOUNT=0
set /a REBOOTCOUNT=0
set "EXITCODE=0"
call :StartTimer TOTAL_START

echo.
echo. >> "%LOG%"
call :StartTimer S1_START
echo ^> [%START_HUMAN%] (1/9) DISM /Online /Cleanup-Image /CheckHealth
>>"%LOG%" echo ^> [%START_HUMAN%] (1/9) DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /CheckHealth > "%OUT%" 2>&1
set "S1_RC=%ERRORLEVEL%"
call :StopTimer "%S1_START%" S1_MS "%TIME%"
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
call :StopTimer "%S2_START%" S2_MS "%TIME%"
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
call :StopTimer "%S3_START%" S3_MS "%TIME%"
del "%S3_START%" >nul 2>&1
call :NetState wuauserv
set "S3_STATE=%SVC_STATE%"
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo   Service state: %SVC_STATE%
>>"%LOG%" echo   Service state: %SVC_STATE%
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
call :StopTimer "%S4_START%" S4_MS "%TIME%"
del "%S4_START%" >nul 2>&1
call :NetState bits
set "S4_STATE=%SVC_STATE%"
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo   Service state: %SVC_STATE%
>>"%LOG%" echo   Service state: %SVC_STATE%
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
call :StopTimer "%S5_START%" S5_MS "%TIME%"
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
call :StopTimer "%S6_START%" S6_MS "%TIME%"
del "%S6_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
call :CheckCleanup
set "S6_CLEANUP=%CLEANUP_STATE%"
echo   Cleanup recommended: %CLEANUP_STATE%
>>"%LOG%" echo   Cleanup recommended: %CLEANUP_STATE%
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
call :StopTimer "%S7_START%" S7_MS "%TIME%"
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
call :StopTimer "%S8_START%" S8_MS "%TIME%"
del "%S8_START%" >nul 2>&1
type "%OUT%"
call :AppendOut
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
call :StopTimer "%S9_START%" S9_MS "%TIME%"
del "%S9_START%" >nul 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
call :CheckCleanup
set "S9_CLEANUP=%CLEANUP_STATE%"
echo   Cleanup recommended: %CLEANUP_STATE%
>>"%LOG%" echo   Cleanup recommended: %CLEANUP_STATE%
echo ^< [%END_HUMAN%] (9/9) rc=%S9_RC% elapsed=%S9_MS% ms
>>"%LOG%" echo ^< [%END_HUMAN%] (9/9) rc=%S9_RC% elapsed=%S9_MS% ms
echo.
echo. >> "%LOG%"
call :StopTimer "%TOTAL_START%" TOTAL_MS "%TIME%"
del "%TOTAL_START%" >nul 2>&1

echo.
echo. >> "%LOG%"
echo ===== SUMMARY =====
>>"%LOG%" echo ===== SUMMARY =====
call :SummaryLine 1 "DISM /CheckHealth" "%S1_MS%" "%S1_RC%" DISM
call :SummaryLine 2 "DISM /ScanHealth" "%S2_MS%" "%S2_RC%" DISM
call :SummaryLine 3 "net start wuauserv" "%S3_MS%" "%S3_RC%" NET "%S3_STATE%"
call :SummaryLine 4 "net start bits" "%S4_MS%" "%S4_RC%" NET "%S4_STATE%"
call :SummaryLine 5 "DISM /RestoreHealth" "%S5_MS%" "%S5_RC%" DISM
call :SummaryLine 6 "DISM /AnalyzeComponentStore" "%S6_MS%" "%S6_RC%" DISM "%S6_CLEANUP%"
call :SummaryLine 7 "DISM /StartComponentCleanup /ResetBase" "%S7_MS%" "%S7_RC%" DISM
call :SummaryLine 8 "sfc /scannow" "%S8_MS%" "%S8_RC%" SFC
call :SummaryLine 9 "DISM /AnalyzeComponentStore" "%S9_MS%" "%S9_RC%" DISM "%S9_CLEANUP%"
if not defined TOTAL_MS set "TOTAL_MS=NA"
if "%TOTAL_MS%"=="NA" set /a MISSINGCOUNT+=1
set "OVERALL=SUCCESS"
if %MISSINGCOUNT% GTR 0 set "OVERALL=INDETERMINATE"
if %REVIEWCOUNT% GTR 0 set "OVERALL=REVIEW REQUIRED"
if %FAILCOUNT% GTR 0 set "OVERALL=FAILED"
if %REBOOTCOUNT% GTR 0 if %FAILCOUNT%==0 if %REVIEWCOUNT%==0 if %MISSINGCOUNT%==0 set "OVERALL=SUCCESS (restart required)"
call :FormatMs "%TOTAL_MS%"
echo TOTAL - %DUR% - %OVERALL%
>>"%LOG%" echo TOTAL - %DUR% - %OVERALL%
if not "%OVERALL%"=="SUCCESS" if not "%OVERALL%"=="SUCCESS (restart required)" set "EXITCODE=1"
echo Exit code: %EXITCODE%
>>"%LOG%" echo Exit code: %EXITCODE%
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
"%PSEXE%" -NoProfile -Command "$tz=[TimeZoneInfo]::CreateCustomTimeZone('Europe/Istanbul',[TimeSpan]::FromHours(3),'Europe/Istanbul','Europe/Istanbul'); $n=[DateTime]::UtcNow; $local=[TimeZoneInfo]::ConvertTimeFromUtc($n,$tz); [IO.File]::WriteAllText($env:RW_HUMAN,$local.ToString('yyyy-MM-dd HH:mm:ss.fff')); [IO.File]::WriteAllText($env:RW_START,[string]$n.Ticks)" >nul 2>&1
set "START_HUMAN="
set /p START_HUMAN=<"%HUMANFILE%" 2>nul
del "%HUMANFILE%" >nul 2>&1
if not defined START_HUMAN set "START_HUMAN=unknown"
set "%~1=%STARTFILE%"
exit /b 0

:StopTimer
set "RW_START=%~1"
set "RW_END_CLOCK=%~3"
set "HUMANFILE=%TEMP%\rw_human_%RANDOM%_%RANDOM%.tmp"
set "ELAPSEDFILE=%TEMP%\rw_elapsed_%RANDOM%_%RANDOM%.tmp"
set "RW_HUMAN=%HUMANFILE%"
set "RW_ELAPSED=%ELAPSEDFILE%"
del "%HUMANFILE%" >nul 2>&1
del "%ELAPSEDFILE%" >nul 2>&1
"%PSEXE%" -NoProfile -Command "try { $tz=[TimeZoneInfo]::CreateCustomTimeZone('Europe/Istanbul',[TimeSpan]::FromHours(3),'Europe/Istanbul','Europe/Istanbul'); $startTicks=[long]([IO.File]::ReadAllText($env:RW_START)); $startUtc=[DateTime]::new($startTicks,[DateTimeKind]::Utc); $startLocal=[TimeZoneInfo]::ConvertTimeFromUtc($startUtc,$tz); try { $endTime=[TimeSpan]::Parse($env:RW_END_CLOCK,[Globalization.CultureInfo]::CurrentCulture) } catch { $endTime=[DateTime]::Parse($env:RW_END_CLOCK,[Globalization.CultureInfo]::CurrentCulture).TimeOfDay }; $endLocal=$startLocal.Date.Add($endTime); if ($endLocal -lt $startLocal) { $endLocal=$endLocal.AddDays(1) }; $ms=[int64](($endLocal-$startLocal).TotalMilliseconds); [IO.File]::WriteAllText($env:RW_HUMAN,$endLocal.ToString('yyyy-MM-dd HH:mm:ss.fff')); [IO.File]::WriteAllText($env:RW_ELAPSED,[string]$ms) } catch { [IO.File]::WriteAllText($env:RW_HUMAN,'unknown'); [IO.File]::WriteAllText($env:RW_ELAPSED,'NA') }" >nul 2>&1
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

:AppendOut
if not exist "%OUT%" exit /b 0
"%PSEXE%" -NoProfile -Command "try { $reader=[IO.StreamReader]::new($env:OUT,$true); try { $text=$reader.ReadToEnd() } finally { $reader.Dispose() }; [IO.File]::AppendAllText($env:LOG,$text,(New-Object System.Text.UTF8Encoding($false))) } catch { exit 1 }" >nul 2>&1
if errorlevel 1 echo [WARN] Could not append stage output.
if errorlevel 1 >>"%LOG%" echo [WARN] Could not append stage output.
exit /b 0

:CheckCleanup
set "CLEANUP_STATE=UNKNOWN"
findstr /i /c:"Cleanup Recommended" "%OUT%" 2>nul | findstr /i /c:": Yes" >nul 2>&1
if not errorlevel 1 set "CLEANUP_STATE=YES"
if "%CLEANUP_STATE%"=="UNKNOWN" findstr /i /c:"Cleanup Recommended" "%OUT%" 2>nul | findstr /i /c:": No" >nul 2>&1
if "%CLEANUP_STATE%"=="UNKNOWN" if not errorlevel 1 set "CLEANUP_STATE=NO"
exit /b 0

:NetState
set "SVC_STATE=UNKNOWN"
sc query "%~1" >nul 2>&1
set "SVC_RC=%ERRORLEVEL%"
if "%SVC_RC%"=="1060" set "SVC_STATE=MISSING"
if not "%SVC_RC%"=="0" if not "%SVC_RC%"=="1060" set "SVC_STATE=UNKNOWN"
if not "%SVC_RC%"=="0" exit /b 0
for /f "tokens=3" %%A in ('sc query "%~1" 2^>nul ^| findstr /r /c:"STATE"') do set "SVC_STATE=%%A"
exit /b 0

:SummaryLine
set "N=%~1"
set "NAME=%~2"
set "MS=%~3"
set "RC=%~4"
set "KIND=%~5"
set "DETAIL=%~6"
set "RESULT=REVIEW"
set "NOTE="
if not defined MS set "RESULT=MISSING"
if not defined RC set "RESULT=MISSING"
if "%RESULT%"=="MISSING" goto :SumEmit
if "%MS%"=="NA" set "RESULT=MISSING"
if "%RC%"=="NA" set "RESULT=MISSING"
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
if /i "%DETAIL%"=="YES" if "%RESULT%"=="REBOOT" set "NOTE=(cleanup recommended; restart required)"
if /i "%DETAIL%"=="YES" if not "%RESULT%"=="FAIL" if not "%RESULT%"=="REBOOT" set "NOTE=(cleanup recommended)"
if /i "%DETAIL%"=="YES" if not "%RESULT%"=="FAIL" set "RESULT=REVIEW"
if /i "%DETAIL%"=="UNKNOWN" if "%RESULT%"=="REBOOT" set "NOTE=(verify cleanup recommendation; restart required)"
if /i "%DETAIL%"=="UNKNOWN" if not "%RESULT%"=="FAIL" if not "%RESULT%"=="REBOOT" set "NOTE=(verify cleanup recommendation)"
if /i "%DETAIL%"=="UNKNOWN" if not "%RESULT%"=="FAIL" set "RESULT=REVIEW"
goto :SumEmit

:SumNET
if "%DETAIL%"=="MISSING" goto :SumNETMissing
if "%RC%"=="0" if "%DETAIL%"=="4" set "RESULT=OK"
if "%RC%"=="2" if "%DETAIL%"=="4" set "RESULT=OK"
if "%RC%"=="2" if "%DETAIL%"=="4" set "NOTE=(already running)"
if "%RC%"=="0" if not "%DETAIL%"=="4" set "RESULT=REVIEW"
if "%RC%"=="0" if not "%DETAIL%"=="4" set "NOTE=(verify service state)"
if "%RC%"=="2" if not "%DETAIL%"=="4" set "RESULT=REVIEW"
if "%RC%"=="2" if not "%DETAIL%"=="4" set "NOTE=(verify service state)"
if not "%RC%"=="0" if not "%RC%"=="2" set "RESULT=FAIL"
goto :SumEmit

:SumNETMissing
set "RESULT=FAIL"
set "NOTE=(service missing)"
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
exit /b %EXITCODE%
