#Requires -Version 5.1
<#
    Restores the classic (pre-Windows 11) right-click menu, so everything
    shows on the first click instead of being tucked under "Show more
    options". Kram's own entries don't need this to work - they've always
    been reachable via "Show more options" - but this is what makes them
    (and everything else) visible without the extra click.

    This is Microsoft's own documented escape hatch for the Windows 11
    context menu redesign: an empty CLSID key that tells Explorer to skip
    straight to the full menu. HKCU only, no admin rights needed.

    Run with -Uninstall to put Windows 11's compact menu back.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$ClsidKey  = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$InprocKey = Join-Path $ClsidKey 'InprocServer32'

if ($Uninstall) {
    if (Test-Path $ClsidKey) {
        Remove-Item $ClsidKey -Recurse -Force
        Write-Host "Removed $ClsidKey"
    }
    Write-Host ""
    Write-Host "Windows 11's compact right-click menu is back." -ForegroundColor Green
} else {
    New-Item -Path $InprocKey -Force | Out-Null
    New-ItemProperty -Path $InprocKey -Name '(Default)' -Value '' -PropertyType String -Force | Out-Null
    Write-Host ""
    Write-Host "Classic right-click menu restored." -ForegroundColor Green
    Write-Host "Everything - including Kram - now shows on the first right-click."
}

Write-Host ""
Write-Host "Restarting Explorer for it to take effect (this briefly closes open" -ForegroundColor Yellow
Write-Host "Explorer windows and redraws the taskbar/desktop)..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Sleep -Milliseconds 500
Start-Process explorer.exe
Write-Host "Done."
