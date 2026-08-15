#Requires -Version 5.1
<#
    Organise.ps1 - project scaffolder + root-folder organiser.

    Verbs
      new   -Type <Long|Shorts|Photo|UI>   Scaffold a new project and open it.
      sort                                 Sweep loose items in a project root into
                                           the managed folders. Safe to re-run.
      tidy                                 Deep report before archiving. Dry-run
                                           unless -Apply is passed.

    The toolkit is portable: everything resolves from $PSScriptRoot, so this
    folder can be moved anywhere.
#>

[CmdletBinding()]
param(
    [ValidateSet('new', 'sort', 'tidy')]
    [string]$Verb = 'sort',

    [string]$Type,

    [string]$Name,

    # Language pack for folder names: en, hi-Latn, hi-Deva (see locales/).
    # Defaults to config's defaultLocale. Stored per-project, so projects in
    # different languages coexist happily.
    [string]$Locale,

    [string]$Path = (Get-Location).Path,

    # Create the project in the current directory instead of projectsRoot.
    [switch]$Here,

    # tidy only: actually move things instead of just reporting.
    [switch]$Apply,

    # Clean junk out of downloaded filenames. Never appends sequential numbers,
    # so this cannot accidentally manufacture an image sequence.
    [switch]$Rename,

    # sort/tidy: report what would happen, change nothing.
    [switch]$DryRun,

    # Wait for a keypress before closing. Used by the Explorer context menu,
    # which would otherwise flash the console and vanish before you can read it.
    [switch]$Pause
)

$ErrorActionPreference = 'Stop'

# Language packs can carry non-Latin folder names (Devanagari, and whatever
# gets contributed later). Without this the console prints them as mojibake.
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$ToolRoot     = $PSScriptRoot
$ConfigPath   = Join-Path $ToolRoot 'config.json'
$LocalPath    = Join-Path $ToolRoot 'config.local.json'
$TemplateRoot = Join-Path $ToolRoot '_Templates'
$LocaleRoot   = Join-Path $ToolRoot 'locales'
$MarkerName   = '.project.json'
$LogName      = 'organise-log.json'

# ---------------------------------------------------------------- helpers ---

function Write-Info  { param($m) Write-Host $m }
function Write-Good  { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host $m -ForegroundColor Yellow }
function Write-Bad   { param($m) Write-Host $m -ForegroundColor Red }

# Shipped defaults, with config.local.json layered on top so a user's personal
# paths never collide with the committed file.
function Get-Config {
    if (-not (Test-Path $ConfigPath)) {
        throw "config.json not found next to the script ($ConfigPath)."
    }
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    if (Test-Path $LocalPath) {
        $local = Get-Content $LocalPath -Raw | ConvertFrom-Json
        foreach ($p in $local.PSObject.Properties) {
            $config | Add-Member -MemberType NoteProperty -Name $p.Name -Value $p.Value -Force
        }
    }

    $config.projectsRoot = [Environment]::ExpandEnvironmentVariables($config.projectsRoot)
    return $config
}

function Get-Locale {
    param([string]$Code)

    if (-not $Code) { return @{} }
    $file = Join-Path $LocaleRoot "$Code.json"
    if (-not (Test-Path $file)) {
        $available = (Get-ChildItem $LocaleRoot -Filter '*.json' -ErrorAction SilentlyContinue |
                      ForEach-Object { $_.BaseName }) -join ', '
        Write-Warn "Language pack '$Code' not found - using canonical English names."
        Write-Warn "Available: $available"
        return @{}
    }
    $pack = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    return (ConvertTo-Hashtable $pack.folders)
}

