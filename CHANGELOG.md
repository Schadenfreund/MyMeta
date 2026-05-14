# Changelog

All notable changes to MyMeta will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.7] - 2026-05-14

### Added

- **Season Covers** — New toolbar button (photo album icon) opens a Season Covers dialog when TV episode files are loaded. Files are grouped by series + season. Each row shows the current cover thumbnail, an Auto button that fetches the season-specific poster from TMDB (falling back to the show-level poster), a Search button that opens the full cover picker, and a Custom button to pick a local image file. A Season / Show toggle switches whether Auto and Search look for season-specific or show-level posters. Confirming applies the chosen cover bytes to every episode in each group.

### Fixed

- **Statistics Not Counting** — TV Shows Matched and Movies Matched counters in the Settings tab were only incremented when using the per-row apply button. Using Apply All or the inline metadata editor's rename action no longer silently skips the counters.

## [1.1.6] - 2026-05-14

### Added

- **Provider Selection in Cover Art Modal** — The "Select Cover Art" gallery modal now includes the same provider dropdown (TMDB / OMDb / AniDB) found in the other search modals. TMDB returns a full poster gallery; OMDb and AniDB return the poster image from each search result. Defaults to the last-used metadata source and auto-searches when the provider is changed.
- **Grouped Titles in Search All Metadata** — Files with the same parsed title are now grouped under a single shared text field instead of showing one field per file. Editing the shared field updates the search query for the whole group. Expanding a group reveals per-file overrides (seeded from the shared value) for cases where individual files need different titles. A badge shows the file count per group.

### Changed

- **Modal Style Consistency** — Full pass across all three search/picker modals (Select Cover Art, Select Match, Search All Metadata): unified close-button sizing, consistent header/search-bar layout, and matching separator treatment between sections.

## [1.1.5] - 2026-05-02

### Added

- **Three Independent Apply Toggles** — Replaced the single Metadata-Only toggle with three separate persistent buttons in the renamer toolbar: Rename, Update Cover, and Embed Metadata Fields. Each can be toggled independently and persists across sessions. Migrates automatically from the old setting.
- **Remove All Covers Before Embed** — New toggle in Settings → Metadata Source (MKV only). When enabled, all image attachments are stripped by MIME type before adding the new cover — useful when existing covers have non-standard filenames. When disabled, only attachments named `cover*` are removed.

### Fixed

- **MKV Metadata Missing After First Apply** — On some MKV files, only the Title showed up in MediaInfo after applying; all other fields required a second Apply to appear. Fixed by combining all mkvpropedit writes into a single call so the file index is rebuilt correctly in one pass.
- **Duplicate Covers on MKV Files** — Existing cover attachments with uppercase names like `Cover.jpg` were not detected and removed, leaving two covers in the file after embed. Cover name matching is now case-insensitive.
- **Unnecessary File Rewrite When Nothing to Embed** — With both Update Cover and Embed Metadata Fields disabled, FFmpeg was still invoked as a fallback and rewrote the entire file. FFmpeg is now skipped when there is nothing to do.

- **Software Update Not Applying** — Pressing "Restart Now to Update" would close the app but the update was never installed. The PowerShell update script was silently blocked by Windows execution policy on launch. Fixed by adding `-ExecutionPolicy Bypass` and switching from `-Command "& 'script'"` to `-File script` for more robust path handling.

## [1.1.2] - 2026-04-04

### Fixed

- **Update Process Robustness** — Rewrote the auto-update script from CMD batch to hidden PowerShell, eliminating visible console windows during updates. Process detection now uses `Get-Process` instead of `tasklist | find` (which spawned visible subprocesses). Added a 60-second timeout on process wait to prevent hangs.
- **DRY Update Code** — Consolidated duplicated update-launch logic in the UI into a single `launchUpdateScript()` method in UpdateService. GitHub release URLs are now centralized as static getters instead of being constructed inline in multiple places.

## [1.1.1] - 2026-04-04

### Added

- **Search Bar in Fix Match & Gallery Modals** — Both the Fix Match (search results) and Cover Gallery modals now include a search text field. You can type any title to search for different matches or poster art directly from within the modal, matching the main search modal's UX. The gallery modal no longer requires pre-fetched alternatives — it always opens and lets you search TMDB for posters.

