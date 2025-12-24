# MyMeta Windows Release Build Script
# Run this script to create a release package

param(
    [string]$Version = "1.0.1"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyMeta Release Builder v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ReleaseName = "MyMeta-v$Version-windows"
$BuildPath = "build\windows\x64\runner\Release"
$OutputPath = "releases\$ReleaseName"

# Step 1: Clean previous builds
Write-Host "[1/6] Cleaning previous builds..." -ForegroundColor Yellow
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
}
if (Test-Path "releases\$ReleaseName") {
    Remove-Item -Recurse -Force "releases\$ReleaseName"
}

# Step 2: Run flutter clean
Write-Host "[2/6] Running flutter clean..." -ForegroundColor Yellow
flutter clean

# Step 3: Build release
Write-Host "[3/6] Building Windows release (this may take a while)..." -ForegroundColor Yellow
flutter build windows --release

if (-not (Test-Path "$BuildPath\MyMeta.exe")) {
    Write-Host "❌ Build failed! MyMeta.exe not found." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build successful!" -ForegroundColor Green

# Step 4: Create release directory structure
Write-Host "[4/6] Creating release package..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# Copy executable and DLLs
Write-Host "  - Copying executable and DLLs..." -ForegroundColor Gray
Copy-Item "$BuildPath\MyMeta.exe" $OutputPath
Get-ChildItem "$BuildPath\*.dll" | Copy-Item -Destination $OutputPath

# Copy data folder (flutter assets)
Write-Host "  - Copying app resources..." -ForegroundColor Gray
Copy-Item "$BuildPath\data" $OutputPath -Recurse

# Copy documentation
Write-Host "  - Copying documentation..." -ForegroundColor Gray
Copy-Item "README.md" $OutputPath -ErrorAction SilentlyContinue
Copy-Item "QUICK_START.md" $OutputPath -ErrorAction SilentlyContinue
Copy-Item "LICENSE" $OutputPath -ErrorAction SilentlyContinue
Copy-Item "CHANGELOG.md" $OutputPath -ErrorAction SilentlyContinue

# Create UserData structure
Write-Host "  - Creating UserData structure..." -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path "$OutputPath\UserData\tools\ffmpeg" | Out-Null
New-Item -ItemType Directory -Force -Path "$OutputPath\UserData\tools\mkvpropedit" | Out-Null
New-Item -ItemType Directory -Force -Path "$OutputPath\UserData\tools\AtomicParsley" | Out-Null

# Create UserData README
@"
# UserData Folder

This folder contains your personal settings and tool configurations.

## What's Stored Here:
- settings.db      → Your app configuration (API keys, preferences, statistics)
- tools/           → External tools (FFmpeg, mkvpropedit, AtomicParsley)
  - ffmpeg/
  - mkvpropedit/
  - AtomicParsley/

## Important Notes:
✅ **This folder is preserved during updates!**
   When updating MyMeta, your settings and tools remain intact.

✅ **Portable Installation:**
   UserData is stored alongside MyMeta.exe if the app can't access AppData

✅ **Backup Recommended:**
   Consider backing up this folder before major updates

## Tools Setup:
Place your external tools in the respective folders:
- FFmpeg: Extract ffmpeg.exe, ffprobe.exe to tools/ffmpeg/bin/
- mkvpropedit: Extract mkvpropedit.exe to tools/mkvpropedit/
- AtomicParsley: Extract AtomicParsley.exe to tools/AtomicParsley/

For detailed instructions, see QUICK_START.md
"@ | Out-File "$OutputPath\UserData\README.txt" -Encoding UTF8

Write-Host "✅ Release package created!" -ForegroundColor Green

# Step 5: Create ZIP archive
Write-Host "[5/6] Creating ZIP archive..." -ForegroundColor Yellow
$ZipPath = "releases\$ReleaseName.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath
}

Compress-Archive -Path $OutputPath -DestinationPath $ZipPath -CompressionLevel Optimal

# Get file size
$ZipSize = (Get-Item $ZipPath).Length / 1MB
Write-Host "✅ ZIP created: $ZipPath ($([math]::Round($ZipSize, 2)) MB)" -ForegroundColor Green

# Step 6: Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Release Package Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Version:      $Version" -ForegroundColor White
Write-Host "Package:      $ZipPath" -ForegroundColor White
Write-Host "Size:         $([math]::Round($ZipSize, 2)) MB" -ForegroundColor White
Write-Host "Folder:       $OutputPath" -ForegroundColor White
Write-Host ""

# List contents
Write-Host "Package Contents:" -ForegroundColor Yellow
Get-ChildItem $OutputPath -Recurse -File | Select-Object -ExpandProperty FullName | ForEach-Object {
    $relativePath = $_.Substring((Get-Item $OutputPath).FullName.Length + 1)
    Write-Host "  - $relativePath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Test the release package on a clean system" -ForegroundColor White
Write-Host "2. Create Git tag:" -ForegroundColor White
Write-Host "   git tag -a v$Version -m `"Release v$Version`"" -ForegroundColor Gray
Write-Host "3. Push tag:" -ForegroundColor White
Write-Host "   git push origin v$Version" -ForegroundColor Gray
Write-Host "4. Create GitHub Release at:" -ForegroundColor White
Write-Host "   https://github.com/Schadenfreund/MyMeta/releases/new" -ForegroundColor Gray
Write-Host "5. Upload: $ZipPath" -ForegroundColor White
Write-Host ""
Write-Host "✅ Release build complete!" -ForegroundColor Green
