#Requires -Version 5.1
<#
    The one entry point behind Setup\Install.bat and Setup\Uninstall.bat.

    Install   - adds Kram to the right-click menu, then offers to switch
                Windows 11 to the full (classic) menu so Kram shows on the
                first right-click instead of under "Show more options".
    Uninstall - removes Kram from the right-click menu, then offers to put
                Windows 11's compact menu back if the full one is on.

    The classic-menu switch changes every app's menu, not just Kram's, and
    restarts Explorer - so it's always a question, never automatic.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$ContextMenu = Join-Path $PSScriptRoot 'Install-ContextMenu.ps1'
$ClassicMenu = Join-Path $PSScriptRoot 'Install-ClassicContextMenu.ps1'
$ClassicKey  = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'

function Test-ClassicMenuOn { Test-Path $ClassicKey }

function Ask-YesNo {
    param([string]$Question)
    $a = Read-Host "$Question [y/N]"
    return ($a -match '^(y|yes)$')
}

Write-Host ""
if ($Uninstall) {
    & $ContextMenu -Uninstall

    if (Test-ClassicMenuOn) {
        Write-Host ""
        Write-Host "Your PC is also using the full (classic) Windows right-click menu."
        if (Ask-YesNo "Put Windows 11's compact menu back?") {
            & $ClassicMenu -Uninstall
        }
    }
    return
}

& $ContextMenu

Write-Host ""
if (Test-ClassicMenuOn) {
    Write-Host "Kram shows on the first right-click (full Windows menu is on)." -ForegroundColor Green
    return
}

Write-Host "Windows 11 tucks Kram under 'Show more options' (or Shift+Right-click)."
Write-Host "You can switch to the full right-click menu so it shows on the first click."
Write-Host "That changes the menu for every app, and restarts Explorer once."
Write-Host ""
if (Ask-YesNo "Switch to the full right-click menu?") {
    & $ClassicMenu
} else {
    Write-Host ""
    Write-Host "Left as is. Shift+Right-click opens the full menu any time."
}
