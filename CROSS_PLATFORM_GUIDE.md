# Cross-Platform Release Guide (macOS & Linux)

## Current Status

Your Flutter app is **95% cross-platform ready** but has Windows-specific code that needs updating.

---

## What Needs to Change

### 1. **Enable macOS and Linux Platforms** ✅ Easy

```powershell
# Run these commands in your project directory
flutter create --platforms=macos,linux .
```

This will create `macos/` and `linux/` folders with platform-specific code.

### 2. **Platform-Specific Tool Paths** ⚠️ Medium Complexity

**Current Issue:** Code uses `.exe` extension everywhere (Windows-only)

**Fix:** Update `settings_service.dart` to detect platform:

```dart
import 'dart:io' show Platform;

// Platform-aware executable extension
String get _exeExtension => Platform.isWindows ? '.exe' : '';

// Platform-aware download URLs
String _getFFmpegUrl() {
  if (Platform.isWindows) {
    return 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';
  } else if (Platform.isMacOS) {
    return 'https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip'; // macOS FFmpeg
  } else if (Platform.isLinux) {
    return 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz'; // Linux FFmpeg
  }
  return '';
}
```

**Update all tool detection code:**
```dart
// Old
'$toolName.exe'

// New
'$toolName${_exeExtension}'
```

### 3. **Tool Download URLs** ⚠️ Critical

Need separate URLs for each platform:

