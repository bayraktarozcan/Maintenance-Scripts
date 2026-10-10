@echo off
chcp 65001 >nul 2>&1
setlocal EnableExtensions
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
if not defined TS set "TS=notime"
for %%I in ("%~dp0..\Logs\WinGet-Upgrade") do set "LOGDIR=%%~fI"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
if not exist "%LOGDIR%" set "LOGDIR=%TEMP%\WinGet-Upgrade"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1
set "LOG=%LOGDIR%\WinGet-Upgrade_%TS%.txt"
powershell -NoProfile -Command "[System.IO.File]::WriteAllBytes($env:LOG, @(0xEF,0xBB,0xBF))" >nul 2>&1
set "INDEX=%LOGDIR%\index.txt"
if not exist "%INDEX%" >>"%INDEX%" echo Script: WinGet-Upgrade - Dir: %LOGDIR% - Created: %TS%
>>"%INDEX%" echo %TS% %LOG%
echo Index: %INDEX%
>>"%LOG%" echo Index: %INDEX%
set "OUT=%TEMP%\wug_out.tmp"
echo.
echo. >> "%LOG%"
echo ^> Oturum saptama: fltmc + whoami /groups S-1-16-12288
>>"%LOG%" echo ^> Oturum saptama: fltmc + whoami /groups S-1-16-12288
fltmc >nul 2>&1
set "FLT=%ERRORLEVEL%"
for /f "delims=" %%U in ('whoami') do set "WHOAMI_NAME=%%U"
if not defined WHOAMI_NAME set "WHOAMI_NAME=bilinmiyor"
whoami /groups > "%OUT%" 2>&1
find "S-1-16-12288" "%OUT%" >nul 2>&1
set "HIGH=%ERRORLEVEL%"
set "SESSION=Standart"
set "SCOPE=user"
set "WARN=0"
if %FLT%==0 if %HIGH%==0 set "SESSION=Yükseltilmiş"
if %FLT%==0 if %HIGH%==0 set "SCOPE=machine"
if %FLT%==0 if not %HIGH%==0 set "WARN=1"
if not %FLT%==0 if %HIGH%==0 set "WARN=1"
echo Oturum: %SESSION%
>>"%LOG%" echo Oturum: %SESSION%
echo Kullanıcı: %WHOAMI_NAME%
>>"%LOG%" echo Kullanıcı: %WHOAMI_NAME%
echo SCOPE: %SCOPE%
>>"%LOG%" echo SCOPE: %SCOPE%
if "%WARN%"=="1" echo UYARI: saptama sonuçları çelişiyor; oturum standart sayıldı.
if "%WARN%"=="1" >>"%LOG%" echo UYARI: saptama sonuçları çelişiyor; oturum standart sayıldı.
if defined WG_DRYRUN echo [DRYRUN] modu açık: 1. ve 2. adım çalıştırılmayacak.
if defined WG_DRYRUN >>"%LOG%" echo [DRYRUN] modu açık: 1. ve 2. adım çalıştırılmayacak.
set "FAIL=0"
echo.
echo. >> "%LOG%"
echo ^> (1/3) winget source update
>>"%LOG%" echo ^> (1/3) winget source update
set "EL1=0"
if defined WG_DRYRUN echo [DRYRUN] winget source update
if defined WG_DRYRUN >>"%LOG%" echo [DRYRUN] winget source update
if not defined WG_DRYRUN winget source update > "%OUT%" 2>&1
if not defined WG_DRYRUN set "EL1=%ERRORLEVEL%"
if not defined WG_DRYRUN type "%OUT%"
if not defined WG_DRYRUN type "%OUT%" >> "%LOG%" 2>&1
>>"%LOG%" echo errorlevel: %EL1%
if not "%EL1%"=="0" set "FAIL=1"
echo.
echo. >> "%LOG%"
echo.
echo. >> "%LOG%"
echo ^> (2/3) winget upgrade --all --scope %SCOPE% --include-unknown --accept-source-agreements --accept-package-agreements
>>"%LOG%" echo ^> (2/3) winget upgrade --all --scope %SCOPE% --include-unknown --accept-source-agreements --accept-package-agreements
set "EL2=0"
if defined WG_DRYRUN echo [DRYRUN] winget upgrade --all --scope %SCOPE% --include-unknown --accept-source-agreements --accept-package-agreements
if defined WG_DRYRUN >>"%LOG%" echo [DRYRUN] winget upgrade --all --scope %SCOPE% --include-unknown --accept-source-agreements --accept-package-agreements
if not defined WG_DRYRUN winget upgrade --all --scope %SCOPE% --include-unknown --accept-source-agreements --accept-package-agreements > "%OUT%" 2>&1
if not defined WG_DRYRUN set "EL2=%ERRORLEVEL%"
if not defined WG_DRYRUN type "%OUT%"
if not defined WG_DRYRUN type "%OUT%" >> "%LOG%" 2>&1
>>"%LOG%" echo errorlevel: %EL2%
if not "%EL2%"=="0" set "FAIL=1"
echo.
echo. >> "%LOG%"
echo.
echo. >> "%LOG%"
echo ^> (3/3) winget upgrade --scope %SCOPE% --include-unknown
>>"%LOG%" echo ^> (3/3) winget upgrade --scope %SCOPE% --include-unknown
winget upgrade --scope %SCOPE% --include-unknown > "%OUT%" 2>&1
set "EL3=%ERRORLEVEL%"
type "%OUT%"
type "%OUT%" >> "%LOG%" 2>&1
>>"%LOG%" echo errorlevel: %EL3%
if not "%EL3%"=="0" set "FAIL=1"
echo Not: Burada kalan paketler öteki oturum türüyle yükseltilmeyi bekleyebilir.
>>"%LOG%" echo Not: Burada kalan paketler öteki oturum türüyle yükseltilmeyi bekleyebilir.
echo.
echo. >> "%LOG%"
del "%OUT%" >nul 2>&1
echo.
echo Log: %LOG%
>>"%LOG%" echo Log: %LOG%
if "%FAIL%"=="0" echo Özet: tüm adımlar başarılı.
if "%FAIL%"=="0" >>"%LOG%" echo Özet: tüm adımlar başarılı.
if not "%FAIL%"=="0" echo Özet: bir ya da daha çok adım hata verdi; errorlevel satırlarına bakın.
if not "%FAIL%"=="0" >>"%LOG%" echo Özet: bir ya da daha çok adım hata verdi; errorlevel satırlarına bakın.
powershell -NoProfile -Command "try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } } catch { }" >nul 2>&1
echo.
pause
