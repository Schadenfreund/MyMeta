# Changelog

All notable changes to MyMeta will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-12-24

### Fixed
- **Critical: Metadata Reading on Paths with Spaces** - Fixed FFprobe failing to read embedded metadata when project/file paths contain spaces (like "My Drive"). Changed `runInShell` from `true` to `false` to properly handle paths with spaces. Metadata now correctly persists after embedding and can be read on re-import.
- **Auto-Update System** - Configured GitHub repository information (Schadenfreund/MyMeta) for automatic update checks

### Added
- **Auto-Update Feature** - Added "Software Updates" card in Settings that checks GitHub Releases for new versions
- **Update Service** - Complete auto-update implementation with progress tracking and UserData preservation
- **Better Error Logging** - FFprobe errors now show stderr output for easier debugging

## [1.0.1] - 2025-12-24

### Added
- **Episode-Specific Descriptions**: All metadata sources (TMDB, OMDb, AniDB/MAL) now fetch and display episode-specific descriptions instead of series overviews
- **Season/Episode Override**: Edit season and episode numbers in metadata editor and re-search with corrected values - perfect for fixing wrong filename parsing or handling MAL's unique season numbering
- **Auto-Match Visual Indicators**: Files matched via "Search All Metadata" now show a 🔄 change icon instead of ☁️ cloud icon, making it easy to spot and fix incorrect auto-matches
- **Fix Match Modal Integration**: Click the 🔄 icon on auto-matched files to open Fix Match modal with all 10 search results for easy correction
- **Complete Fix Match Metadata**: All search results in Fix Match now have complete metadata (episode titles, descriptions, etc.) instead of just the first 3 results

### Fixed
- **Metadata Editor**: Fixed critical setState() during build errors that prevented typing more than one character in metadata fields
- **Excessive Save Calls**: Implemented pending save flag to prevent cascade of save operations when editing metadata
- **Episode Descriptions**: Fixed TV show episodes and anime showing series descriptions instead of episode-specific descriptions
- **AniDB/MAL Episode Details**: Now correctly fetches episode titles and descriptions from Jikan API for all anime results
- **TMDB Episode Descriptions**: Now uses episode details API to get episode-specific descriptions instead of series overview
- **Alternative Covers Button**: Renamed from "Browse Gallery" to "Alternative Covers" and shows helpful message when no covers are available instead of silent failure
- **Rate Limiting**: Removed restrictive rate limiting for search results to ensure Fix Match always has complete metadata

### Changed
- **Search All Workflow**: More transparent and user-friendly - auto-matched files visually indicated and easy to correct with one click
- **Icon Behavior**: Search icon (☁️) vs Fix Match icon (🔄) provides clear visual feedback on file matching source
- **UserData Management**: Better handling of episode override persistence across searches

### Improved
- **Metadata Completeness**: Centralized and robust metadata fetching ensures all fields are populated across all sources
- **User Experience**: More dynamic and intuitive interface that adapts based on user actions
- **Code Quality**: Cleaner, more maintainable code with better separation of concerns

## [1.0.0] - 2025-12-23

### Added
- Initial release of MyMeta
- **Multi-Source Metadata**: Search TMDB, OMDb, and AniDB for movies and TV shows
- **Bulk Operations**: Search All Metadata and Apply All for efficient batch processing
- **Inline Metadata Editor**: Edit all metadata fields inline with live preview
- **Cover Art Management**: Paste from clipboard, choose files, or browse alternative covers
- **External Tools Integration**: FFmpeg, mkvpropedit, and AtomicParsley support
- **Statistics Tracking**: Lifetime TV shows and movies matched
- **Customizable Appearance**: Accent color picker with 8 preset colors
- **Fix Match Modal**: Select different search results if auto-match is incorrect
- **Settings Persistence**: SQLite database for reliable settings storage
- **UserData Folder**: Centralized user data in AppData/Roaming folder

### Features
- Drag-and-drop file support
- File picker for manual file selection
- Real-time metadata preview
- Episode title fetching for TV shows
- Season and episode detection from filenames
- Smart filename parsing
- Cover art embedding for MKV and MP4 files
- Alternative poster selection
- Manual metadata editing
- Search result re-matching

### Technical
- Flutter Windows desktop application
- Material Design 3 theming
- Provider state management
- SQLite database
- Multi-threaded processing
- External process management
- HTTP client for API calls
- XML parsing for AniDB
- JSON parsing for TMDB/OMDb/Jikan

---

## Release Notes Format

### Added
New features and capabilities

### Fixed  
Bug fixes and corrections

### Changed
Changes to existing functionality

### Deprecated
Features marked for removal

### Removed
Features removed

### Security
Security-related changes
