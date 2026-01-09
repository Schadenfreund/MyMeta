# Changelog

All notable changes to MyMeta will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2026-01-09

### Added
- **Pre-Search Confirmation Modal** - When using "Search All Metadata", a modal now appears asking you to confirm or correct the TV Show/Movie name before searching. This prevents wrong matches and ensures accurate bulk metadata fetching.
- **Title Override Support** - All metadata search operations now support overriding the detected title, allowing for more accurate searches when filename parsing doesn't capture the correct name.
- **Smart Title Guessing** - The confirmation modal pre-fills with an intelligent guess based on the first file's name, stripping common patterns like season/episode markers, years, and quality indicators.

### Changed
- **Search All Metadata Workflow** - The bulk search feature now requires user confirmation of the series/movie name before proceeding, improving match accuracy.
- **MediaRecord Enhancement** - Added title override capability to the `MediaRecord.withOverrides` constructor for more flexible metadata searching.

## [1.0.3] - 2025-12-24

- **Auto-Update Feature** - Added "Software Updates" card in Settings that checks GitHub Releases for new versions

## [1.0.2] - 2025-12-24

### Fixed
- **Critical: Metadata Reading on Paths with Spaces** - Fixed FFprobe failing to read embedded metadata when project/file paths contain spaces (like "My Drive"). Changed `runInShell` from `true` to `false` to properly handle paths with spaces. Metadata now correctly persists after embedding and can be read on re-import.
- **Metadata Field Round-Tripping** - Fixed year, rating, and age rating not persisting after embedding. Added proper MKV tag mappings (`DATE_RELEASED`, `LAW_RATING`, `RATING`) so these fields correctly round-trip when writing and re-reading metadata.
- **Fix Match Modal Responsiveness** - Fixed laggy behavior when clicking Fix Match button. Modal now opens instantly and performs search in background with loading indicator, making the app feel much more responsive.
- **Fix Match Source Switching** - Fixed issue where changing metadata source in Fix Match modal wouldn't trigger new search. Modal now automatically searches when opened with no results and when source is changed.
- **Portable App Tool Path Validation** - Added startup validation that checks if saved tool paths are still valid after the app is moved. Automatically attempts to fix paths by searching `UserData/tools`. Clears invalid paths and provides detailed logging. Critical for portable app reliability.
- **Metadata Editor Field Updates** - Fixed inline metadata editor not reliably updating all fields when new metadata is fetched from online search. Now properly detects changes across all metadata fields (title, year, season, episode, description, genres, actors, rating, etc.) and updates the UI accordingly.
- **Fix Match Complete Metadata** - Fixed Fix Match modal not downloading cover art or generating formatted filenames when selecting an alternative match. Now properly completes metadata with cover download and applies user's naming format settings.
- **Search Results Race Conditions** - Fixed race conditions in the search results picker that could cause metadata fields to be lost or incorrectly saved. Refactored to use cleaner async flow with proper state management.
- **Cover Extraction Field Preservation** - Fixed background cover extraction losing metadata fields (like tmdbId, imdbId, searchResults, alternativePosterUrls) when updating match results with extracted cover bytes.

### Added
- **Auto-Update Feature** - Added "Software Updates" card in Settings that checks GitHub Releases for new versions
- **Update Service** - Complete auto-update implementation with progress tracking and UserData preservation during updates
- **Better Error Logging** - FFprobe errors now show stderr output for easier debugging
- **Startup Path Validation** - Tool paths validated on every app launch with auto-fix attempts
- **App Constants Module** - New centralized constants for metadata sources, HTTP configuration, image settings, and search limits
- **Safe Parser Utility** - Robust parsing for years, runtime, integers, doubles, and comma-separated lists with proper bounds checking
- **HTTP Client Wrapper** - Centralized API client with 15-second timeout, retry logic, and consistent error handling
- **MatchResult.copyWith()** - Safe method for copying MatchResult objects without losing fields

### Changed
- **Build Script** - Now automatically reads version from `pubspec.yaml` instead of hardcoded default
- **Tool Path Management** - More robust handling of tool paths for portable installations
- **TMDB Service Refactored** - Now uses centralized HTTP client with timeouts and safe parsing utilities
- **OMDB Service Refactored** - Now uses centralized HTTP client with timeouts and safe parsing utilities
- **AniDB Service Refactored** - Now uses centralized HTTP client with timeouts, extracted XML parsing into reusable method

### Improved
- **Code Quality** - Applied DRY principles throughout codebase with shared utilities
- **API Reliability** - All HTTP requests now have 15-second timeouts to prevent indefinite hangs
- **Year Parsing** - Robust year extraction that handles various date formats and validates range (1888-2100)
- **Error Handling** - Consistent null-safety patterns across all API services

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
