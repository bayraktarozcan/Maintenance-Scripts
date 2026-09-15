@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
if not defined TS set "TS=notime"
for %%I in ("%~dp0..\Logs\Repair-Windows") do set "LOGDIR=%%~fI"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%\Repair-Windows"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\Repair-Windows_%TS%.txt"
powershell -NoProfile -Command "[System.IO.File]::WriteAllBytes($env:LOG, @(0xEF,0xBB,0xBF))" >nul 2>&1
set "INDEX=%LOGDIR%\index.txt"
if not exist "%INDEX%" >>"%INDEX%" echo Script: Repair-Windows - Dir: %LOGDIR% - Created: %TS%
>>"%INDEX%" echo %TS% %LOG%
echo Index: %INDEX%
>>"%LOG%" echo Index: %INDEX%
set "OUT=%TEMP%\sc_out.tmp"

echo.
echo. >> "%LOG%"
echo ^> (1/9) DISM /Online /Cleanup-Image /CheckHealth
>>"%LOG%" echo ^> (1/9) DISM /Online /Cleanup-Image /CheckHealth
DISM /Online /Cleanup-Image /CheckHealth > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (2/9) DISM /Online /Cleanup-Image /ScanHealth
>>"%LOG%" echo ^> (2/9) DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /ScanHealth > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (3/9) net start wuauserv
>>"%LOG%" echo ^> (3/9) net start wuauserv
net start wuauserv > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (4/9) net start bits
>>"%LOG%" echo ^> (4/9) net start bits
net start bits > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (5/9) DISM /Online /Cleanup-Image /RestoreHealth
>>"%LOG%" echo ^> (5/9) DISM /Online /Cleanup-Image /RestoreHealth
DISM /Online /Cleanup-Image /RestoreHealth > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (6/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
>>"%LOG%" echo ^> (6/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (7/9) DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
>>"%LOG%" echo ^> (7/9) DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (8/9) sfc /scannow
>>"%LOG%" echo ^> (8/9) sfc /scannow
sfc /scannow > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (9/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
>>"%LOG%" echo ^> (9/9) DISM /Online /Cleanup-Image /AnalyzeComponentStore
DISM /Online /Cleanup-Image /AnalyzeComponentStore > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

del "%OUT%" >nul 2>&1
echo.
echo Log: %LOG%
>>"%LOG%" echo Log: %LOG%
powershell -NoProfile -Command "try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch { }" >nul 2>&1
echo.
pause