| Tool | Windows | macOS | Linux |
|------|---------|-------|-------|
| **FFmpeg** | ✅ Current | 🔗 [evermeet.cx](https://evermeet.cx/ffmpeg/) | 🔗 [johnvansickle.com](https://johnvansickle.com/ffmpeg/) |
| **MKVToolNix** | ✅ Current | 🔗 [mkvtoolnix.download/macos](https://mkvtoolnix.download/downloads.html#macosx) | 🔗 Package manager (`apt/dnf`) |
| **AtomicParsley** | ✅ Current | 🔗 [homebrew](https://formulae.brew.sh/formula/atomicparsley) | 🔗 Package manager |

### 4. **Archive Extraction** ⚠️ Medium

**Current:** Uses `.zip` and `.7z` (Windows formats)
**Need:** Handle `.tar.gz`, `.tar.xz`, `.dmg` for macOS/Linux

**Solution:** Add `archive` package to pubspec.yaml:
```yaml
dependencies:
  archive: ^3.4.0
```

---

## Step-by-Step Implementation

### **Phase 1: Code Updates** (1-2 hours)

1. **Update `settings_service.dart`:**
   - Add Platform detection
   - Make executable extension dynamic
   - Add platform-specific download URLs

2. **Update `tool_downloader_service.dart`:**
   - Handle `.tar.gz` and `.tar.xz` archives
   - Platform-specific extraction logic

3. **Update all tool invocation code:**
   - Replace hardcoded `.exe` with dynamic extension
   - Handle path differences (`/` vs `\`)

### **Phase 2: Enable Platforms** (30 minutes)

```powershell
# Enable platforms
flutter create --platforms=macos,linux .

# Check dependencies compatibility
flutter pub get
```

### **Phase 3: Build for Each Platform** (Requires respective hardware/VM)

#### **macOS Build** (Requires Mac)
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/MyMeta.app
```

#### **Linux Build** (Requires Linux or WSL2)
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

---

## Platform-Specific Challenges

### **macOS:**

**✅ Easy:**
- Flutter builds native macOS app
- FFmpeg available via evermeet.cx

**⚠️ Challenges:**
1. **Code Signing** - Required for Gatekeeper
   - Need Apple Developer account ($99/year)
   - Or users must right-click → Open (security prompt)
   
2. **Notarization** - Required for macOS 10.15+
   - Submit to Apple for malware scan
   - Can take hours

3. **Different package format** - `.app` bundle vs `.exe`

**Estimated Time:** 4-8 hours (first time)

### **Linux:**

**✅ Easy:**
- No signing requirements
- flutter build works well

**⚠️ Challenges:**
1. **Many distributions** - Ubuntu, Fedora, Arch, etc.
   - Package `.deb` for Ubuntu/Debian
   - Package `.rpm` for Fedora/RHEL
   - Or just provide tar.gz (universal)

2. **Dependencies** - Need `clang`, `cmake`, `ninja-build`
   - Most Ubuntu users have these
   - Document in README

3. **Tool availability**
   - FFmpeg usually in repos
   - MKVToolNix in repos
   - AtomicParsley may need manual install

**Estimated Time:** 2-4 hours

---

## Simplified Approach (Recommended for v1.0)

### **Option 1: Windows-Only for v1.0** ⭐ Recommended

**Pros:**
- Ship now with Windows (95% of your target audience)
- Add macOS/Linux in v1.1 or v1.2
- Less testing burden
- Focus on perfecting Windows experience

**Cons:**
- Limits audience slightly

### **Option 2: macOS Next (v1.1)**

**Why macOS second:**
- Smaller changes needed
- FFmpeg + tools available
- Good testing with Apple Silicon Macs

**Steps:**
1. Update code for cross-platform tool paths
2. Find Mac to build/test on
3. Deal with signing/notarization
4. Release v1.1 with macOS support

### **Option 3: Linux After macOS (v1.2)**

**Why Linux last:**
- Multiple distros to support
- Most Linux users comfortable building from source
- Can provide just source code initially
- Package managers vary

---

## Code Example - Cross-Platform Tool Detection

Here's a patch for `settings_service.dart`:

```dart
class SettingsService with ChangeNotifier {
  // Platform-aware executable extension
  String get _exeExtension {
    if (Platform.isWindows) return '.exe';
    return ''; // macOS and Linux don't use extensions
  }

  // Platform-aware default tool URLs
  String get _defaultFFmpegUrl {
    if (Platform.isWindows) {
      return 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl-shared.zip';
    } else if (Platform.isMacOS) {
      return 'https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip';
    } else if (Platform.isLinux) {
      return 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz';
    }
    return '';
  }

  // Update all tool checks
  Future<bool> _isToolAvailable(String toolName) async {
    String? customPath;
    
    if (toolName == 'ffmpeg') {
      customPath = _ffmpegPath;
    } else if (toolName == 'mkvpropedit') {
      customPath = _mkvpropeditPath;
    } else if (toolName == 'AtomicParsley') {
      customPath = _atomicparsleyPath;
    }

    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (dir.existsSync()) {
        // CHANGE: Use dynamic extension
        final directPath = p.join(customPath, '$toolName$_exeExtension');
        if (File(directPath).existsSync()) {
          return true;
        }
        
        // Rest of code...
      }
    }
    
    return false;
  }
}
```

---

## Recommended Timeline

### **Now (v1.0):**
- ✅ Launch Windows version
- ✅ Get user feedback
- ✅ Fix any Windows bugs

### **v1.1 (1-2 months):**
- 🍎 Add macOS support
- Update README: "macOS support added!"
- Create macOS release

### **v1.2 (2-3 months):**
- 🐧 Add Linux support
- Provide `.deb` and `.tar.gz`
- Update README: "Now on Linux!"

---

## Testing Without Multiple Machines

### **Option 1: Virtual Machines**
- **macOS:** Use VMware (requires macOS ISO, technically against EULA)
- **Linux:** VirtualBox (free, easy)

### **Option 2: Cloud VMs**
- **macOS:** MacStadium, AWS EC2 Mac instances ($$$)
- **Linux:** Free AWS/Azure/Google Cloud credits

### **Option 3: GitHub Actions CI/CD**
- Free for open-source
- Builds on Windows, macOS, Linux automatically
- Most efficient approach

---

## My Recommendation

**For your v1.0 Reddit launch:**

✅ **Stay Windows-only**
- Say in README: "Windows support now, macOS/Linux coming soon"
- Focus on making Windows version perfect
- Get user feedback first

**After launch (v1.1):**
- Based on user requests, prioritize macOS or Linux
- Most data hoarders use Windows/Linux, Plex users often use macOS
- Can gauge interest from Reddit responses

**Advantages:**
1. Ship now, not in weeks
2. Learn from Windows users first
3. Better first impression (polished vs buggy cross-platform)
4. Iterate based on actual feedback

---

## Complexity Estimate

| Platform | Code Changes | Build Setup | Testing | Packaging | Total Time |
|----------|-------------|-------------|---------|-----------|------------|
| **Windows** | ✅ Done | ✅ Done | ✅ Done | ✅ Done | ✅ Complete |
| **macOS** | 4-6 hours | 2 hours | 4 hours | 4-8 hours | **14-20 hours** |
| **Linux** | Same as macOS | 1 hour | 4 hours | 2-4 hours | **11-15 hours** |

**Total for full cross-platform:** ~25-35 hours

---

## Bottom Line

**Question:** Should you add macOS/Linux before v1.0 launch?

**Answer:** **No.** Here's why:

1. ⏱️ **Time** - Delays your launch by 2-4 weeks
2. 🐛 **Bugs** - More platforms = more bugs to fix
3. 👥 **Audience** - Windows is 90%+ of your initial target
4. 📈 **Validation** - Test market fit with Windows first
5. 💰 **Resources** - macOS requires Mac hardware + $99/year

**Better approach:**
- Launch v1.0 Windows now
- Add in README: "macOS & Linux support planned for v1.1+"
- If people ask for it, you'll know there's demand
- Then invest the time to do it right

---

**Want to proceed with cross-platform anyway? I can help you implement it. Otherwise, launch Windows-only and dominate that market first! 🚀**
