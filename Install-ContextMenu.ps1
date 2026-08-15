#Requires -Version 5.1
<#
    Adds Kram to the Windows Explorer right-click menu.

      Right-click empty space in a folder  ->  New with Kram  ->  Long / Shorts / ...
      Right-click a folder                 ->  Kram           ->  Organise / Preview / ...

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

$ToolRoot   = $PSScriptRoot
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
    throw "Organise.ps1 not found next to this installer ($ScriptPath)."
}

# Reinstalling should not merge with a previous layout, e.g. if a project type
# was renamed or dropped from config.json.
Remove-KramKeys

$config = Get-Content (Join-Path $ToolRoot 'config.json') -Raw | ConvertFrom-Json
$types  = $config.types.PSObject.Properties

# --------------------------------------------------------------- helpers ---

function New-CascadeRoot {
    param([string]$Key, [string]$Label)

    New-Item -Path $Key -Force | Out-Null
    New-ItemProperty -Path $Key -Name 'MUIVerb' -Value $Label -PropertyType String -Force | Out-Null
    # An empty 'subcommands' value is what tells Explorer to enumerate the
    # child 'shell' key as a flyout menu.
    New-ItemProperty -Path $Key -Name 'subcommands' -Value '' -PropertyType String -Force | Out-Null
    New-Item -Path (Join-Path $Key 'shell') -Force | Out-Null
}

function New-CascadeItem {
    param([string]$ParentKey, [string]$Order, [string]$Label, [string]$Arguments)

    # Submenu entries are listed in key-name order, hence the numeric prefixes.
    $key = Join-Path $ParentKey "shell\$Order"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name 'MUIVerb' -Value $Label -PropertyType String -Force | Out-Null

    $command = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" {2}' -f $PsExe, $ScriptPath, $Arguments
    $cmdKey = Join-Path $key 'command'
    New-Item -Path $cmdKey -Force | Out-Null
    Set-ItemProperty -Path $cmdKey -Name '(Default)' -Value $command
}

# ------------------------------------------- empty space: New with Kram ---

New-CascadeRoot -Key $BackgroundKey -Label 'New with Kram'

$i = 1
foreach ($t in $types) {
    $label = if ($t.Value.label) { $t.Value.label } else { $t.Name }
    New-CascadeItem -ParentKey $BackgroundKey `
                    -Order ('{0:d2}_{1}' -f $i, $t.Name) `
                    -Label $label `
                    -Arguments ('-Verb new -Type {0} -Here -Path "%V" -Pause' -f $t.Name)
    $i++
}

# ------------------------------------------------ folder: Kram commands ---

New-CascadeRoot -Key $FolderKey -Label 'Kram'

New-CascadeItem -ParentKey $FolderKey -Order '01_Organise' `
    -Label 'Organise' `
    -Arguments '-Verb sort -Path "%V" -Pause'

New-CascadeItem -ParentKey $FolderKey -Order '02_Preview' `
    -Label 'Preview (show what would move)' `
    -Arguments '-Verb sort -Path "%V" -DryRun -Pause'

New-CascadeItem -ParentKey $FolderKey -Order '03_Rename' `
    -Label 'Organise + clean up filenames' `
    -Arguments '-Verb sort -Path "%V" -Rename -Pause'

New-CascadeItem -ParentKey $FolderKey -Order '04_Tidy' `
    -Label 'Tidy (final cleanup check)' `
    -Arguments '-Verb tidy -Path "%V" -Pause'

Write-Host ""
Write-Host "Kram context menu installed for $env:USERNAME." -ForegroundColor Green
Write-Host ""
Write-Host "  Right-click empty space in a folder -> New with Kram"
Write-Host "  Right-click a folder                -> Kram"
Write-Host ""
Write-Host "On Windows 11 both live under 'Show more options' (Shift+F10)." -ForegroundColor Yellow
Write-Host "No restart needed. Re-run this after editing project types in config.json."
Write-Host "Remove it any time with:  Install-ContextMenu.ps1 -Uninstall"
