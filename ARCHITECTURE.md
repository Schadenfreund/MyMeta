# MyMeta - Architecture

Technical documentation for developers and contributors.

---

## 🏗️ Architecture Overview

MyMeta is built with Flutter using a clean architecture pattern with clear separation of concerns.

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Pages, Widgets, UI Components)        │
├─────────────────────────────────────────┤
│          Business Logic Layer           │
│    (Services, State Management)         │
├─────────────────────────────────────────┤
│            Data Layer                   │
│  (Backend, API Clients, FFmpeg)         │
└─────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── backend/
│   ├── core_backend.dart     # FFmpeg operations, metadata embedding
│   ├── match_result.dart     # Metadata result models
│   └── media_record.dart     # Media record models
├── pages/
│   ├── home_page.dart        # Main layout with sidebar
│   ├── renamer_page.dart     # File management UI
│   ├── formats_page.dart     # Naming format configuration
│   └── settings_page.dart    # App settings
├── widgets/
│   ├── app_card.dart         # Centralized card components (NEW)
│   ├── custom_titlebar.dart  # Custom window controls
│   ├── accent_color_picker.dart  # Color selection widget
│   ├── about_card.dart       # About information card
│   ├── tool_paths_card.dart  # Tool configuration card
│   └── inline_metadata_editor.dart  # Metadata editing UI
├── services/
│   ├── file_state_service.dart      # File list state management
│   ├── settings_service.dart        # App settings persistence
│   └── tool_downloader_service.dart # Tool download & setup
└── theme/
    └── app_theme.dart        # Centralized theme constants
```

---

## 🔄 Data Flow

### **File Rename Workflow**

```
User Action → State Service → Backend → FFmpeg → File System
     ↓            ↓              ↓         ↓          ↓
  UI Event → Update State → API Call → Process → Update File
                ↓                                      ↓
          Notify Listeners ←─────────────────── Success/Error
                ↓
          Update UI
```

### **Metadata Matching Flow**

```
1. User adds files
   └→ FileStateService.addFiles()

2. User clicks Match
   └→ FileStateService.matchFiles()
       ├→ Parse filename
       ├→ Query TMDB/OMDb API
       ├→ Download cover art
       └→ Store MatchResult

3. User clicks Rename
   └→ FileStateService.renameFiles()
       ├→ Generate new filename
       ├→ Call CoreBackend.embedMetadata()
       │   ├→ Build FFmpeg command
       │   ├→ Execute FFmpeg
       │   └→ Verify output
       └→ Update file state
```

---

## 🧩 Core Components

### **1. FileStateService**
**Purpose:** Manages file list state and operations

**Key Responsibilities:**
- Add/remove files from list
- Match metadata via API
- Execute rename operations
- Track undo history
- Notify UI of changes

**State:**
```dart
List<InputFileData> _inputFiles
List<MatchResult> _matchResults
List<UndoData> _undoStack
bool _isLoading
```

**Key Methods:**
- `addFiles(List<XFile>)` - Add files to list
- `matchFiles(SettingsService)` - Fetch metadata
- `renameFiles()` - Execute rename + embed
- `undo()` - Revert last operation
- `clearAll()` / `clearRenamedFiles()` - Cleanup

### **2. SettingsService**
**Purpose:** Persist and manage app settings

**Storage:** SharedPreferences (local key-value store)

**Settings Managed:**
- Theme mode (light/dark)
- Accent color
- API keys (TMDB, OMDb)
- Metadata provider preference
- Naming format templates
- Excluded folders list

**Persistence:**
```dart
await _prefs.setString(key, value)
value = _prefs.getString(key) ?? default
```

### **3. CoreBackend**
**Purpose:** FFmpeg integration and metadata embedding

**Key Features:**
- FFmpeg path detection (bundled → PATH)
- Metadata escaping for FFmpeg
- MP4 cover embedding (attached_pic)
- MKV cover attachment
- Command caching for performance

**Critical Methods:**

#### `embedMetadata(filePath, coverPath, metadata)`
```dart
1. Validate inputs
2. Check FFmpeg availability
3. Build FFmpeg command:
   - Set codec (copy)
   - Add cover art
   - Embed metadata fields
4. Execute FFmpeg
5. Verify temp output
6. Replace original file
7. Cleanup
```

#### `_checkFFmpegAvailable()`
```dart
1. Check bundled: app_dir/ffmpeg.exe
2. Fallback to PATH
3. Cache result
4. Return true/false
```

---

## 🎨 UI Architecture

### **Custom Titlebar**
Replaces system titlebar with custom implementation:
- Window dragging
- Minimize/Maximize/Close buttons
- Double-click to maximize
- Theme-aware styling

### **Sidebar Navigation**
Auto-hide vertical sidebar with:
- Tab selection
- Accent color highlight
- Soft glow effect
- Hover to reveal
- Icons + labels

### **Centralized Card Components** ⭐ NEW
Reusable UI components following DRY principles:

**AppCard** - Main card container
```dart
AppCard(
  title: 'Settings',
  icon: Icons.settings,
  description: 'Configure your preferences',
  accentColor: accentColor,
  children: [...],
)
```

**AppCardHeader** - Inline title + description
- Bold white title and grey description on same line
- Consistent spacing and alignment
- Accent color icon

**AppSettingRow** - Setting with inline labels
- Title and description inline (not stacked)
- Control widget on the right
- Baseline alignment for text

**AppLabeledInput** - Input with inline labels
- Label and description inline
- Input field below
- Consistent spacing

**Benefits:**
- ✅ DRY - Single source of truth
- ✅ Consistency - Uniform look across pages
- ✅ Maintainability - Easy to update globally
- ✅ Code reduction - ~168 lines saved

### **State Management**
Uses Provider pattern:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SettingsService()),
    ChangeNotifierProvider(create: (_) => FileStateService()),
  ],
  child: MyApp(),
)
```

