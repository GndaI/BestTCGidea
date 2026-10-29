@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server\start-public.ps1"
echo.
echo Public game server stopped.
pause
