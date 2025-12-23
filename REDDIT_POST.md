## REDDIT POST TEMPLATE - MyMeta v1.0.0

---

### TITLE OPTIONS (pick one):

1. **MyMeta v1.0.0 - Free Media File Metadata Manager with Auto-Embedding (Windows)**
2. **[Release] MyMeta - Automatically fetch & embed metadata into your media files (Free, MIT Licensed)**
3. **I built a free tool to organize media files with embedded metadata (TMDB/OMDb/AniDB)**

---

### POST BODY:

```markdown
I built a free, open-source tool to automatically fetch and embed metadata into your media files!

## What is MyMeta?

MyMeta automatically fetches metadata from **TMDB**, **OMDb**, and **AniDB**, then embeds it directly into your MP4/MKV files along with cover art. Perfect for organizing media libraries for Plex, Jellyfin, or Kodi.

## ✨ Key Features

**Metadata Sources:**
• TMDB - Comprehensive movie & TV show data
• OMDb - IMDb-based alternative
• AniDB - Specialized anime database

**Smart Processing:**
• Automatic cover art embedding (MP4 & MKV)
• Batch processing support
• Customizable naming templates
• Season/episode detection for TV shows
• Inline metadata editing

**Zero Setup:**
• Portable - no installation needed
• One-click tool downloads (FFmpeg, MKVToolNix, AtomicParsley)
• 60-120x faster processing with specialized tools
• 8 accent color themes

## 🎯 Use Cases

**Media Server Preparation:**
```
messy_file.mp4  →  Inception (2010).mp4
```
Complete with embedded title, year, description, genres, cast, rating, and cover art!

**TV Show Organization:**
```
show.s01e01.mkv  →  Breaking Bad - S01E01 - Pilot.mkv
```
With full episode metadata embedded!

## 📦 What's Inside

- **Windows 10/11** (64-bit)
- **21.90 MB** download
- **MIT Licensed** - completely free & open source
- **Zero lint errors** - production-ready code

## 🔧 Technical Details

**Tools Used:**
• FFmpeg (required) - Core metadata embedding
• MKVToolNix (optional) - 60-120x faster MKV processing
• AtomicParsley (optional) - 60-120x faster MP4 processing

All tools download automatically on first launch!

**Supported Formats:**
• MP4 - Full metadata + cover art
• MKV - Full metadata + cover art

## 📥 Download

**GitHub Release:** [Add your release link]  
**Source Code:** [Add your repo link]

## 💝 Support

The app is completely free! If you find it useful, there's an optional support button in settings.

## 📸 Screenshots

[Add 2-3 screenshots showing:
1. Main interface with files loaded
2. Metadata editing panel
3. Settings page with accent colors]

---

Made with ❤️ for the data hoarding community!
```

---

### RECOMMENDED SUBREDDITS & POSTING STRATEGY:

1. **r/DataHoarder** (PRIMARY AUDIENCE)
   - Best day: Tuesday-Thursday
   - Best time: 10-14:00 EST
   - Focus: File organization, metadata management
   - Expected reception: Very positive

2. **r/PleX**
   - Focus: "Perfect for preparing files for Plex"
   - Mention: "Embedded metadata = better Plex matching"

3. **r/jellyfin** 
   - Similar to Plex angle
   - Emphasize: Free & open-source (matches Jellyfin philosophy)

4. **r/software**
   - More general audience
   - Focus: Free, MIT licensed, well-documented

5. **r/windows**
   - Emphasize: Modern Windows app, beautiful UI
   - Mention: Native Windows integration

---

### POSTING TIPS:

✅ **DO:**
- Post between 10AM-2PM EST on weekdays
- Respond to questions quickly (first 2 hours crucial)
- Include screenshots in post
- Mention it's free & open-source immediately
- Be humble and receptive to feedback

❌ **DON'T:**
- Post on weekends (lower engagement)
- Be defensive about criticism
- Over-promote the donation link
- Cross-post to all subs at once (stagger by 1-2 days)
- Edit post too much after posting

---

### EXPECTED QUESTIONS & ANSWERS:

**Q: "Why not just use FileBot?"**
A: FileBot requires a license ($6/year). MyMeta is completely free and MIT licensed. Plus, I wanted native cover art embedding and modern UI.

**Q: "Does this work on Linux/Mac?"**
A: Currently Windows only (v1.0.0), but it's built with Flutter so cross-platform support is planned for future releases.

**Q: "How is this different from Sonarr/Radarr?"**
A: Sonarr/Radarr are for automation/downloads. MyMeta is for organizing existing files and embedding metadata. They complement each other!

**Q: "Is my API key safe?"**
A: Yes! API keys are stored locally on your machine, encrypted, and never sent anywhere except to TMDB/OMDb/AniDB for metadata requests.

**Q: "What about privacy?"**
A: All processing is local. Only metadata queries go to external APIs. No telemetry, no tracking, no data collection.

**Q: "Can I modify and sell this?"**
A: Yes, it's MIT licensed. The only requirement is keeping the copyright notice. Though I hope you'll contribute improvements back to the community instead!

---

### FOLLOW-UP ACTIONS:

After posting:
1. Monitor for first 2-3 hours
2. Answer all questions promptly
3. Thank people for feedback
4. Note feature requests
5. Fix any critical bugs immediately
6. Update README with common questions

---

### SUCCESS METRICS:

Good response:
- 50+ upvotes
- 10+ comments
- 5+ GitHub stars

Great response:
- 200+ upvotes
- 50+ comments
- 20+ GitHub stars

Viral response:
- 1000+ upvotes
- 100+ comments
- 100+ GitHub stars

---

Good luck with your launch! 🚀
