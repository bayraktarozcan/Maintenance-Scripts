@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
if not defined TS set "TS=notime"
for %%I in ("%~dp0..\Logs\Reset-Windows-Update") do set "LOGDIR=%%~fI"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%\Reset-Windows-Update"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\Reset-Windows-Update_%TS%.txt"
powershell -NoProfile -Command "[System.IO.File]::WriteAllBytes($env:LOG, @(0xEF,0xBB,0xBF))" >nul 2>&1
set "INDEX=%LOGDIR%\index.txt"
if not exist "%INDEX%" >>"%INDEX%" echo Script: Reset-Windows-Update - Dir: %LOGDIR% - Created: %TS%
>>"%INDEX%" echo %TS% %LOG%
echo Index: %INDEX%
>>"%LOG%" echo Index: %INDEX%
set "OUT=%TEMP%\rwu_out.tmp"

echo.
echo. >> "%LOG%"
echo ^> (1/13) net stop wuauserv
>>"%LOG%" echo ^> (1/13) net stop wuauserv
net stop wuauserv > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (2/13) net stop bits
>>"%LOG%" echo ^> (2/13) net stop bits
net stop bits > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (3/13) net stop msiserver
>>"%LOG%" echo ^> (3/13) net stop msiserver
net stop msiserver > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (4/13) net stop cryptSvc
>>"%LOG%" echo ^> (4/13) net stop cryptSvc
net stop cryptSvc > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (5/13) del /f /s /q "C:\Windows\SoftwareDistribution\*.*"
>>"%LOG%" echo ^> (5/13) del /f /s /q "C:\Windows\SoftwareDistribution\*.*"
del /f /s /q "C:\Windows\SoftwareDistribution\*.*" > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (6/13) for /d %%I in ("C:\Windows\SoftwareDistribution\*") do rd /s /q "%%I"
>>"%LOG%" echo ^> (6/13) for /d %%I in ("C:\Windows\SoftwareDistribution\*") do rd /s /q "%%I"
for /d %%I in ("C:\Windows\SoftwareDistribution\*") do rd /s /q "%%I" > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (7/13) del /f /s /q "C:\Windows\System32\catroot2\*.*"
>>"%LOG%" echo ^> (7/13) del /f /s /q "C:\Windows\System32\catroot2\*.*"
del /f /s /q "C:\Windows\System32\catroot2\*.*" > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (8/13) for /d %%I in ("C:\Windows\System32\catroot2\*") do rd /s /q "%%I"
>>"%LOG%" echo ^> (8/13) for /d %%I in ("C:\Windows\System32\catroot2\*") do rd /s /q "%%I"
for /d %%I in ("C:\Windows\System32\catroot2\*") do rd /s /q "%%I" > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (9/13) net start wuauserv
>>"%LOG%" echo ^> (9/13) net start wuauserv
net start wuauserv > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (10/13) net start bits
>>"%LOG%" echo ^> (10/13) net start bits
net start bits > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (11/13) net start cryptSvc
>>"%LOG%" echo ^> (11/13) net start cryptSvc
net start cryptSvc > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (12/13) net start msiserver
>>"%LOG%" echo ^> (12/13) net start msiserver
net start msiserver > "%OUT%" 2>&1
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
echo.
echo. >> "%LOG%"

echo.
echo. >> "%LOG%"
echo ^> (13/13) UsoClient StartScan
>>"%LOG%" echo ^> (13/13) UsoClient StartScan
UsoClient StartScan > "%OUT%" 2>&1
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
