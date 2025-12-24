# MyMeta - Quick Start Guide

Get up and running with MyMeta in 5 minutes!

---

## 📦 Installation

### **Step 1: Download**
Download the latest MyMeta release (ZIP file).

### **Step 2: Extract**
Extract the ZIP to any folder on your computer.

### **Step 3: Run**
Double-click `MyMeta.exe` - that's it! No installation wizard, no setup.

---

## 🔑 Initial Setup

### **Getting Your API Keys**

MyMeta needs API keys to fetch metadata. Both are **free** and take 2 minutes to set up:

#### **TMDB API Key** (Recommended)
1. Go to [themoviedb.org](https://www.themoviedb.org/)
2. Create a free account
3. Go to Settings → API → Create → Choose "Developer"
4. Fill in required fields (any website works, e.g., "Personal Use")
5. Copy the **API Key (v3 auth)**

#### **OMDb API Key** (Alternative)
1. Go to [omdbapi.com/apikey.aspx](http://www.omdbapi.com/apikey.aspx)
2. Enter your email
3. Choose "FREE" tier (1,000 requests/day)
4. Check your email for the API key

#### **AniDB Client ID** (Optional - For Anime)

AniDB is perfect for anime metadata. Setup takes 5 minutes:

1. **Create AniDB Account**
   - Go to [anidb.net](https://anidb.net)
   - Create a free account and log in

2. **Register API Client**
   - Visit [http://anidb.net/perl-bin/animedb.pl?show=client](http://anidb.net/perl-bin/animedb.pl?show=client)
   - Click **"Add New Project"**
   - Give your project any name (e.g., "MyMeta")
   - Other fields don't matter - just fill them in

3. **Create API Version**
   - Inside your project, click **"Add New Version"**
   - Enter a version name (e.g., "mymeta" or "client1")
   - Set version number to **1**
   - **Important:** The version name = your "Client ID"

4. **Add to MyMeta**
   - In MyMeta Settings, paste the **version name** as "AniDB Client ID"
   - Leave version at 1 (or use what you set)

**Note:** AniDB has rate limits (2 requests/second). MyMeta handles this automatically.

**Bonus:** MyMeta also uses Jikan (MyAnimeList) for anime search, which works without any API key!


### **Adding Keys to MyMeta**
1. Open MyMeta
2. Click the **Settings** tab (gear icon in sidebar)
3. Paste your API key(s) in the appropriate fields
4. Keys are saved automatically

---

## 🎬 Your First Rename

### **Example: Renaming a Movie**

#### **1. Add the File**
- Click **"Add Files"** button, OR
- Drag & drop your video file into MyMeta

Example file: `random_movie_2010.mp4`

#### **2. Match Metadata**
- Click **"Match"** button
- MyMeta searches TMDB/OM Db for your file
- Metadata and cover art are fetched automatically

#### **3. Review (Optional)**
- Click on the file to expand the metadata editor
- All fields are editable
- Make any corrections needed

#### **4. Rename**
- Click **"Rename Files"** button
- File is renamed AND metadata is embedded

**Result:**  
`random_movie_2010.mp4` → `Inception (2010).mp4`

Plus embedded:
- Title, year, description
- Genres, director, actors
- Cover art image
- Rating information

---

## 📺 Renaming TV Shows

### **Example: Breaking Bad Episode**

#### **Starting File**
`bb.s01e01.1080p.mkv`

#### **Steps**
1. Add file
2. Click Match
3. MyMeta detects:
   - Series: Breaking Bad
   - Season: 1
   - Episode: 1
   - Title: Pilot

4. Click Rename

#### **Result**
`Breaking Bad - S01E01 - Pilot.mkv`

With full metadata embedded!

---

## 🎨 Customizing MyMeta

### **Change Accent Color**
1. Settings tab
2. Scroll to "Accent Color"
3. Click any color circle
4. Entire app updates instantly!

### **Change Theme**
1. Settings tab
2. "Theme" dropdown
3. Choose Light or Dark

### **Custom Naming Formats**
1. Go to **Formats** tab
2. Modify the pattern

**Movie Format:**
```
{movie_name} ({year})
```

**TV Show Format:**
```
{series_name} - S{season_number}E{episode_number} - {episode_title}
```

**Available Tokens:**
- `{movie_name}` / `{series_name}`
- `{year}`
- `{season_number}` - Padded (01, 02, etc.)
- `{episode_number}` - Padded (01, 02, etc.)
- `{episode_title}`

---

## 🔄 Typical Workflow

```
1. Add Files
   ├─ Click "Add Files" button
   └─ Or drag & drop into window

2. Match Metadata
   ├─ Click "Match" button
   ├─ Wait for API response (1-3 seconds)
   └─ Review fetched data

3. Edit (Optional)
   ├─ Click any file to expand
   ├─ Modify any field
   └─ Changes saved automatically

4. Rename Files
   ├─ Click "Rename Files" button
   ├─ Metadata embedded into files
   └─ Files renamed with new names

5. Clean Up
   ├─ Click "Clear Finished" to remove done files
   └─ Or "Clear All" to start fresh
```

---

## 💡 Tips & Tricks

### **Batch Processing**
- Add multiple files at once
- Match all files with one click
- Rename all in one operation

### **Inline Editing**
- Click any file (before or after match)
- Edit metadata directly
- No need for separate dialog

### **Undo Support**
- Made a mistake? Click "Undo"
- Reverts last rename operation
- Files restored to original names

### **Folder Exclusions**
Exclude parent folders to improve matching:
1. Settings tab
2. "Folder Exclusions" section
3. Add folders like "Movies", "TV Shows", etc.

These folders are ignored during filename parsing.

---

## 🎯 Common Tasks

### **Organizing a Movie Collection**
```
1. Add all movie files
2. Click Match (fetches all metadata)
3. Review any questionable matches
4. Click Rename Files
5. Click Clear Finished
```

### **Processing a TV Season**
```
1. Add all episode files
2. Match (MyMeta detects S01E01, S01E02, etc.)
3. Verify episode titles are correct
4. Rename Files
5. Episodes now properly named!
```

### **Fixing a Bad Match**
```
1. Click the file to expand
2. Edit the metadata fields
3. Correct title, year, or season/episode
4. Click Rename Files
5. Metadata embedded with corrections
```

---

## ⚙️ Settings Explained

### **Theme**
- **Light:** Clean, bright interface
- **Dark:** Easy on the eyes

### **Accent Color**
Your personal touch - changes:
- Selected sidebar tab
- Primary buttons
- Focus borders
- Active elements

### **Metadata Source**
- **TMDB:** Most comprehensive, includes crew info and extensive TV show data
- **OMDb:** Alternative, IMDb-based data
- **AniDB:** Specialized database for anime content

### **API Keys**
- Required for metadata fetching
- Stored locally (encrypted)
- Never shared

### **Folder Exclusions**
Parent folders to ignore during parsing:
- "Movies"
- "TV Shows"
- "Media"
- etc.

Helps MyMeta focus on the actual filename.

---

## 🔍 Understanding Metadata

### **What Gets Embedded?**

**Basic Info:**
- Title
- Year
- Description/Plot

**Extended:**
- Genres (Action, Drama, etc.)
- Director
- Actors/Cast
- Rating (8.5/10)
- Content Rating (PG-13, R, etc.)
- Runtime

**Visual:**
- Cover Art (poster image)

### **Where Can I See It?**

**In File Properties:**
- Right-click file → Properties → Details tab
- Shows embedded metadata

**In Media Players:**
- VLC: Tools → Media Information
- Windows Media Player: Library view
- Plex/Jellyfin: Automatic recognition

**With FFprobe:**
```powershell
ffprobe your_file.mp4 2>&1 | Select-String "title"
```

---

## ❗ Troubleshooting

### **"FFmpeg not found" or Slow Processing**
- Go to Settings → Setup Tools
- Click "Download" for FFmpeg (required)
- Optionally download MKVToolNix and AtomicParsley for 60-120x faster processing
- Tools are automatically configured after download

### **No matches found**
- Check internet connection
- Verify API key is correct
- Try alternative provider (TMDB ↔ OMDb)
- Manually edit filename for better matching

### **Wrong match**
- Click file to expand editor
- Manually correct the metadata
- OR search with more specific filename

### **Cover art not showing**
- Only works with MP4 and MKV files
- Check if cover was downloaded (console output)
- Some players don't show embedded covers

### **Can't rename file**
- File might be in use (close media player)
- Check file permissions
- Run MyMeta as administrator if needed

---

## 🚀 Advanced Usage

### **Custom Formats**
Create your own naming patterns:

**Example - Year First:**
```
({year}) {movie_name}
→ (2010) Inception.mp4
```

**Example - Detailed TV:**
```
{series_name} S{season_number}E{episode_number} ({year}) - {episode_title}
→ Game of Thrones S01E01 (2011) - Winter Is Coming.mkv
```

### **Keyboard Shortcuts** (Planned)
- `Ctrl+O` - Add files
- `Ctrl+M` - Match
- `Ctrl+R` - Rename
- `Ctrl+Z` - Undo

---

## 📚 Next Steps

Now that you're familiar with MyMeta:

1. **Organize your collection** - Start with a small batch first
2. **Customize colors** - Make it your own!
3. **Tweak formats** - Perfect for your naming style
4. **Check documentation:**
   - [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
   - [CHANGELOG.md](CHANGELOG.md) for updates and guidelines

**Version 1.0.0 - Production Release:**
- Zero-issue codebase with comprehensive quality checks
- Smart batch processing with metadata disambiguation
- Enhanced performance with specialized tools (60-120x faster)
- Modern Flutter 3.x+ APIs throughout
- Professional-grade code quality

---

## 💬 Getting Help

**Having issues?**
1. Check this guide
2. Review error messages in the console
3. Try alternative metadata provider
4. Restart MyMeta

**Still stuck?**
- Open an issue with details
- Include console output
- Describe steps to reproduce

---

<div align="center">

**Happy organizing!** 🎬

MyMeta makes media management effortless.

[Back to README](README.md) | [Architecture](ARCHITECTURE.md)

</div>