# Translates each segment of a folder path independently, so a pack only has to
# name the segments it actually wants to change.
function Convert-ToLocaleName {
    param([string]$FolderPath, [hashtable]$Map)

    if ($Map.Count -eq 0) { return $FolderPath }
    $parts = $FolderPath -split '[\\/]'
    $out = foreach ($p in $parts) { if ($Map.ContainsKey($p)) { $Map[$p] } else { $p } }
    return ($out -join '\')
}

function ConvertTo-Hashtable {
    param($Object)
    $h = @{}
    if ($null -eq $Object) { return $h }
    foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}

function Get-SafeName {
    param([string]$Raw)
    $invalid = [IO.Path]::GetInvalidFileNameChars() -join ''
    $pattern = "[{0}]" -f [regex]::Escape($invalid)
    $clean = ($Raw -replace $pattern, '_').Trim().Trim('.')
    $clean = $clean -replace '\s+', ' '
    return $clean
}

function Get-SanitisedFileName {
    param([string]$BaseName)
    $s = [uri]::UnescapeDataString($BaseName)
    $s = $s -replace '[^\w\-. ()\[\]]', '_'   # drop punctuation soup, keep brackets
    $s = $s -replace '_{2,}', '_'
    $s = $s -replace '\s{2,}', ' '
    $s = $s.Trim(' ', '_', '-')
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60).TrimEnd(' ', '_', '-') }
    if ([string]::IsNullOrWhiteSpace($s)) { $s = 'file' }
    return $s
}

function Show-InputBox {
    param([string]$Prompt, [string]$Title)
    Add-Type -AssemblyName Microsoft.VisualBasic
    return [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, '')
}

# Managed folders = the top-level folders defined by _Base plus the type
# template. Reading them at runtime means editing a template folder in
# Explorer is all it takes to teach the script a new managed folder.
function Get-ManagedFolders {
    param([string]$TypeName, $Config, [hashtable]$Locale = @{})

    $names = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    $sources = @('_Base')
    if ($TypeName -and $Config.types.$TypeName) { $sources += $Config.types.$TypeName.template }

    foreach ($src in $sources) {
        $dir = Join-Path $TemplateRoot $src
        if (Test-Path $dir) {
            Get-ChildItem $dir -Directory | ForEach-Object {
                [void]$names.Add((Convert-ToLocaleName -FolderPath $_.Name -Map $Locale))
            }
        }
    }

    # Any folder the rules point at also counts as managed, even if the
    # template happens not to contain it yet.
    $rules = Get-Rules -TypeName $TypeName -Config $Config -Locale $Locale
    foreach ($dest in $rules.Values) {
        $top = ($dest -split '[\\/]')[0]
        [void]$names.Add($top)
    }
    return $names
}

function Get-Rules {
    param([string]$TypeName, $Config, [hashtable]$Locale = @{})

    $rules = ConvertTo-Hashtable $Config.defaultRules
    if ($TypeName -and $Config.types.$TypeName) {
        $override = ConvertTo-Hashtable $Config.types.$TypeName.rules
        foreach ($k in $override.Keys) { $rules[$k] = $override[$k] }
    }

    if ($Locale.Count -gt 0) {
        foreach ($k in @($rules.Keys)) {
            $rules[$k] = Convert-ToLocaleName -FolderPath $rules[$k] -Map $Locale
        }
    }
    return $rules
}

