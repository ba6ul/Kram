@echo off
chcp 65001 >nul
:: End-of-project deep check. Reports only - nothing moves.
:: Run this before you archive the project.
powershell -NoProfile -ExecutionPolicy Bypass -File "__TOOLROOT__\Organise.ps1" -Verb tidy -Path "%~dp0."
echo.
pause
