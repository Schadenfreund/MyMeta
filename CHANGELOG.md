# MyMeta - Changelog

Track all notable changes, todos, and development guidelines.

---

## 🆕 Recent Updates

### **v1.0.0** - 2025-12-22
**Production Release - Zero Issues**

#### Code Quality
- ✅ Achieved **zero lint issues** (down from 245)
- ✅ Replaced 134 `print()` with `debugPrint()` (auto-stripped in release)
- ✅ Updated 63 deprecated Flutter APIs to modern syntax
- ✅ Fixed all BuildContext async safety issues
- ✅ Removed all unnecessary imports and null assertions
- ✅ 100% sound null safety maintained

#### Branding & Cleanup
- ✅ Removed all "simpler_filebot" references
- ✅ Updated window title to "MyMeta"
- ✅ Consolidated build scripts into single `build.bat`
- ✅ Deleted deprecated scripts (bundle_ffmpeg.ps1, setup.bat)
- ✅ Cleaned up 15+ temporary analysis files
- ✅ Consolidated redundant documentation

#### Features Enhanced
- ✅ Smart batch processing with metadata disambiguation
- ✅ TV show episode grouping for efficient workflow
- ✅ Multiple result selection modal for ambiguous searches
- ✅ Enhanced performance (60-120x faster with specialized tools)
- ✅ Modern Flutter 3.x+ APIs throughout

#### Build & Distribution
- ✅ Single comprehensive build script with menu options
- ✅ Development and release build support
- ✅ Automated code analysis before builds
- ✅ Clean project structure ready for distribution

---

### **v0.9.1** - 2025-12-21 (Internal)
**UI Architecture Refactoring**

#### Added
- ✅ Centralized card component system (`app_card.dart`)
  - `AppCard` - Reusable card container
  - `AppCardHeader` - Inline title + description header
  - `AppSettingRow` - Setting row with inline labels
  - `AppLabeledInput` - Input field with inline labels

#### Changed
- ✅ **Settings Page** - Refactored to use centralized components
  - API key inputs now display label + description inline (was stacked)
  - Removed 138 lines of duplicate code
  - All cards use consistent AppCard styling
- ✅ **Formats Page** - Refactored to use centralized components
  - Card headers now display title + description inline
  - Help card uses AppCardHeader for consistency
  - Reduced code by 30 lines
- ✅ **Tool Paths Card** - Fixed layout and status detection
  - Grey description text now appears next to bold title (was below)
  - Status indicator moved to right side of header (was left)
  - Fixed FFmpeg availability status detection

#### Fixed
- ✅ All card headers now use inline layout (title + description on same line)
- ✅ Consistent spacing and alignment across all cards
- ✅ Theme-aware colors for description text
- ✅ Status indicators positioned correctly (right side)

#### Code Quality
- 📉 Reduced total codebase by ~168 lines
- ♻️ Implemented DRY principles thoroughly
- 🎨 Centralized UI patterns for maintainability
- 📚 Updated architecture documentation

---

### **v1.6.0** - 2025-12-20
**One-Click Tool Setup**

#### Added
- ✅ Automatic tool download and configuration
- ✅ One-click FFmpeg, MKVToolNix, AtomicParsley setup
- ✅ Portable UserData folder storage
- ✅ Tool availability status indicators

#### Changed
- ✅ Rebranded from MyPay to MyMeta
- ✅ Smaller initial download (tools downloaded on-demand)
- ✅ Improved sidebar with soft glow effect
- ✅ Enhanced button organization

---

## 📋 TODO

### High Priority
- [ ] Add unit tests for core components
- [ ] Implement keyboard shortcuts (Ctrl+O, Ctrl+M, Ctrl+R, Ctrl+Z)
- [ ] Add progress bars for batch operations
- [ ] Improve error handling and user feedback

### Medium Priority
- [ ] Add preview before rename feature
- [ ] Implement watch folder automation
- [ ] Add metadata validation
- [ ] Create comprehensive logging system

### Low Priority
- [ ] Cross-platform support (macOS, Linux)
- [ ] Multi-language support
- [ ] Advanced search filters
- [ ] Custom metadata fields

### UI/UX Enhancements
- [ ] Improved file list virtualization for large batches
- [ ] Drag-to-reorder file list
- [ ] Bulk metadata editing
- [ ] Metadata templates/presets

---

## ✅ DO's

