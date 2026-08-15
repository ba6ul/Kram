@echo off
setlocal enabledelayedexpansion

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set datestr=%datetime:~0,8%
set "psCommand=powershell -Command "Add-Type -AssemblyName Microsoft.VisualBasic; $name = [Microsoft.VisualBasic.Interaction]::InputBox('Enter project name', 'Project Name'); Write-Output $name""
for /f "delims=" %%a in ('%psCommand%') do set "name=%%a"
if "%name%"=="" (
    echo No name entered. Exiting...
    timeout /t 3 /nobreak >nul
    exit /b
)

set "root_folder=%datestr%_%name%"
mkdir "%root_folder%" 2>nul

mkdir "%root_folder%\01_After effects"
mkdir "%root_folder%\02_davici resolve"
mkdir "%root_folder%\03_Photoshop"
mkdir "%root_folder%\04_chitra"
mkdir "%root_folder%\05_chalchitra"
mkdir "%root_folder%\06_awaj"
mkdir "%root_folder%\07_export"

type nul > "%root_folder%\01_After effects\%name%.aep"
type nul > "%root_folder%\02_davici resolve\%name%.drp"
type nul > "%root_folder%\03_Photoshop\%name%.psd"
