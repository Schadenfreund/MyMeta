# Legacy Tools Directory

**⚠️ This directory is no longer used.**

## What Changed

As of **v1.0.0**, MyMeta now includes a **one-click Setup Tools** feature that automatically downloads and configures all required tools on first launch.

Tools are now stored in the **UserData/tools/** directory (next to the executable), not bundled with the application.

## How It Works Now

1. Launch MyMeta
2. Go to **Settings** tab
3. Click **Setup Tools** button
4. Download FFmpeg (required), MKVToolNix, and AtomicParsley with one click
5. Tools are automatically configured

## For Developers

The build process no longer bundles tools from this directory. The CMakeLists.txt has been updated to exclude tool bundling.

If you need to manually place tools for development testing, put them in:
```
<executable_dir>/UserData/tools/
├── ffmpeg/ffmpeg.exe
├── mkvtoolnix/mkvpropedit.exe
└── atomicparsley/AtomicParsley.exe
```

---

**This README is kept for reference only.**
