@echo off
chcp 65001 >nul
cd /d "%~dp0"

rem  build_apks.bat              -> pick a game interactively (Enter = all)
rem  build_apks.bat RailOps2026  -> rebuild that game only
rem  build_apks.bat all          -> rebuild every game

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apks.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apks.ps1" -GameName "%~1"
)
echo.
pause