function Get-ProjectMarker {
    param([string]$ProjectPath)
    $marker = Join-Path $ProjectPath $MarkerName
    if (Test-Path $marker) {
        return Get-Content $marker -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    return $null
}

function Test-FileLocked {
    param([string]$FilePath)
    try {
        $fs = [IO.File]::Open($FilePath, 'Open', 'ReadWrite', 'None')
        $fs.Close()
        $fs.Dispose()
        return $false
    } catch {
        return $true
    }
}

function Get-UniquePath {
    param([string]$Destination)
    if (-not (Test-Path $Destination)) { return $Destination }

    $dir  = Split-Path $Destination -Parent
    $base = [IO.Path]::GetFileNameWithoutExtension($Destination)
    $ext  = [IO.Path]::GetExtension($Destination)

    $i = 2
    while ($true) {
        $candidate = Join-Path $dir ("{0} ({1}){2}" -f $base, $i, $ext)
        if (-not (Test-Path $candidate)) { return $candidate }
        $i++
    }
}

# Groups root-level files into image sequences. A sequence is >= N files that
# share a prefix, an extension, and a zero-padding width. These must move as a
# unit or the sequence is destroyed.
function Group-Sequences {
    param([array]$Files, [int]$MinFrames)

    $groups = @{}
    foreach ($f in $Files) {
        $base = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        if ($base -match '^(.*?)(\d{2,})$') {
            $key = '{0}|{1}|{2}' -f $Matches[1].ToLower(), $f.Extension.ToLower(), $Matches[2].Length
            if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
            $groups[$key] += $f
        }
    }

    $sequences = @()
    foreach ($k in $groups.Keys) {
        if ($groups[$k].Count -ge $MinFrames) {
            $sequences += , @{
                Prefix = ($k -split '\|')[0]
                Files  = $groups[$k]
            }
        }
    }
    return $sequences
}

# For a dropped folder, pick the destination its contents most agree on.
function Get-FolderDestination {
    param([string]$FolderPath, [hashtable]$Rules)

    $tally = @{}
    Get-ChildItem $FolderPath -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = $Rules[$_.Extension.ToLower()]
        if ($dest) {
            if (-not $tally.ContainsKey($dest)) { $tally[$dest] = 0 }
            $tally[$dest]++
        }
    }
    if ($tally.Count -eq 0) { return $null }
    return ($tally.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
}

function Add-LogEntry {
    param([string]$ProjectPath, [array]$Moves)
    if ($Moves.Count -eq 0) { return }

    $logPath = Join-Path $ProjectPath $LogName
    $log = @()
    if (Test-Path $logPath) {
        $existing = Get-Content $logPath -Raw | ConvertFrom-Json
        if ($existing) { $log = @($existing) }
    }
    $log += [pscustomobject]@{
        timestamp = (Get-Date).ToString('s')
        moves     = $Moves
    }
    $log | ConvertTo-Json -Depth 6 | Set-Content $logPath -Encoding UTF8
}

# -------------------------------------------------------------------- new ---

function Invoke-New {
    param($Config)

    if (-not $Type) { throw "new requires -Type (one of: $($Config.types.PSObject.Properties.Name -join ', '))" }
    if (-not $Config.types.$Type) { throw "Unknown type '$Type'." }

    $projName = $Name
    if (-not $projName) { $projName = Show-InputBox -Prompt 'Project name' -Title "New $Type project" }
    $projName = Get-SafeName $projName
    if ([string]::IsNullOrWhiteSpace($projName)) {
        Write-Warn 'No name entered. Nothing created.'
        return $false
    }

    $stamp      = Get-Date -Format 'yyyyMMdd'
    $folderName = "{0}_{1}" -f $stamp, $projName

    if ($Here) {
        # -Path defaults to the working directory, so the CLI behaves as before
        # while the Explorer context menu can hand us %V.
        $parent = $Path
    } else {
        $parent = Join-Path $Config.projectsRoot $Type
    }
    $target = Join-Path $parent $folderName

    if (Test-Path $target) {
        Write-Bad "'$target' already exists. Pick a different name."
        return $false
    }

    New-Item -ItemType Directory -Path $target -Force | Out-Null

    # _Base first, then the type template layered on top.
    foreach ($src in @('_Base', $Config.types.$Type.template)) {
        $dir = Join-Path $TemplateRoot $src
        if (Test-Path $dir) {
            Copy-Item -Path (Join-Path $dir '*') -Destination $target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Template files are named PROJECT.aep etc. Rename to the real project name.
    Get-ChildItem $target -Recurse -File -Filter 'PROJECT*' | ForEach-Object {
        $new = $_.Name -replace '^PROJECT', $projName
        Rename-Item $_.FullName -NewName $new
    }

    # Placeholder files that only exist to keep empty folders in the template.
    Get-ChildItem $target -Recurse -File -Filter '.keep' -Force | Remove-Item -Force

    # Apply the language pack. Deepest-first so renaming a parent can't
    # invalidate the paths of children still queued.
    $localeCode = if ($Locale) { $Locale } else { $Config.defaultLocale }
    $map = Get-Locale $localeCode
    if ($map.Count -gt 0) {
        Get-ChildItem $target -Recurse -Directory |
            Sort-Object { $_.FullName.Split('\').Count } -Descending |
            ForEach-Object {
                if ($map.ContainsKey($_.Name)) {
                    Rename-Item $_.FullName -NewName $map[$_.Name] -ErrorAction SilentlyContinue
                }
            }
    }

    [pscustomobject]@{
        name    = $projName
        type    = $Type
        locale  = $localeCode
        created = (Get-Date).ToString('s')
        version = 1
    } | ConvertTo-Json | Set-Content (Join-Path $target $MarkerName) -Encoding UTF8

    $support = Join-Path $ToolRoot 'templates-support'
    if (Test-Path $support) {
        # Projects live anywhere, so bake the toolkit location into the
        # launcher rather than relying on a relative path.
        Get-ChildItem $support -Filter '*.bat' | ForEach-Object {
            (Get-Content $_.FullName -Raw).Replace('__TOOLROOT__', $ToolRoot) |
                Set-Content (Join-Path $target $_.Name) -Encoding ASCII
        }
    }

    Write-Good "Created $target"
    Start-Process explorer.exe $target
    return $true
}

# ------------------------------------------------------------ sort / tidy ---

function Invoke-Sort {
    param($Config, [switch]$Deep, [switch]$Preview)

    $project = (Resolve-Path $Path).Path
    $marker  = Get-ProjectMarker $project

    if (-not $marker) {
        Write-Bad "No $MarkerName here - '$project' isn't a project folder."
        Write-Info "Run:  Organise.ps1 -Verb new -Type <Type>   (or -Here inside an existing folder)"
        return
    }

    $typeName   = $marker.type
    $localeCode = if ($marker.locale) { $marker.locale } else { $Config.defaultLocale }
    $map        = Get-Locale $localeCode

    $rules    = Get-Rules -TypeName $typeName -Config $Config -Locale $map
    $managed  = Get-ManagedFolders -TypeName $typeName -Config $Config -Locale $map
    $protected = @($Config.protectedRootFiles)
    $minFrames = [int]$Config.sequenceMinFrames

    Write-Info ""
    Write-Info "Project : $(Split-Path $project -Leaf)"
    Write-Info "Type    : $typeName  ($localeCode)"
    if ($Preview) { Write-Warn "Mode    : preview (nothing will move)" }
    Write-Info ""

    $plan    = @()
    $skipped = @()

    # --- loose files in the root -------------------------------------------
    $rootFiles = Get-ChildItem $project -File | Where-Object {
        $protected -notcontains $_.Name -and $_.Name -notlike '.*'
    }

    # Sequences first, so their members are excluded from per-file handling.
    $sequences = Group-Sequences -Files $rootFiles -MinFrames $minFrames
    $inSequence = New-Object System.Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)

    foreach ($seq in $sequences) {
        $dest = $rules[$seq.Files[0].Extension.ToLower()]
        if (-not $dest) { continue }

        $seqFolder = Get-SafeName ($seq.Prefix.TrimEnd('_', '-', ' '))
        if ([string]::IsNullOrWhiteSpace($seqFolder)) { $seqFolder = 'sequence' }

        foreach ($f in $seq.Files) {
            [void]$inSequence.Add($f.Name)
            $plan += [pscustomobject]@{
                Kind = 'sequence'
                From = $f.FullName
                To   = Join-Path (Join-Path $project (Join-Path $dest "${seqFolder}_seq")) $f.Name
                Note = "sequence '$seqFolder' ($($seq.Files.Count) frames)"
            }
        }
    }

    foreach ($f in $rootFiles) {
        if ($inSequence.Contains($f.Name)) { continue }

        $dest = $rules[$f.Extension.ToLower()]
        if (-not $dest) {
            $skipped += "$($f.Name)  - no rule for '$($f.Extension)'"
            continue
        }
        if (Test-FileLocked $f.FullName) {
            $skipped += "$($f.Name)  - file is open in another program"
            continue
        }

        $leaf = $f.Name
        if ($Rename) {
            $leaf = '{0}{1}' -f (Get-SanitisedFileName ([IO.Path]::GetFileNameWithoutExtension($f.Name))), $f.Extension
        }

        $plan += [pscustomobject]@{
            Kind = 'file'
            From = $f.FullName
            To   = Join-Path (Join-Path $project $dest) $leaf
            Note = ''
        }
    }

    # --- dropped folders in the root ---------------------------------------
    $rootDirs = Get-ChildItem $project -Directory | Where-Object {
        -not $managed.Contains($_.Name) -and $_.Name -notlike '.*'
    }

    foreach ($d in $rootDirs) {
        $dest = Get-FolderDestination -FolderPath $d.FullName -Rules $rules
        if (-not $dest) {
            $skipped += "$($d.Name)\  - couldn't tell what's in it"
            continue
        }
        $plan += [pscustomobject]@{
            Kind = 'folder'
            From = $d.FullName
            To   = Join-Path (Join-Path $project $dest) $d.Name
            Note = 'moved intact'
        }
    }

    # --- deep pass (tidy) ---------------------------------------------------
    if ($Deep) {
        Write-Info "Deep scan - checking for strays inside managed folders..."
        foreach ($folder in $managed) {
            $fp = Join-Path $project $folder
            if (-not (Test-Path $fp)) { continue }
            Get-ChildItem $fp -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $want = $rules[$_.Extension.ToLower()]
                if ($want) {
                    $wantTop = ($want -split '[\\/]')[0]
                    if ($wantTop -ne $folder) {
                        $skipped += "$($_.FullName.Substring($project.Length + 1))  - looks like it belongs in $want (left alone; may be linked in your edit)"
                    }
                }
            }
        }
        Write-Info ""
    }

    # --- report -------------------------------------------------------------
    if ($plan.Count -eq 0) {
        Write-Good "Nothing to organise - root is clean."
    } else {
        foreach ($p in $plan) {
            $rel = $p.To.Substring($project.Length + 1)
            $note = if ($p.Note) { "   [$($p.Note)]" } else { '' }
            Write-Info ("  {0,-40} -> {1}{2}" -f (Split-Path $p.From -Leaf), $rel, $note)
        }
    }

    if ($skipped.Count -gt 0) {
        Write-Info ""
        Write-Warn "Left in place:"
        $skipped | ForEach-Object { Write-Warn "  $_" }
    }

    if ($Preview) {
        Write-Info ""
        if ($Deep) {
            Write-Warn "Preview. -Apply performs the root-level moves listed above."
            Write-Warn "Files already nested in a managed folder are reported only and are"
            Write-Warn "never moved automatically - they may be linked in your edit. Move"
            Write-Warn "those by hand once the project is closed."
        } else {
            Write-Warn "Preview only. Re-run without -DryRun to move these."
        }
        return
    }

    # --- execute ------------------------------------------------------------
    $done = @()
    foreach ($p in $plan) {
        $destDir = Split-Path $p.To -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

        $final = Get-UniquePath $p.To
        try {
            Move-Item -LiteralPath $p.From -Destination $final -Force:$false
            $done += [pscustomobject]@{ from = $p.From; to = $final }
        } catch {
            Write-Bad "  failed: $($p.From) - $($_.Exception.Message)"
        }
    }

    Add-LogEntry -ProjectPath $project -Moves $done

    Write-Info ""
    Write-Good "Moved $($done.Count) item(s)."
    if ($done.Count -gt 0) { Write-Info "Log: $LogName" }
}

# ------------------------------------------------------------------- main ---

try {
    $config = Get-Config

    $newSucceeded = $false
    switch ($Verb) {
        'new'  { $newSucceeded = Invoke-New -Config $config }
        'sort' { Invoke-Sort -Config $config -Preview:$DryRun }
        'tidy' { Invoke-Sort -Config $config -Deep -Preview:(-not $Apply) }
    }

    # 'new' opens Explorer on success, so holding a console open on top of it
    # is just noise. But a failed/aborted 'new' (no name entered, folder
    # already exists) must still pause - otherwise the message flashes and
    # closes before anyone can read it.
    if ($Pause -and ($Verb -ne 'new' -or -not $newSucceeded)) {
        Write-Info ""
        Read-Host 'Press Enter to close'
    }
} catch {
    Write-Bad "Error: $($_.Exception.Message)"
    if ($Pause) { Write-Info ""; Read-Host 'Press Enter to close' }
    exit 1
}
