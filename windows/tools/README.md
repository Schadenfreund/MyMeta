# Metadata Optimization Tools

This directory contains external tools for fast metadata embedding:

## Required Tools

### 1. MKVToolNix (mkvpropedit.exe + mkvextract.exe)
**Purpose:**
- `mkvpropedit.exe` - Instant in-place metadata editing for MKV files (60-120x faster than FFmpeg)
- `mkvextract.exe` - Instant cover art extraction from MKV files (10-50x faster than FFmpeg)

**Download Instructions:**
1. Visit [MKVToolNix Downloads](https://mkvtoolnix.download/downloads.html)
2. Download: **mkvtoolnix-64-bit-96.0.7z** (latest version)
3. Extract the 7z archive
4. Copy **both** `mkvpropedit.exe` AND `mkvextract.exe` from the extracted folder to this directory
5. File sizes: mkvpropedit ~15MB, mkvextract ~14MB

**Direct Link:** https://mkvtoolnix.download/windows/releases/96.0/mkvtoolnix-64-bit-96.0.7z

**Current Version:** 96.0 "It's My Life" (November 8, 2025)

---

### 2. AtomicParsley.exe
**Purpose:** Fast single-pass metadata editing for MP4 files (10-20x faster than FFmpeg)

**Download Instructions:**
1. Visit [AtomicParsley GitHub Releases](https://github.com/wez/atomicparsley/releases)
2. Download the latest Windows 64-bit executable from the Assets section
3. Rename to `AtomicParsley.exe` if necessary
4. Copy to this directory
5. File size: ~500KB

**Alternative (Chocolatey):**
```powershell
choco install atomicparsley
```
Then copy `AtomicParsley.exe` from `C:\ProgramData\chocolatey\lib\atomicparsley\tools\` to this directory.

**Current Version:** 20240608.083822.1 (June 2024)

---

## After Downloading

Once both executables are in this directory, rebuild the application:

```powershell
flutter build windows --release
```

The tools will be automatically bundled with your application in the build output.

---

## Verification

To verify the tools are working:

1. Build the app: `flutter build windows --release`
2. Check the build output: `build\windows\x64\runner\Release\`
3. Both executables should be present alongside `MyMeta.exe`
4. The app will auto-detect and use these tools for maximum performance

---

## Fallback Behavior

If these tools are not available, the app will automatically fall back to FFmpeg (slower but reliable). The tools are bundled only if present in this directory during build time.

---

## Sources

- [MKVToolNix Official](https://mkvtoolnix.download/)
- [AtomicParsley GitHub](https://github.com/wez/atomicparsley)
- [AtomicParsley on Chocolatey](https://community.chocolatey.org/packages/atomicparsley)