### Fixed

- **Cover Art Embedding** — Fixed covers not being embedded into media files despite being visible in the UI. The poster cache service now falls back to caching the original download when FFmpeg resize is unavailable, instead of discarding the downloaded poster entirely.
- **FFmpeg Discovery for Poster Resize** — `ImageUtils` now checks `UserData/tools/ffmpeg/` (the recommended portable location) in addition to the app directory and system PATH.
- **Cover Fallback Chain** — If in-memory cover bytes fail to write to disk, the poster URL download fallback now properly kicks in instead of being skipped.

## [1.1.0] - 2026-04-04

### Fixed

- **Software Updates** — The auto-update feature now works reliably. Replaced PowerShell script with a CMD batch script (avoids execution policy blocks), switched to `robocopy` for file copying with retry logic, and added logging for easier troubleshooting. Old covers and stale files in the app directory are properly replaced while `UserData/` (settings, tools, database) is preserved.

### Added

- **Persistent Update Downloads** — Updates are now downloaded into `UserData/Updates/` instead of the system temp directory. Clicking "Restart Later" keeps the download; on next launch the Settings card shows a "Restart Now to Update" banner so you can apply it without re-downloading.

### Changed

- **ZIP Extraction Hardening** — Normalized path separators when extracting release archives, preventing failures when the ZIP was created on Windows with backslash entries.

## [1.0.9] - 2026-04-04

### Fixed

- **TV Show Metadata Embedding** — Fixed an issue where TV show episodes would only embed the title and video track name while all other metadata (Description, Genre, Actors, Rating, Season/Episode numbers) was missing. The MKV embedding function returned success unconditionally even when XML tag writing failed, preventing the FFmpeg fallback from triggering. Also hardened the XML escaping to handle quotes and apostrophes in metadata values that could produce invalid XML.
- **Number Padding in MP4/FFmpeg** — The MP4 (AtomicParsley) and FFmpeg embedding paths were using hardcoded 2-digit padding instead of the user's configured season/episode digit settings.

## [1.0.8] - 2026-04-03

### Added

- **Folder Drag-and-Drop** — Dropping a folder (or multiple folders) now scans recursively for video files inside instead of trying to rename the folder itself. Supports `.mp4`, `.mkv`, `.avi`, `.mov`, `.m4v`, `.wmv`, `.flv`, `.ts`, `.m2ts`, `.webm`, `.mpg`, `.mpeg`.
- **Metadata-Only Mode** — New toggle button in the renamer toolbar. When active, clicking Apply embeds metadata into files without renaming them. Useful for bulk-updating embedded Genre/tags in an existing collection (e.g. fixing Plex library views) while keeping filenames untouched. Setting persists across sessions.
- **Configurable Number Padding** — You can now choose how many digits to use for season and episode numbers: episode 2/3/4 digits (`E01` / `E001` / `E0001`), season 2/3 digits (`S01` / `S001`). Live preview updates instantly.

### Fixed

- **Episode Parsing Bug** — Regex `\d{1,2}` was truncating 3-digit episode numbers (e.g. `E001` parsed as episode `00` instead of `1`). Changed to `\d+` to capture any digit count correctly.
- **TMDB Search Crash on Certain Shows** — TMDB occasionally returns an empty string for `first_air_date` rather than `null`. Calling `.substring(0, 4)` on an empty string threw `RangeError (end): Invalid value: Only valid value is 0: 4`, crashing the search and showing "No results found". Fixed with a proper length guard.
- **Season 0 / Specials Fallback** — Shows that list their first episode under Season 0 (Specials) on TMDB — such as *One Piece (2023)*, *Solo Leveling*, and *Fallout* — now match correctly for Episode 1. The app retries with Season 0 before skipping a result, so S01E01 searches succeed even when TMDB stores the episode as S00E01.

### Changed

- **Unified Search Modal** — The per-file search button and Fix Match modal have been merged into a single "Select Match" dialog with a search text field. Users can now type a custom search query and pick from results, regardless of whether the file was auto-matched. The inline metadata editor's search button also opens the same modal.
- **Formats Page** — The standalone "Number Padding" card has been folded into the TV Series Format card as a compact inline row, reducing clutter. The preview now reflects the actual padding settings.

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
