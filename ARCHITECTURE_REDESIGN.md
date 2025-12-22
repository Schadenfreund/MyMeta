# MyMeta - Clean Architecture Redesign

## Current Problems

1. **Confusing flow** - Actions are mixed up and automatic
2. **Rename ≠ Metadata** - These are coupled but should be separate
3. **Automatic actions** - Things happen without user clicking (confusing)
4. **Too many buttons** - Search, save, rename, apply... what does each do?
5. **No preview** - User doesn't know what will be written until it's done

---

## Proposed Clean Architecture

### Core Principle: **Explicit User Actions**

Nothing modifies files automatically. User must explicitly click to change anything.

---

## 3 Clear Stages

### Stage 1: IMPORT (Read Only)
**What happens:**
- Read filename and path
- Parse filename for hints (series pattern: S01E02, year, etc.)
- Read existing embedded metadata (FFprobe)
- Extract existing cover art from file
- Detect if likely Movie or TV Show

**What does NOT happen:**
- ❌ No online searches
- ❌ No file modifications
- ❌ No downloads

**User sees:**
- File card with current info
- Existing metadata pre-filled
- Existing cover (if any)
- Type indicator (Movie/TV Show guess)

---

### Stage 2: SEARCH (User Triggered)
**When:** User clicks 🔍 search icon on a card

**What happens:**
- Search TMDB/OMDB using title/year hints
- Download cover thumbnails (to memory, not file)
- Present search results dropdown
- User selects best match (or keeps current)

**What does NOT happen:**
- ❌ No file modifications yet
- ❌ No renaming

**User sees:**
- Search results popup
- Can select different result
- Preview of new metadata
- Preview of new cover

---

### Stage 3: APPLY (User Triggered)
**When:** User clicks ✓ apply/save button

**What happens:**
- Write ALL metadata to file (title, year, description, cover, etc.)
- Optionally rename file (based on format template)
- Show success/failure feedback

**This is the ONLY point where files are modified!**

---

## Simplified UI Design

### File Card (Collapsed)
```
┌─────────────────────────────────────────────────────────────┐
│ [Cover]  Title: Pluribus S01E02               🔍  ✓  ✕     │
│          Type: TV Show | Year: 2025                         │
│          Status: Ready to Apply                             │
└─────────────────────────────────────────────────────────────┘

🔍 = Search online for metadata
✓ = Apply changes to file
✕ = Remove from list
```

### File Card (Expanded - Click to expand)
```
┌─────────────────────────────────────────────────────────────┐
│ [Cover]  Title: [___Pluribus_______________]                │
│          Year:  [___2025___]                                │
│          Type:  (•) Movie  ( ) TV Show                      │
│                                                             │
│ [TV Show Fields - only if TV Show selected]                 │
│          Season:  [___1___]                                 │
│          Episode: [___2___]                                 │
│          Episode Title: [___Pirate Lady___]                 │
│                                                             │
│ Description:                                                │
│ [________________________________________________]          │
│ [________________________________________________]          │
│                                                             │
│ Genres: [___Drama, Sci-Fi___]                               │
│ Director: [________________]                                │
│ Actors: [___________________]                               │
│                                                             │
│ [Preview New Filename: Pluribus - S01E02 - Pirate Lady.mkv] │
│                                                             │
│              [ Cancel ]  [ Apply to File ]                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Action Button Clarity

| Button | Icon | What it does |
|--------|------|--------------|
| Search | 🔍 | Search online, preview results, select match |
| Apply | ✓ | Write metadata to file, optionally rename |
| Remove | ✕ | Remove from list (no file changes) |
| Expand | Click card | Show/edit all metadata fields |

---

## Filename vs Metadata - SEPARATE!

### Options in Settings:
- [x] Apply metadata when clicking ✓
- [x] Rename file when clicking ✓
- Movie format: `{title} ({year})`
- TV format: `{show} - S{season}E{episode} - {episodeTitle}`

### Or separate buttons:
- "Apply Metadata" = Write metadata only, keep filename
- "Rename & Apply" = Write metadata AND rename file

---

## Detection Logic (Cleaner)

### On Import:
```
1. Parse filename:
   - Look for S##E## or ##x## patterns → TV Show
   - Look for (YYYY) year pattern → Movie likely
   - Look for known series keywords → TV Show
   
2. If embedded metadata exists:
   - Has SEASON/EPISODE tags → TV Show
   - Has "Movie" content type → Movie
   
3. Set initial type based on best guess
4. User can always override
```

### Type affects:
- Which fields are shown (Season/Episode only for TV)
- Filename template used
- Search query construction

---

## Implementation Phases

### Phase 1: Clean up existing code
- Remove automatic actions
- Make search explicit (click only)
- Make apply explicit (click only)

### Phase 2: Simplify UI
- Reduce button confusion
- Clear action labels
- Preview before apply

### Phase 3: Separate concerns
- Rename is optional (checkbox)
- Metadata embed always happens on Apply
- Type detection is just a hint, user can change

---

## Technical Changes Needed

### 1. FileStateService
- `importFile()` - Read only, no side effects
- `searchMetadata(index)` - Search, store results, no file changes
- `applyMetadata(index, options)` - Write to file, optionally rename

### 2. CoreBackend
- `readMetadata(path)` - Read existing from file
- `searchOnline(title, year, type)` - Search TMDB/OMDB
- `writeMetadata(path, metadata, cover)` - Write to file
- `renameFile(oldPath, newName)` - Rename only

### 3. InlineMetadataEditor
- Show all fields
- Preview filename change
- Single "Apply" button
- Cancel discards changes

---

## Summary

**Before (Confusing):**
- Import → Auto-search → Auto-rename → ??? 
- Multiple save/rename buttons
- Can't tell what clicking will do

**After (Clear):**
- Import = Just read
- Search = Find online (user clicks)
- Apply = Write to file (user clicks)
- Everything explicit, nothing automatic

This makes the app predictable and easy to understand!
