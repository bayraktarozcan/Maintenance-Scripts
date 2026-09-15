@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
if not defined TS set "TS=notime"
for %%I in ("%~dp0..\Logs\IPConfig-FlushDNS") do set "LOGDIR=%%~fI"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%\IPConfig-FlushDNS"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\IPConfig-FlushDNS_%TS%.txt"
powershell -NoProfile -Command "[System.IO.File]::WriteAllBytes($env:LOG, @(0xEF,0xBB,0xBF))" >nul 2>&1
set "INDEX=%LOGDIR%\index.txt"
if not exist "%INDEX%" >>"%INDEX%" echo Script: IPConfig-FlushDNS - Dir: %LOGDIR% - Created: %TS%
>>"%INDEX%" echo %TS% %LOG%
echo Index: %INDEX%
>>"%LOG%" echo Index: %INDEX%
set "OUT=%TEMP%\dns_out.tmp"
echo.
echo. >> "%LOG%"
echo ^> ipconfig /flushdns
>>"%LOG%" echo ^> ipconfig /flushdns
ipconfig /flushdns > "%OUT%" 2>&1
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
