Add-Type -AssemblyName System.Drawing

$sourcePath = 'C:\Users\saavi\.gemini\antigravity-ide\brain\834b71f1-6647-4050-85b7-9f1b9219e6ec\.user_uploaded\media_1792268060574.png'
$sourceBmp = [System.Drawing.Bitmap]::FromFile($sourcePath)

function Resize-Image($src, $targetPath, $width, $height) {
    $destRect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
    $destImage = New-Object System.Drawing.Bitmap($width, $height)
    $destImage.SetResolution($src.HorizontalResolution, $src.VerticalResolution)

    $graphics = [System.Drawing.Graphics]::FromImage($destImage)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $graphics.DrawImage($src, $destRect, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()

    $parentDir = Split-Path $targetPath -Parent
    if (!(Test-Path $parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    $destImage.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destImage.Dispose()
    Write-Host "Generated: $targetPath ($width x $height)"
}

# 1. Main Flutter Assets
Copy-Item $sourcePath 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\assets\images\logo.png' -Force
Copy-Item $sourcePath 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\assets\images\icon.png' -Force
Write-Host "Copied master logo.png and icon.png"

# 2. Android App Mipmap Launchers
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\android\app\src\main\res\mipmap-mdpi\ic_launcher.png' 48 48
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\android\app\src\main\res\mipmap-hdpi\ic_launcher.png' 72 72
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' 96 96
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' 144 144
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' 192 192

# 3. Web Favicons and PWA Icons
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\web\favicon.png' 64 64
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\web\icons\Icon-192.png' 192 192
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\web\icons\Icon-512.png' 512 512
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\web\icons\Icon-maskable-192.png' 192 192
Resize-Image $sourceBmp 'C:\Users\saavi\Desktop\Dhurmit\apps\mobile\web\icons\Icon-maskable-512.png' 512 512

$sourceBmp.Dispose()
Write-Host "All assets generated successfully!"
