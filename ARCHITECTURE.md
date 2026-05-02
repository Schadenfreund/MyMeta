# MyMeta - Architecture

Technical documentation for developers and contributors.

---

## Overview

MyMeta is a Flutter Windows desktop application for fetching, editing, and embedding metadata into video files. It follows a clean layered architecture with clear separation of concerns.

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Pages, Widgets, Modals)               │
├─────────────────────────────────────────┤
│          Business Logic Layer           │
│    (Services, State Management)         │
├─────────────────────────────────────────┤
│            Data Layer                   │
│  (Backend, API Services, SQLite, Utils) │
└─────────────────────────────────────────┘
```

---

## Project Structure

```
lib/
├── main.dart                          # Entry point — window setup, providers, theme
├── backend/
│   ├── core_backend.dart              # Metadata embedding, file ops, title formatting
│   ├── match_result.dart              # MatchResult model (metadata from API)
│   ├── media_record.dart              # MediaRecord model (per-file state)
│   └── filename_parser.dart           # Extracts series/episode info from filenames
├── constants/
│   └── app_constants.dart             # MetadataSource & ContentType enums, app-wide constants
├── pages/
│   ├── home_page.dart                 # Root layout — sidebar nav, tab management
│   ├── renamer_page.dart              # File list, match/rename workflow UI
│   ├── formats_page.dart              # Naming template config + live preview
│   └── settings_page.dart            # API keys, tools, theme, updates
├── services/
│   ├── file_state_service.dart        # ChangeNotifier — file list, match/rename ops, undo
│   ├── settings_service.dart          # ChangeNotifier — persists settings to SQLite
│   ├── tmdb_service.dart              # TMDB API — movies & TV metadata
│   ├── omdb_service.dart              # OMDb API — IMDb-based metadata
│   ├── anidb_service.dart             # AniDB + Jikan API — anime metadata
│   ├── poster_cache_service.dart      # Downloads and caches cover art locally
│   ├── tool_downloader_service.dart   # Downloads FFmpeg, MKVToolNix, AtomicParsley
│   └── update_service.dart           # GitHub release check, download, and apply updates
├── theme/
│   └── app_theme.dart                 # MaterialTheme definitions, accent color helpers
├── utils/
│   ├── http_client.dart               # Shared HTTP client (15s timeout, retry)
│   ├── cover_extractor.dart           # Extracts embedded cover art from video files
│   ├── image_utils.dart               # Image resize via FFmpeg, format helpers
│   ├── safe_parser.dart               # Null-safe parse helpers (year, int, double, list)
│   ├── snackbar_helper.dart           # Centralized snackbar/toast notifications
│   └── windows_thumbnail.dart         # Windows shell thumbnail extraction
└── widgets/
    ├── app_card.dart                  # AppCard, AppCardHeader, AppSettingRow, AppLabeledInput
    ├── custom_titlebar.dart           # Custom window titlebar with min/max/close
    ├── inline_metadata_editor.dart    # Expandable per-file metadata editor
    ├── edit_metadata_dialog.dart      # Dialog-based metadata editor
    ├── cover_picker_modal.dart        # Cover art browse/search/select modal
    ├── collapsible_card.dart          # Accordion card container
    ├── accent_color_picker.dart       # 8-color accent picker widget
    ├── about_card.dart                # Version + credits card
    ├── tool_paths_card.dart           # FFmpeg/MKVToolNix/AtomicParsley path config
    └── update_check_card.dart         # Update availability banner + download UI
```

---

## Data Flow

### File Rename Workflow

```
User Action → FileStateService → CoreBackend → External Tool → File System
     ↓               ↓                ↓               ↓              ↓
  UI Event  →  Update State  →  Build Command  →  Execute  →  Update File
                    ↓                                                ↓
             Notify Listeners ←─────────────────────────────  Success/Error
                    ↓
              Rebuild UI
```

### Metadata Matching Flow

```
1. User adds files
   └→ FileStateService.addFiles()
       └→ FilenameParser extracts title, year, season, episode

2. User clicks Match
   └→ FileStateService.matchFiles()
       ├→ Query TMDB / OMDb / AniDB (via service layer)
       ├→ PosterCacheService downloads & caches cover art
       └→ Store MatchResult on MediaRecord

3. User clicks Apply / Rename
   └→ FileStateService.renameFiles()
       ├→ CoreBackend.generateFilename() — applies naming template
       ├→ CoreBackend.embedMetadata()
       │   ├→ AtomicParsley (MP4, if available)
       │   ├→ mkvpropedit (MKV, if available)
       │   └→ FFmpeg fallback
       └→ Rename file on disk, push to undo stack
