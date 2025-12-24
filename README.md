# MyMeta

**Professional Media File Metadata Manager**

MyMeta is a user-friendly desktop application for automatically fetching, editing, and embedding metadata into your media files. Say goodbye to manual file organization and inconsistent naming!

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Features

![MyMeta - Search](https://github.com/user-attachments/assets/78b690f4-1e55-4cbb-b36e-ebafeaa03990)

### **Automatic Metadata Fetching**
- Search **The Movie Database (TMDB)**, **OMDb**, and **AniDB** for accurate metadata
- **TMDB** - Comprehensive movie and TV show data
- **OMDb** - IMDb-based alternative source
- **AniDB** - Specialized anime database
- Automatic title, year, genre, cast, director, and rating extraction
- High-quality cover art download and embedding

### **File Renaming**
- Customizable naming templates for movies and TV shows
- Smart filename parsing for better matching
- Batch processing support

### **Rich Metadata Embedding**
- Embedded metadata includes:
  - Title, year, description
  - Genres, director, actors
  - Rating, content rating, runtime
  - **Cover art** (MP4 & MKV)
- All metadata embedded directly into video files

### **Modern UI**
- Custom titlebar with window controls
- **8 accent color themes** - Choose your favorite!
- Dark & Light mode support
- Inline metadata editing
- Clean, professional interface
- **Centralized card design system** for consistent UX

### **User Features**
- **Easy tool setup** - Download FFmpeg, MKVToolNix, and AtomicParsley with one click

![MyMeta - setup](https://github.com/user-attachments/assets/b5aa87c9-438f-4f6b-a7ea-49b6fa10e266)

  
- **60-120x faster processing** with specialized tools (MKVToolNix for MKV, AtomicParsley for MP4)
- Undo rename operations
- Folder exclusion lists
- Format templates
- Drag & drop support
- Portable - all tools stored in UserData folder

---

## 🚀 Quick Start

### **1. Download & Extract**
Download the latest release and extract to any folder.

### **2. Run MyMeta.exe**
Double-click `MyMeta.exe` - no installation needed!

### **3. Setup Tools (First Launch)**
1. Open **Settings** tab
2. Click **Setup Tools** button
3. Download **FFmpeg** (required, ~80 MB)
4. Optionally download **AtomicParsley** and **MKVToolNix** for faster processing

### **4. Add Your API Keys**
1. Still in **Settings** tab
2. Get free API keys:
   - **TMDB:** [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api)
   - **OMDb:** [omdbapi.com/apikey.aspx](http://www.omdbapi.com/apikey.aspx)
   - **AniDB (optional):** [wiki.anidb.net/API](https://wiki.anidb.net/API) - For anime metadata
3. Paste keys in Settings

### **5. Start Organizing**
1. Click **Add Files** or drag & drop media files
2. Click **Match** to fetch metadata
3. Review and edit as needed
4. Click **Rename Files** to apply changes

---

## 📋 Requirements

- **OS:** Windows 10/11 (64-bit)
- **Disk Space:** ~20 MB (app) + ~100 MB (FFmpeg - downloaded on first launch)
- **Internet:** Required for metadata fetching and tool downloads
- **API Keys:** Free TMDB and/or OMDb API key

---

## 🎯 Use Cases

### **Movie Collections**
Automatically rename and organize your movie library with consistent naming:
```
random_movie_file.mp4  →  The Matrix (1999).mp4
```
Complete with embedded metadata and cover art!

### **TV Show Episodes**
Organize episode files with proper season/episode numbering:
```
show.s01e01.mkv  →  Breaking Bad - S01E01 - Pilot.mkv
```

### **Media Server Prep**
Perfect for preparing files for Plex, Jellyfin, or Kodi with:
- Embedded metadata
- Cover art
- Consistent naming
- Proper formatting

---

## 📖 Documentation

- **[Quick Start Guide](QUICK_START.md)** - Step-by-step tutorial
- **[Architecture](ARCHITECTURE.md)** - Technical deep-dive
- **[Changelog](CHANGELOG.md)** - Version history & guidelines

---

## 🎨 Customization

### **Accent Colors**
Choose from 8 beautiful accent colors:
- Indigo (Default)
- Blue
- Purple  
- Pink
- Red
- Orange
- Green
- Teal

### **Naming Templates**
Customize how files are named:

**Movies:**
```
{movie_name} ({year})
→ Inception (2010).mp4
```

**TV Shows:**
```
{series_name} - S{season_number}E{episode_number} - {episode_title}
→ Game of Thrones - S01E01 - Winter Is Coming.mkv
```

---

## 🛠️ Supported Formats

### **Video Files**
- **MP4** - Full metadata + cover art embedding
- **MKV** - Full metadata + cover art attachment

### **Metadata Providers**
- **TMDB** - The Movie Database (comprehensive movie/TV metadata)
- **OMDb** - IMDb data (alternative source)
- **AniDB** - Anime Database (specialized anime metadata)

---

## ❓ FAQ

### **Do I need to install FFmpeg?**
No manual installation needed! MyMeta has a built-in Setup dialog that downloads and configures FFmpeg, MKVToolNix, and AtomicParsley with one click. Just go to Settings → Setup Tools → Download.

- **FFmpeg** (required) - Core metadata embedding
- **MKVToolNix** (optional) - 60-120x faster MKV processing
- **AtomicParsley** (optional) - 60-120x faster MP4 processing

### **Does it modifyoriginal files?**
Yes, but safely:
- Metadata is embedded into the file
- Original content is preserved
- Undo support available
- No quality loss (codec copy)

### **Can I edit metadata manually?**
Yes! Click any file to expand the inline editor and modify any field.

### **What if the match is wrong?**
Simply edit the metadata inline before renaming. All fields are editable.

### **Is my data private?**
Yes! All processing happens locally. Only metadata queries go to TMDB/OMDb APIs.

---

## 🔧 Troubleshooting

### **No metadata fetched**
- Check your API keys in Settings
- Verify internet connection
- Try alternative provider (TMDB ↔ OMDb)

### **Cover art not embedding**
- Ensure FFmpeg is downloaded (Settings → Setup Tools)
- Ensure file format is MP4 or MKV
- Check console output for errors
- Try re-downloading FFmpeg via Setup dialog

### **File not renamed**
- Click "Match" before "Rename"
- Ensure metadata was fetched successfully
- Check file permissions

---

## 📝 Changelog

### **Version 1.0.0** - Current (Initial Public Release)
- Zero lint issues - production-ready code quality
- TMDB, OMDb & AniDB metadata integration
- One-click tool setup (FFmpeg, MKVToolNix, AtomicParsley)
- 8 accent color themes with dark/light mode
- Cover art embedding for MP4 & MKV files
- Customizable naming templates
- Portable design - no installation needed
- Modern, polished UI with custom titlebar

See [CHANGELOG.md](CHANGELOG.md) for full version history.

---

## 🤝 Contributing

MyMeta is a personal project, but feedback and suggestions are welcome!

**Found a bug?** Open an issue with:
- Steps to reproduce
- Expected vs actual behavior
- Console output if available

**Feature request?** Describe:
- Use case
- Expected behavior
- Why it would be useful

---

## 📄 License

MIT License - Feel free to use, modify, and distribute.

---

## 🙏 Credits

**Built with:**
- [Flutter](https://flutter.dev) - Cross-platform framework
- [TMDB API](https://www.themoviedb.org) - Movie/TV metadata
- [OMDb API](https://www.omdbapi.com) - IMDb data

---

## 🔧 Third-Party Tools

MyMeta uses the following optional external tools (downloaded separately on-demand):

| Tool | License | Purpose |
|------|---------|--------|
| [FFmpeg](https://ffmpeg.org) | LGPL/GPL | Media processing & metadata embedding |
| [MKVToolNix](https://mkvtoolnix.download) | GPL 2.0 | Fast MKV metadata editing |
| [AtomicParsley](https://github.com/wez/atomicparsley) | GPL 2.0 | Fast MP4 metadata editing |

**Note:** These tools are NOT bundled with MyMeta. They are downloaded by the user on first launch and executed as separate external processes. See [LICENSE](LICENSE) for details.

---

## 📧 Support

For questions, feedback, or support:
- Check the [Quick Start Guide](QUICK_START.md)
- Review [Architecture docs](ARCHITECTURE.md)
- Search existing issues

---

<div align="center">

**MyMeta** - Your Personal Metadata Manager

Made with ❤️ for media enthusiasts

[Download Latest Release](#) | [Documentation](QUICK_START.md) | [Report Bug](#)

</div>
