@echo off
chcp 65001 >nul
:: Sorts loose files sitting in this project's root into the right folders.
:: Safe to run as many times as you like - already-organised folders are ignored.
powershell -NoProfile -ExecutionPolicy Bypass -File "__TOOLROOT__\Organise.ps1" -Verb sort -Path "%~dp0."
echo.
pause