```

---

## Core Components

### FileStateService

Central ChangeNotifier managing the file list and all batch operations.

**State:**
```dart
List<MediaRecord> _files
bool _isLoading
bool _metadataOnlyMode
List<UndoData> _undoStack
```

**Key methods:** `addFiles()`, `matchFiles()`, `renameFiles()`, `undo()`, `clearAll()`

### SettingsService
ChangeNotifier that persists all user settings to a **SQLite** database via `sqflite_common_ffi`. The database lives in `UserData/` (AppData/Roaming).

**Settings managed:** theme mode, accent color, API keys (TMDB/OMDb/AniDB), metadata provider, naming templates, tool paths (FFmpeg/mkvpropedit/AtomicParsley), excluded folders, number-padding digits, metadata-only mode.

On startup, saved tool paths are validated and auto-corrected if the app has been moved (portable app support).

### CoreBackend

Handles metadata embedding and filename generation.

**Embedding priority per format:**

- MP4: AtomicParsley → FFmpeg fallback
- MKV: mkvpropedit (XML tags + cover attachment) → FFmpeg fallback

**Filename generation** uses template substitution (`{movie_name}`, `{year}`, `{series_name}`, `{season_number}`, `{episode_number}`, `{episode_title}`) with configurable digit padding for season/episode numbers.

**FFmpeg path resolution:** `UserData/tools/ffmpeg/` → app directory → system PATH, cached for the session.

### API Services
Each service uses the shared `HttpClient` (15-second timeout, retry logic).

| Service       | Source         | Format    |
|---------------|----------------|-----------|
| `TmdbService` | themoviedb.org | JSON      |
| `OmdbService` | omdbapi.com    | JSON      |
| `AnidbService`| AniDB + Jikan  | XML + JSON|

All services support title overrides and episode-specific metadata (description, title).

### PosterCacheService

Downloads cover art from TMDB/OMDb URLs, resizes via FFmpeg (if available), and stores locally in `UserData/cache/`. Falls back to caching the original download when FFmpeg resize is unavailable.

### UpdateService

Checks the GitHub Releases API for new versions. Downloads the release ZIP into `UserData/Updates/`, extracts it, and applies the update via a hidden PowerShell script that waits for the app to close before replacing files. `UserData/` is preserved across updates.

---

## UI Architecture

### State Management
Provider pattern — two root ChangeNotifiers injected at app startup:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsService()),
    ChangeNotifierProvider(create: (_) => FileStateService()),
  ],
  child: MyApp(),
)
```

Widgets subscribe with `context.watch<T>()` or read once with `context.read<T>()`.

### Centralized Card System (`app_card.dart`)

All settings-style UI is built from these composable components:

- **`AppCard`** — titled card container with icon and optional description
- **`AppCardHeader`** — icon + bold title + grey description on one line
- **`AppSettingRow`** — label/description on the left, control widget on the right
- **`AppLabeledInput`** — inline label + text input field

Always use these components for new settings UI. Do not introduce one-off styled containers.

### Custom Titlebar
Replaces the OS titlebar. Handles drag-to-move, double-click maximize, and min/max/close buttons. Theme-aware.

### Sidebar Navigation
Auto-hide vertical sidebar. Icons + labels, accent-color highlight, soft glow on active tab. Tabs: Renamer, Formats, Settings.

---

## External Tools

Tools are **not bundled** — they are downloaded by the user via Settings → Setup Tools and stored in `UserData/tools/`.

| Tool                     | Purpose                                | Speed vs FFmpeg |
|--------------------------|----------------------------------------|-----------------|
| FFmpeg                   | Metadata embedding fallback (required) | baseline        |
| AtomicParsley            | Fast MP4 metadata embedding            | ~60–120× faster |
| MKVToolNix (mkvpropedit) | Fast MKV metadata embedding            | ~60–120× faster |

---

## External Dependencies

**UI & Platform:**

- `window_manager` — custom titlebar and window control
- `provider` — state management
- `flutter_markdown` — markdown rendering

**File Handling:**

- `file_picker` — file selection dialog
- `desktop_drop` — drag-and-drop
- `path` / `path_provider` — path manipulation and platform directories

**Storage:**

- `sqflite_common_ffi` + `sqlite3_flutter_libs` — SQLite for settings persistence

**Networking:**

- `http` — TMDB/OMDb/AniDB API requests
- `dio` — update download with progress tracking
- `url_launcher` — open URLs in browser

**Data Processing:**

- `xml` — AniDB XML parsing
- `archive` — ZIP extraction for updates
- `package_info_plus` — read app version at runtime

---

## Security & Privacy

- API keys stored locally in SQLite, never hardcoded
- All processing happens on-device; only metadata queries leave the machine
- Network requests go only to TMDB, OMDb, AniDB, and GitHub Releases
- No telemetry or analytics

---

## Performance

- **Codec copy** (`-c copy`) — FFmpeg embeds metadata without re-encoding; no quality loss
- **Parallel fetching** — `Future.wait()` for concurrent metadata requests
- **FFmpeg path cached** — discovered once per session
- **Poster cache** — avoids re-downloading the same cover art

---

## Build & Distribution

```bash
# Development
flutter run -d windows

# Release
flutter build windows --release
```

The portable distribution is a flat folder (no installer):
```
MyMeta-v1.x.x/
├── MyMeta.exe
├── flutter_windows.dll
└── data/
```

`UserData/` (AppData/Roaming/MyMeta) contains all user data: settings DB, tool binaries, poster cache, update downloads. It is preserved across updates and app moves.

---

## Code Style

- Classes: `PascalCase` | Files: `snake_case.dart` | Variables: `camelCase`
- One widget/service per file; small private helpers may live alongside their parent
- Use `AppCard` and its sub-components for all settings-style UI
- Use `HttpClient` wrapper for all external HTTP calls
- Use `SafeParser` utilities for untrusted/nullable external data
- DRY: extract repeated logic into shared utils; do not duplicate embedding or parsing code
- No comments unless the *why* is non-obvious from the code itself

---

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [TMDB API Docs](https://developers.themoviedb.org/3)
- [OMDb API Docs](http://www.omdbapi.com/)
- [AniDB API Docs](https://wiki.anidb.net/API)
