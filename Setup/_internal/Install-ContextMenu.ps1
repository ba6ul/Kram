#Requires -Version 5.1
<#
    Adds Kram to the Windows Explorer right-click menu. Normally run via
    Setup\Install.bat (Kram-Setup.ps1), not directly.

      Right-click empty space in a folder  ->  Kram - New project  ->  Long / Shorts / ...
      Right-click a folder                 ->  Kram                ->  Organise / Preview / ...

    Everything is written under HKCU, so this needs no administrator rights and
    affects only the current user. Run with -Uninstall to remove it cleanly.

    Windows 11 note: registry verbs like these live under "Show more options"
    (or Shift+F10), not the first-level menu. Putting an entry in the top-level
    Windows 11 menu requires a signed MSIX shell extension, which Kram does not
    ship.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# This installer lives in Setup\_internal\; the toolkit is two levels up.
$ToolRoot   = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ScriptPath = Join-Path $ToolRoot 'Organise.ps1'
$PsExe      = Join-Path $PSHOME 'powershell.exe'

$BackgroundKey = 'HKCU:\Software\Classes\Directory\Background\shell\Kram'
$FolderKey     = 'HKCU:\Software\Classes\Directory\shell\Kram'

function Remove-KramKeys {
    foreach ($k in @($BackgroundKey, $FolderKey)) {
        if (Test-Path $k) {
            Remove-Item $k -Recurse -Force
            Write-Host "Removed $k"
        }
    }
}

if ($Uninstall) {
    Remove-KramKeys
    Write-Host ""
    Write-Host "Kram context menu removed." -ForegroundColor Green
    return
}

if (-not (Test-Path $ScriptPath)) {
    throw "Organise.ps1 not found in the Kram folder ($ScriptPath)."
}

# Reinstalling should not merge with a previous layout, e.g. if a project type
# was renamed or dropped from config.json.
Remove-KramKeys

$config = Get-Content (Join-Path $ToolRoot 'config.json') -Raw | ConvertFrom-Json
$types  = $config.types.PSObject.Properties

# --------------------------------------------------------------- helpers ---

function New-CascadeRoot {
    param([string]$Key, [string]$Label, [string]$Icon)

    New-Item -Path $Key -Force | Out-Null
    New-ItemProperty -Path $Key -Name 'MUIVerb' -Value $Label -PropertyType String -Force | Out-Null
    # An empty 'subcommands' value is what tells Explorer to enumerate the
    # child 'shell' key as a flyout menu.
    New-ItemProperty -Path $Key -Name 'subcommands' -Value '' -PropertyType String -Force | Out-Null
    if ($Icon) {
        New-ItemProperty -Path $Key -Name 'Icon' -Value $Icon -PropertyType String -Force | Out-Null
    }
    # Pin to the top of the menu and fence it off with separators, so it
    # doesn't get lost among every other app's entries.
    New-ItemProperty -Path $Key -Name 'Position' -Value 'Top' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $Key -Name 'SeparatorBefore' -Value '' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $Key -Name 'SeparatorAfter' -Value '' -PropertyType String -Force | Out-Null
    New-Item -Path (Join-Path $Key 'shell') -Force | Out-Null
}

function New-CascadeItem {
    param([string]$ParentKey, [string]$Order, [string]$Label, [string]$Arguments, [string]$Icon)

    # Submenu entries are listed in key-name order, hence the numeric prefixes.
    $key = Join-Path $ParentKey "shell\$Order"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name 'MUIVerb' -Value $Label -PropertyType String -Force | Out-Null
    if ($Icon) {
        New-ItemProperty -Path $key -Name 'Icon' -Value $Icon -PropertyType String -Force | Out-Null
    }

    $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" {2}' -f $PsExe, $ScriptPath, $Arguments
    $cmdKey = Join-Path $key 'command'
    New-Item -Path $cmdKey -Force | Out-Null
    Set-ItemProperty -Path $cmdKey -Name '(Default)' -Value $command
}

# Kram's own icons, drawn by Make-Icons.ps1 into this folder's icons\. System DLL
# icons were used before, but their indices aren't stable across Windows
# builds - the original picks drifted to a folder, magnifier, printer and
# warning sign. A type without its own icon (e.g. one you add to config.json)
# falls back to the Kram icon.
$IconDir  = Join-Path $PSScriptRoot 'icons'
function Get-KramIcon {
    param([string]$Name)
    $p = Join-Path $IconDir ("{0}.ico" -f $Name.ToLower())
    if (Test-Path $p) { return $p }
    return (Join-Path $IconDir 'kram.ico')
}
$KramIcon = Get-KramIcon 'kram'

# The K icon carries the branding; the label just says what it does. An em
# dash, built from its char code so the script stays plain ASCII - Windows
# PowerShell 5.1 misreads non-ASCII in a BOM-less script.
$Dash = [char]0x2014

# ------------------------------------------- empty space: new project ---

New-CascadeRoot -Key $BackgroundKey -Label "Kram $Dash New project" -Icon $KramIcon

$i = 1
foreach ($t in $types) {
    # One word per entry (Long, Shorts, ...) - config.json's longer 'label'
    # was too wordy to scan in a menu.
    $icon  = Get-KramIcon $t.Name
    New-CascadeItem -ParentKey $BackgroundKey `
                    -Order ('{0:d2}_{1}' -f $i, $t.Name) `
                    -Label $t.Name `
                    -Arguments ('-Verb new -Type {0} -Here -Path "%V" -Pause' -f $t.Name) `
                    -Icon $icon
    $i++
}

# ------------------------------------------------ folder: Kram commands ---

New-CascadeRoot -Key $FolderKey -Label 'Kram' -Icon $KramIcon

New-CascadeItem -ParentKey $FolderKey -Order '01_Organise' `
    -Label 'Organise' `
    -Arguments '-Verb sort -Path "%V" -Pause' `
    -Icon (Get-KramIcon 'organise')

New-CascadeItem -ParentKey $FolderKey -Order '02_Preview' `
    -Label 'Preview' `
    -Arguments '-Verb sort -Path "%V" -DryRun -Pause' `
    -Icon (Get-KramIcon 'preview')

New-CascadeItem -ParentKey $FolderKey -Order '03_Rename' `
    -Label 'Organise + rename' `
    -Arguments '-Verb sort -Path "%V" -Rename -Pause' `
    -Icon (Get-KramIcon 'rename')

New-CascadeItem -ParentKey $FolderKey -Order '04_Tidy' `
    -Label 'Tidy' `
    -Arguments '-Verb tidy -Path "%V" -Pause' `
    -Icon (Get-KramIcon 'tidy')

Write-Host ""
Write-Host "Kram added to the right-click menu." -ForegroundColor Green
Write-Host ""
Write-Host "  Right-click empty space in a folder -> Kram $Dash New project"
Write-Host "  Right-click a folder                -> Kram"
Write-Host ""
Write-Host "Run Install.bat again after adding a project type to config.json."
