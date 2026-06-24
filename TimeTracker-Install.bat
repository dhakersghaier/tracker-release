@echo off
REM TimeTracker Windows installer — double-click to run.
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/install-windows.ps1' | iex"
echo.
pause
