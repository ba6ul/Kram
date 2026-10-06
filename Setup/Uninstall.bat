@echo off
chcp 65001 >nul
title Kram uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_internal\Kram-Setup.ps1" -Uninstall
echo.
pause
