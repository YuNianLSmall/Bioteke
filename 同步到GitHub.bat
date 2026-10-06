@echo off
chcp 65001 >nul
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync.ps1" %~1
echo.
pause