UI widgets watch services:
```dart
final settings = context.watch<SettingsService>();
final fileState = context.watch<FileStateService>();
```

---

## 🔌 External Dependencies

### **Flutter Packages**

**UI & Platform:**
- `flutter` - Core framework
- `window_manager` - Custom titlebar
- `provider` - State management

**File Handling:**
- `file_picker` - File selection dialog
- `desktop_drop` - Drag & drop support
- `cross_file` - Cross-platform file abstraction
- `path` - Path manipulation

**Storage:**
- `shared_preferences` - Settings persistence

**HTTP:**
- `http` - API requests (TMDB, OMDb)

### **External Tools**

**FFmpeg** (Bundled)
- Version: Latest stable
- Purpose: Metadata embedding
- Location: `app_dir/ffmpeg.exe`
- Fallback: System PATH

---

## 🔐 Security & Privacy

### **API Keys**
- Stored in SharedPreferences (local)
- Never transmitted except to respective APIs
- User-provided (not hardcoded)

### **File Access**
- Only files user explicitly selects
- All processing local
- No file upload to external servers

### **Network Requests**
- Only to TMDB/OMDb APIs
- Only for metadata queries
- No telemetry or analytics

---

## 📊 Performance Optimizations

### **FFmpeg Caching**
```dart
static bool? _ffmpegAvailable;
static String? _ffmpegPath;
```
Checks FFmpeg once per session.

### **Lazy Loading**
UI only loads visible items in scrollable lists.

### **Async Operations**
All file I/O and network requests are async:
```dart
await Future.wait([
  _fetchMetadata(file1),
  _fetchMetadata(file2),
])
```

### **Codec Copy**
FFmpeg uses `-c copy` to avoid re-encoding:
- No quality loss
- 100x faster than re-encoding
- Minimal CPU usage

---

## 🧪 Testing Strategy

### **Manual Testing**
Test each workflow:
1. Add files → Match → Rename
2. Inline editing
3. Undo operation
4. Settings persistence
5. Theme switching
6. Format customization

### **Edge Cases**
- Large files (>20GB)
- Special characters in filenames
- Missing metadata
- Network failures
- File permissions

### **Platforms**
- Windows 10
- Windows 11

---

## 🚀 Build & Distribution

### **Development Build**
```bash
flutter run
```

### **Release Build**
```bash
flutter build windows --release
```

### **FFmpeg Bundling**
```powershell
.\bundle_ffmpeg.ps1
```

### **Distribution Package**
```
MyMeta-v1.6.0/
├── MyMeta.exe
├── ffmpeg.exe
├── flutter_windows.dll
└── data/
```

---

## 🔧 Development Setup

### **Prerequisites**
- Flutter SDK 3.0+
- Windows 10/11
- Visual Studio 2022 (C++ tools)
- Git

### **Clone & Setup**
```bash
git clone <repository>
cd mymeta
flutter pub get
```

### **Run**
```bash
flutter run -d windows
```

### **Build**
```bash
flutter build windows --release
.\bundle_ffmpeg.ps1
```

---

## 📝 Code Style

### **Naming Conventions**
- Classes: `PascalCase`
- Files: `snake_case.dart`
- Variables: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE`

### **File Organization**
- One widget per file (exception: small private helper widgets)
- Group related functionality
- Clear imports at top
- Reusable components in `widgets/` folder

### **State Management**
- Use Provider for app-wide state
- Local `setState` for widget-specific state
- Notify listeners on state changes

### **DRY Principles** ⭐ NEW
- **Don't Repeat Yourself** - Create reusable components
- Use centralized widgets (AppCard, AppCardHeader, etc.)
- Extract common patterns into shared components
- Single source of truth for styling and layout
- Understand the architecture before creating new patterns

### **Component Reusability**
- Use existing components from `widgets/app_card.dart`
- Follow established patterns for consistency
- Update existing components rather than creating duplicates
- Document new reusable components

---

## 🌟 Future Enhancements

### **Planned Features**
- Progress indicators during batch processing
- Parallel metadata fetching
- Preview before rename
- Keyboard shortcuts
- Watch folder automation
- Cross-platform (macOS, Linux)

### **Technical Debt**
- Add unit tests
- Implement error boundaries
- Add logging framework
- Improve error messages

---

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [TMDB API Docs](https://developers.themoviedb.org/3)
- [OMDb API Docs](http://www.omdbapi.com/)

---

<div align="center">

**MyMeta Architecture**

Clean, maintainable, extensible

[README](README.md) | [Quick Start](QUICK_START.md)

</div>
