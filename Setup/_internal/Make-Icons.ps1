#Requires -Version 5.1
<#
    Draws Kram's right-click menu icons into Setup\_internal\icons\*.ico.

    Each icon is a white symbol on a coloured rounded square, rendered fresh at
    every size (16-256 px) so small sizes stay crisp. Symbols come from the
    Windows icon font (Segoe Fluent Icons on Windows 11, Segoe MDL2 Assets on
    Windows 10), so nothing is downloaded.

    The .ico files are committed; you only need to re-run this to restyle them.
    Then run Setup\Install.bat again - Explorer caches icons, so a sign-out
    or Explorer restart may be needed to see the change.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$OutDir = Join-Path $PSScriptRoot 'icons'
New-Item -ItemType Directory -Force $OutDir | Out-Null

$Sizes = 16, 20, 24, 32, 48, 64, 256

$IconFont = if ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains 'Segoe Fluent Icons') {
    'Segoe Fluent Icons'
} else {
    'Segoe MDL2 Assets'
}

# name = (top colour, bottom colour, glyph, font). Glyph is a char code in the
# icon font, or plain text drawn in Segoe UI Black.
$Icons = [ordered]@{
    kram     = @('#FF6A00', '#E5007A', 'K',    'Segoe UI Black')
    long     = @('#8B5CF6', '#5B21B6', 0xE714, $IconFont)  # video
    shorts   = @('#F43F5E', '#BE123C', 0xE768, $IconFont)  # play
    photo    = @('#38BDF8', '#0369A1', 0xE722, $IconFont)  # camera
    ui       = @('#34D399', '#047857', 0xE7F4, $IconFont)  # monitor
    app      = @('#FBBF24', '#B45309', 0xE821, $IconFont)  # briefcase
    organise = @('#60A5FA', '#1D4ED8', 0xE895, $IconFont)  # sync arrows
    preview  = @('#94A3B8', '#475569', 0xE721, $IconFont)  # magnifier
    rename   = @('#FB923C', '#C2410C', 0xE8AC, $IconFont)  # rename
    tidy     = @('#4ADE80', '#15803D', 0xE73E, $IconFont)  # check mark
}

function New-IconBitmap {
    param([int]$Size, [string]$Top, [string]$Bottom, $Glyph, [string]$FontName)

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)

    # Rounded square, nearly full-bleed so it reads at 16 px.
    $pad = [math]::Max(0, [math]::Round($Size * 0.04))
    $w = $Size - 2 * $pad
    $r = [math]::Max(2, $w * 0.24)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($pad, $pad, $r, $r, 180, 90)
    $path.AddArc($pad + $w - $r, $pad, $r, $r, 270, 90)
    $path.AddArc($pad + $w - $r, $pad + $w - $r, $r, $r, 0, 90)
    $path.AddArc($pad, $pad + $w - $r, $r, $r, 90, 90)
    $path.CloseFigure()

    $rect = New-Object System.Drawing.RectangleF $pad, $pad, $w, $w
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect,
        ([System.Drawing.ColorTranslator]::FromHtml($Top)),
        ([System.Drawing.ColorTranslator]::FromHtml($Bottom)), 90
    $g.FillPath($brush, $path)

    $text = if ($Glyph -is [string]) { $Glyph } else { [string][char]$Glyph }
    $scale = if ($Glyph -is [string]) { 0.66 } else { 0.56 }
    $font = New-Object System.Drawing.Font $FontName, ([float]($w * $scale)), ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'
    $fmt.LineAlignment = 'Center'
    $g.DrawString($text, $font, [System.Drawing.Brushes]::White, $rect, $fmt)

    $g.Dispose()
    return $bmp
}

# Classic 32-bit DIB entry: BITMAPINFOHEADER, bottom-up BGRA pixels, then an
# all-zero AND mask (alpha does the masking). Every Windows icon reader
# understands this; PNG entries below 256 px trip up some of them.
function ConvertTo-DibEntry {
    param([System.Drawing.Bitmap]$Bitmap)

    $s = $Bitmap.Width
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $bw.Write([uint32]40); $bw.Write([int32]$s); $bw.Write([int32]($s * 2))
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0)
    $bw.Write([uint32]($s * $s * 4)); $bw.Write([int32]0); $bw.Write([int32]0)
    $bw.Write([uint32]0); $bw.Write([uint32]0)
    for ($y = $s - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $s; $x++) {
            $c = $Bitmap.GetPixel($x, $y)
            $bw.Write([byte]$c.B); $bw.Write([byte]$c.G); $bw.Write([byte]$c.R); $bw.Write([byte]$c.A)
        }
    }
    $maskRow = [math]::Ceiling($s / 32) * 4
    $bw.Write((New-Object byte[] ($maskRow * $s)))
    $bw.Flush()
    return ,$ms.ToArray()
}

# .ico container: DIB entries for small sizes, PNG for 256 px (Vista+ format).
function Save-Ico {
    param([string]$Path, [System.Drawing.Bitmap[]]$Bitmaps)

    $pngs = foreach ($b in $Bitmaps) {
        if ($b.Width -ge 256) {
            $ms = New-Object System.IO.MemoryStream
            $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            ,$ms.ToArray()
        } else {
            ,(ConvertTo-DibEntry $b)
        }
    }

    $fs = [System.IO.File]::Create($Path)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$Bitmaps.Count)
    $offset = 6 + 16 * $Bitmaps.Count
    for ($i = 0; $i -lt $Bitmaps.Count; $i++) {
        $s = $Bitmaps[$i].Width
        $dim = if ($s -ge 256) { 0 } else { $s }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim)
        $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($p in $pngs) { $bw.Write($p) }
    $bw.Close()
}

foreach ($name in $Icons.Keys) {
    $spec = $Icons[$name]
    $bitmaps = foreach ($s in $Sizes) { New-IconBitmap -Size $s -Top $spec[0] -Bottom $spec[1] -Glyph $spec[2] -FontName $spec[3] }
    Save-Ico -Path (Join-Path $OutDir "$name.ico") -Bitmaps $bitmaps
    $bitmaps | ForEach-Object { $_.Dispose() }
    Write-Host "  $name.ico"
}

Write-Host ""
Write-Host "Icons written to $OutDir (glyph font: $IconFont)." -ForegroundColor Green
