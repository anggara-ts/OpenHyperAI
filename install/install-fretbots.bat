@echo off
setlocal EnableExtensions
chcp 65001 >nul
:: Installs the Fretbots / Buff plugin into the Open Hyper AI bots folder.
:: Usage:
::   install-fretbots.bat                      (finds Dota 2 through Steam)
::   install-fretbots.bat "D:\SteamLibrary\steamapps\common\dota 2 beta"
::   install-fretbots.bat uninstall [dota path]
:: Needs the Open Hyper AI bot script already installed (vscripts\bots exists).

set "MODE=install"
if /i "%~1"=="uninstall" (
    set "MODE=uninstall"
    shift
)

set "PLUGIN=%~dp0.."
set "DOTA=%~1"
if not "%DOTA%"=="" goto :have_dota

for /f "tokens=2,*" %%a in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| find "SteamPath"') do set "STEAM=%%b"
if "%STEAM%"=="" set "STEAM=C:\Program Files (x86)\Steam"
set "STEAM=%STEAM:/=\%"
set "DOTA=%STEAM%\steamapps\common\dota 2 beta"

:have_dota
set "VS=%DOTA%\game\dota\scripts\vscripts"
set "BOTS=%VS%\bots"
if not exist "%BOTS%\" (
    echo Could not find the bots folder: "%BOTS%"
    echo Install Open Hyper AI first, or pass your "dota 2 beta" folder as the first argument.
    exit /b 1
)

if "%MODE%"=="uninstall" goto :uninstall

echo Installing Fretbots plugin into "%BOTS%"
xcopy "%PLUGIN%\FretBots" "%BOTS%\FretBots\" /E /I /Y /Q >nul || goto :fail
xcopy "%PLUGIN%\Buff" "%BOTS%\Buff\" /E /I /Y /Q >nul || goto :fail
copy /Y "%PLUGIN%\FretBots.lua" "%BOTS%\FretBots.lua" >nul || goto :fail
if not exist "%BOTS%\Customize\" mkdir "%BOTS%\Customize"
copy /Y "%PLUGIN%\Customize\fretbots.lua" "%BOTS%\Customize\fretbots.lua" >nul || goto :fail
if not exist "%VS%\game\Customize\" mkdir "%VS%\game\Customize"
if exist "%VS%\game\Customize\fretbots.lua" (
    echo Keeping your existing settings: "%VS%\game\Customize\fretbots.lua"
) else (
    copy /Y "%PLUGIN%\Customize\fretbots.lua" "%VS%\game\Customize\fretbots.lua" >nul
    echo Settings: "%VS%\game\Customize\fretbots.lua"
)
echo.
echo Done. In a Local Host lobby with cheats enabled, after hero selection starts, open the console and run:
echo   sv_cheats 1
echo   script_reload_code bots/FretBots
echo (or script_reload_code bots/Buff/buff for the lighter Buff script)
exit /b 0

:uninstall
echo Removing Fretbots plugin from "%BOTS%"
if exist "%BOTS%\FretBots\" rmdir /S /Q "%BOTS%\FretBots"
if exist "%BOTS%\Buff\" rmdir /S /Q "%BOTS%\Buff"
if exist "%BOTS%\FretBots.lua" del /Q "%BOTS%\FretBots.lua"
if exist "%BOTS%\Customize\fretbots.lua" del /Q "%BOTS%\Customize\fretbots.lua"
echo Done. Your settings in "%VS%\game\Customize\fretbots.lua" were kept.
exit /b 0

:fail
echo Copy failed. If Dota is under Program Files, run this script as Administrator.
exit /b 1
