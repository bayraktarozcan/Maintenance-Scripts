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
for %%I in ("%~dp0..\Logs\Update-Components") do set "LOGDIR=%%~fI"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%\Update-Components"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\Update-Components_%TS%.txt"
"%PSEXE%" -NoProfile -Command "[System.IO.File]::WriteAllBytes($env:LOG, @(0xEF,0xBB,0xBF))" >nul 2>&1
set "INDEX=%LOGDIR%\index.txt"
if not exist "%INDEX%" >>"%INDEX%" echo Script: Update-Components - Dir: %LOGDIR% - Created: %TS%
>>"%INDEX%" echo %TS% %LOG%
echo Index: %INDEX%
>>"%LOG%" echo Index: %INDEX%
set "SCRIPT=%~dp0..\Tools\Update-Components.ps1"
echo.
echo. >> "%LOG%"
echo ^> Update-Components.ps1 %*
>>"%LOG%" echo ^> Update-Components.ps1 %*
"%PSEXE%" -NoProfile -File "%SCRIPT%" %* 2>&1 | "%PSEXE%" -NoProfile -Command "$input | ForEach-Object { $_; [IO.File]::AppendAllText($env:LOG, $_ + [Environment]::NewLine, [Text.UTF8Encoding]::new($false)) }"
echo.
echo. >> "%LOG%"
echo.
echo Log: %LOG%
>>"%LOG%" echo Log: %LOG%
"%PSEXE%" -NoProfile -Command "try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch { }" >nul 2>&1
echo.
pause