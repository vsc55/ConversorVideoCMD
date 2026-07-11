@echo off
REM Lanzador de setup.ps1 apuntando a config.debug.json, para EDITAR/gestionar ese config de
REM depuracion (behavior.debug = true) con el editor de setup, sin tocar tu config.json normal.
REM Igual que setup.cmd pero fijando -Config al config de depuracion. Se le pueden pasar mas args.
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" -Config "%~dp0config.debug.json" %*
echo.
pause
