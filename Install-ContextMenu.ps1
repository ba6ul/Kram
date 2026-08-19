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
    param([string]$Key, [string]$Label, [string]$Icon)

    New-Item -Path $Key -Force | Out-Null
    New-ItemProperty -Path $Key -Name 'MUIVerb' -Value $Label -PropertyType String -Force | Out-Null
    # An empty 'subcommands' value is what tells Explorer to enumerate the
    # child 'shell' key as a flyout menu.
    New-ItemProperty -Path $Key -Name 'subcommands' -Value '' -PropertyType String -Force | Out-Null
    if ($Icon) {
        New-ItemProperty -Path $Key -Name 'Icon' -Value $Icon -PropertyType String -Force | Out-Null
    }
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

# Icons are pulled from DLLs already on every Windows install - "path,index"
# - so there is nothing to ship and nothing that can go missing. Indices were
# picked by rendering shell32.dll/imageres.dll to a contact sheet and reading
# off ones that actually look right; they are stable system icons, not magic
# numbers, so they're safe to keep hardcoded.
$ImageRes = "$env:SystemRoot\System32\imageres.dll"
$Shell32  = "$env:SystemRoot\System32\shell32.dll"

$TypeIcons = @{
    Long   = "$ImageRes,8"    # film clip
    Shorts = "$ImageRes,168"  # vertical play
    Photo  = "$ImageRes,43"   # camera
    UI     = "$Shell32,133"   # screen/monitor
    App    = "$ImageRes,217"  # briefcase
}
$DefaultTypeIcon = "$ImageRes,4"  # folder, for any custom type not listed above

# ------------------------------------------- empty space: New with Kram ---

New-CascadeRoot -Key $BackgroundKey -Label 'New with Kram' -Icon "$ImageRes,4"

$i = 1
foreach ($t in $types) {
    $label = if ($t.Value.label) { $t.Value.label } else { $t.Name }
    $icon  = if ($TypeIcons.ContainsKey($t.Name)) { $TypeIcons[$t.Name] } else { $DefaultTypeIcon }
    New-CascadeItem -ParentKey $BackgroundKey `
                    -Order ('{0:d2}_{1}' -f $i, $t.Name) `
                    -Label $label `
                    -Arguments ('-Verb new -Type {0} -Here -Path "%V" -Pause' -f $t.Name) `
                    -Icon $icon
    $i++
}

# ------------------------------------------------ folder: Kram commands ---

New-CascadeRoot -Key $FolderKey -Label 'Kram' -Icon "$ImageRes,156"

New-CascadeItem -ParentKey $FolderKey -Order '01_Organise' `
    -Label 'Organise' `
    -Arguments '-Verb sort -Path "%V" -Pause' `
    -Icon "$ImageRes,227"

New-CascadeItem -ParentKey $FolderKey -Order '02_Preview' `
    -Label 'Preview (show what would move)' `
    -Arguments '-Verb sort -Path "%V" -DryRun -Pause' `
    -Icon "$ImageRes,158"

New-CascadeItem -ParentKey $FolderKey -Order '03_Rename' `
    -Label 'Organise + clean up filenames' `
    -Arguments '-Verb sort -Path "%V" -Rename -Pause' `
    -Icon "$ImageRes,236"

New-CascadeItem -ParentKey $FolderKey -Order '04_Tidy' `
    -Label 'Tidy (final cleanup check)' `
    -Arguments '-Verb tidy -Path "%V" -Pause' `
    -Icon "$ImageRes,131"

Write-Host ""
Write-Host "Kram context menu installed for $env:USERNAME." -ForegroundColor Green
Write-Host ""
Write-Host "  Right-click empty space in a folder -> New with Kram"
Write-Host "  Right-click a folder                -> Kram"
Write-Host ""
Write-Host "On Windows 11 both live under 'Show more options' (Shift+F10)." -ForegroundColor Yellow
Write-Host "No restart needed. Re-run this after editing project types in config.json."
Write-Host "Remove it any time with:  Install-ContextMenu.ps1 -Uninstall"
