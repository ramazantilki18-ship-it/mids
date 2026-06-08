param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $ProjectRoot 'assets\brand\logo_small.png'
$previewPath = Join-Path $ProjectRoot 'assets\brand\app_icon_denetim_sistemi.png'
$fontPath = 'C:\Windows\Fonts\segoeuib.ttf'

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Bounds,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc($Bounds.X, $Bounds.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Bounds.Right - $diameter, $Bounds.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Bounds.Right - $diameter, $Bounds.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Bounds.X, $Bounds.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$Bitmap)

    $left = $Bitmap.Width
    $top = $Bitmap.Height
    $right = -1
    $bottom = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -gt 8) {
                if ($x -lt $left) { $left = $x }
                if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }

    return [System.Drawing.Rectangle]::FromLTRB($left, $top, $right + 1, $bottom + 1)
}

function Save-ResizedPng {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$Size,
        [string]$Destination
    )

    $bitmap = [System.Drawing.Bitmap]::new(
        $Size,
        $Size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.DrawImage($Source, 0, 0, $Size, $Size)
    $graphics.Dispose()
    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$canvasSize = 1024
$canvas = [System.Drawing.Bitmap]::new(
    $canvasSize,
    $canvasSize,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.Clear([System.Drawing.Color]::Transparent)
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$backgroundPath = New-RoundedRectanglePath `
    -Bounds ([System.Drawing.RectangleF]::new(0, 0, $canvasSize, $canvasSize)) `
    -Radius 110
$whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$graphics.FillPath($whiteBrush, $backgroundPath)

$logo = [System.Drawing.Bitmap]::FromFile($sourcePath)
$logoBounds = Get-AlphaBounds -Bitmap $logo
$logoHeight = 520
$logoWidth = [int][Math]::Round($logoHeight * $logoBounds.Width / $logoBounds.Height)
$logoX = [int](($canvasSize - $logoWidth) / 2)
$logoY = 137
$destination = [System.Drawing.Rectangle]::new($logoX, $logoY, $logoWidth, $logoHeight)
$graphics.DrawImage($logo, $destination, $logoBounds, [System.Drawing.GraphicsUnit]::Pixel)

$fontCollection = [System.Drawing.Text.PrivateFontCollection]::new()
$fontCollection.AddFontFile($fontPath)
$font = [System.Drawing.Font]::new(
    $fontCollection.Families[0],
    54,
    [System.Drawing.FontStyle]::Bold,
    [System.Drawing.GraphicsUnit]::Pixel
)
$textBrush = [System.Drawing.SolidBrush]::new(
    [System.Drawing.ColorTranslator]::FromHtml('#001e61')
)
$textFormat = [System.Drawing.StringFormat]::new()
$textFormat.Alignment = [System.Drawing.StringAlignment]::Center
$textFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
$textFormat.Trimming = [System.Drawing.StringTrimming]::None
$textBounds = [System.Drawing.RectangleF]::new(72, 708, 880, 116)
$label = 'DENET' + [char]0x0130 + 'M S' + [char]0x0130 + 'STEM' + [char]0x0130
$graphics.DrawString($label, $font, $textBrush, $textBounds, $textFormat)

$canvas.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)

$launcherSizes = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

foreach ($entry in $launcherSizes.GetEnumerator()) {
    $destinationPath = Join-Path `
        $ProjectRoot `
        "android\app\src\main\res\$($entry.Key)\ic_launcher.png"
    Save-ResizedPng -Source $canvas -Size $entry.Value -Destination $destinationPath
}

$textFormat.Dispose()
$textBrush.Dispose()
$font.Dispose()
$fontCollection.Dispose()
$logo.Dispose()
$whiteBrush.Dispose()
$backgroundPath.Dispose()
$graphics.Dispose()
$canvas.Dispose()

Write-Output "Launcher icon generated: $previewPath"
