# Build and package the Windows app with its current source snapshot.
param([switch]$SkipBuild, [switch]$KeepBuild)

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
. (Join-Path $PSScriptRoot 'scripts/release-package.ps1')
$BuildSource = $null
if (-not $SkipBuild) {
    if (-not $KeepBuild) {
        flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'Flutter clean failed.' }
    }
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    $BuildSource = @(Get-ReleaseSourceManifest $PSScriptRoot)
    flutter build windows --release --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Flutter Windows build failed.' }
}
$FlutterExecutable = if (-not $SkipBuild) { 'flutter' }
$release = New-WindowsReleasePackage -ProjectRoot $PSScriptRoot -AppName 'MyMeta' -ExeName 'MyMeta.exe' `
    -BuildSource $BuildSource -FlutterExecutable $FlutterExecutable -PreparePackage {
    param($OutputPath)
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
}
Write-Host "Created $($release.ZipPath) with $($release.SourceFiles) source files." -ForegroundColor Green
Write-Host "Test folder: $($release.OutputPath)"
