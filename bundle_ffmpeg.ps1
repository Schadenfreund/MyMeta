# Bundle FFmpeg with Simpler FileBot
# This script downloads FFmpeg and places it in the build directory

Write-Host "📦 Bundling FFmpeg with Simpler FileBot..." -ForegroundColor Cyan

$buildDir = "build\windows\x64\runner\Release"
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
$tempZip = "$env:TEMP\ffmpeg.zip"
$tempExtract = "$env:TEMP\ffmpeg_extract"

# Check if build directory exists
if (!(Test-Path $buildDir)) {
    Write-Host "❌ Build directory not found. Please run 'flutter build windows --release' first." -ForegroundColor Red
    exit 1
}

# Download FFmpeg
Write-Host "⬇️  Downloading FFmpeg..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $tempZip -UseBasicParsing
    Write-Host "✅ Downloaded FFmpeg" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to download FFmpeg: $_" -ForegroundColor Red
    exit 1
}

# Extract
Write-Host "📂 Extracting FFmpeg..." -ForegroundColor Yellow
if (Test-Path $tempExtract) {
    Remove-Item $tempExtract -Recurse -Force
}
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# Find ffmpeg.exe
$ffmpegExe = Get-ChildItem -Path $tempExtract -Filter "ffmpeg.exe" -Recurse | Select-Object -First 1

if (!$ffmpegExe) {
    Write-Host "❌ ffmpeg.exe not found in archive" -ForegroundColor Red
    exit 1
}

# Copy to build directory
Copy-Item $ffmpegExe.FullName -Destination "$buildDir\ffmpeg.exe" -Force
Write-Host "✅ Copied ffmpeg.exe to build directory" -ForegroundColor Green

# Cleanup
Remove-Item $tempZip -Force
Remove-Item $tempExtract -Recurse -Force

Write-Host "`n✅ FFmpeg bundled successfully!" -ForegroundColor Green
Write-Host "📁 Location: $buildDir\ffmpeg.exe" -ForegroundColor Cyan
Write-Host "`n🚀 Your app is now ready to distribute!" -ForegroundColor Green
