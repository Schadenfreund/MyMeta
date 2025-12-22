# MyMeta

**Professional Media File Metadata Manager**

MyMeta is a powerful, user-friendly desktop application for automatically fetching, editing, and embedding metadata into your media files. Say goodbye to manual file organization and inconsistent naming!

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Features

### **Automatic Metadata Fetching**
- Search **The Movie Database (TMDB)** and **OMDb** for accurate metadata
- Automatic title, year, genre, cast, director, and rating extraction
- High-quality cover art download and embedding

### **Professional File Renaming**
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

### **Beautiful, Modern UI**
- Custom titlebar with window controls
- **8 accent color themes** - Choose your favorite!
- Dark & Light mode support
- Inline metadata editing
- Clean, professional interface
- **Centralized card design system** for consistent UX

### **Power User Features**
- **Easy tool setup** - Download FFmpeg and optional tools with one click
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
- **TMDB** - The Movie Database (comprehensive metadata)
- **OMDb** - IMDb data (alternative source)

---

## ❓ FAQ

### **Do I need to install FFmpeg?**
No manual installation needed! MyMeta has a built-in Setup dialog that downloads and configures FFmpeg with one click. Just go to Settings → Setup Tools → Download.

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

### **Version 1.6.0** - Current
- **One-click tool setup** - Download FFmpeg and optional tools with ease
- Portable tool storage in UserData folder
- No more bundled executables - smaller download size
- Rebranded to MyMeta
- Beautiful sidebar with soft glow
- Comprehensive UX improvements
- Enhanced button organization
- Full-width sidebar highlight

### **Version 1.5.4**
- Custom titlebar with window controls
- Accent color system (8 colors)
- Inline metadata editing always available
- Bulletproof embedding with FFmpeg caching
- Settings & Formats page redesign

### **Version 1.5.0**
- Initial stable release
- TMDB & OMDb integration
- Cover art embedding
- Extended metadata support

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
- Flutter - Cross-platform framework
- FFmpeg - Media processing
- TMDB API - Movie/TV metadata
- OMDb API - IMDb data

**Special Thanks:**
- The Flutter team
- TMDB community
- FFmpeg developers

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