### Code Organization
- ✅ **DO** use existing markdown files (README.md, QUICK_START.md, ARCHITECTURE.md, CHANGELOG.md)
- ✅ **DO** update existing files rather than creating new documentation
- ✅ **DO** follow DRY (Don't Repeat Yourself) principles
- ✅ **DO** understand the architecture before making changes
- ✅ **DO** use centralized components from `widgets/app_card.dart`
- ✅ **DO** extract common patterns into reusable widgets
- ✅ **DO** keep single source of truth for styling

### UI Development
- ✅ **DO** use `AppCard` for all card-based layouts
- ✅ **DO** use `AppCardHeader` for inline title + description
- ✅ **DO** use `AppSettingRow` for settings with controls
- ✅ **DO** use `AppLabeledInput` for labeled input fields
- ✅ **DO** display labels and descriptions inline (not stacked)
- ✅ **DO** use theme-aware colors (AppColors)
- ✅ **DO** maintain baseline text alignment

### State Management
- ✅ **DO** use Provider for app-wide state
- ✅ **DO** notify listeners when state changes
- ✅ **DO** use `context.watch<>()` for reactive updates
- ✅ **DO** use `context.read<>()` for one-time reads

### File Management
- ✅ **DO** validate file paths and permissions
- ✅ **DO** handle errors gracefully with user feedback
- ✅ **DO** use async/await for file operations
- ✅ **DO** cleanup temporary files

### Testing
- ✅ **DO** test edge cases (large files, special characters, etc.)
- ✅ **DO** test on both Windows 10 and 11
- ✅ **DO** verify FFmpeg operations succeed
- ✅ **DO** test undo functionality

---

## ❌ DON'Ts

### Code Organization
- ❌ **DON'T** create new markdown files - use existing ones
- ❌ **DON'T** duplicate code - create reusable components instead
- ❌ **DON'T** create custom card/header widgets - use centralized ones
- ❌ **DON'T** ignore existing architecture patterns
- ❌ **DON'T** hardcode values - use theme constants

### UI Development
- ❌ **DON'T** stack title and description vertically - use inline layout
- ❌ **DON'T** create one-off card designs - maintain consistency
- ❌ **DON'T** use hardcoded colors - use AppColors and theme
- ❌ **DON'T** ignore accessibility (contrast, font sizes)
- ❌ **DON'T** create complex nested widgets - keep them simple

### State Management
- ❌ **DON'T** update state without notifying listeners
- ❌ **DON'T** use global variables for state
- ❌ **DON'T** create unnecessary state objects
- ❌ **DON'T** forget to dispose controllers and listeners

### File Operations
- ❌ **DON'T** modify files without user confirmation
- ❌ **DON'T** leave temporary files lying around
- ❌ **DON'T** assume file paths are valid without checking
- ❌ **DON'T** block UI during long operations

### Performance
- ❌ **DON'T** rebuild entire widget trees unnecessarily
- ❌ **DON'T** load all files into memory at once
- ❌ **DON'T** make synchronous API calls
- ❌ **DON'T** re-encode video (always use codec copy)

---

## 🎯 Best Practices

### Component Development
1. Check if a reusable component exists before creating new one
2. If creating new component, make it reusable and generic
3. Document component usage with examples
4. Keep components focused on single responsibility
5. Use composition over inheritance

### Code Review Checklist
- [ ] Uses existing reusable components
- [ ] Follows DRY principles
- [ ] Maintains inline header/description layout
- [ ] Uses theme-aware colors
- [ ] Properly disposes resources
- [ ] Handles errors with user feedback
- [ ] Updates relevant documentation

### Documentation Updates
When making changes:
1. Update ARCHITECTURE.md for structural changes
2. Update README.md for user-facing features
3. Update QUICK_START.md for workflow changes
4. Update this CHANGELOG.md with changes

---

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Material Design Guidelines](https://material.io/design)

---

## 🔄 Version History

### v1.0.0 (2025-12-23)
- Initial public release with zero lint issues
- Full metadata integration (TMDB, OMDb, AniDB)
- One-click tool setup
- MIT licensed with proper third-party attributions

### v0.9.x (Internal Development)
- UI architecture refactoring
- Custom titlebar and accent color system
- One-click tool setup development
- MyMeta rebrand from original project

---

<div align="center">

**MyMeta Changelog**

Keep improving, keep it clean

[README](README.md) | [Quick Start](QUICK_START.md) | [Architecture](ARCHITECTURE.md)

</div>
