# GitHub Release Guide - How to Trigger Updates

## 🎯 Quick Answer

**To release an update that users will see:**

1. Create a new GitHub Release
2. Tag it (e.g., `v1.0.2`)  
3. Upload `MyMeta-v1.0.2-windows.zip`
4. ✅ **CHECK "Set as latest release"** ← This is the key!

That's it! Users will see the update when they click "Check for Updates".

---

## 📋 Complete Release Process

### **Step 1: Prepare the Release**

```powershell
# Update version in pubspec.yaml
version: 1.0.2

# Build the release
.\build-release.ps1
```

---

### **Step 2: Create Git Tag**

```bash
# Create annotated tag
git tag -a v1.0.2 -m "Release v1.0.2"

# Push tag to GitHub
git push origin v1.0.2
```

--- **Step 3: Create GitHub Release**

1. Go to: `https://github.com/YourUsername/MyMeta/releases/new`

2. Fill in the form:
   ```
   Tag: v1.0.2
   Title: MyMeta v1.0.2
   Description: [Copy from CHANGELOG.md]
   
   ☑️ Set as the latest release  ← CRITICAL!
   ☐ Set as a pre-release
   ```

3. Upload `releases/MyMeta-v1.0.2-windows.zip`

4. Click **"Publish release"**

---

## 🔄 How Auto-Update Works

### **User Side:**

1. User opens MyMeta → Settings
2. Clicks **"Check for Updates"** button
3. App calls GitHub API
4. If update available → Shows dialog
5. User clicks **"Update Now"**
6. Downloads ZIP, extracts, replaces files
7. UserData folder is preserved ✅
8. App ready to restart

### **Technical Flow:**

```dart
GitHub API Call:
GET https://api.github.com/repos/YourUsername/MyMeta/releases/latest

Returns:
{
  "tag_name": "v1.0.2",
  "name": "MyMeta v1.0.2",
  "body": "Release notes...",
  "published_at": "2025-12-24T15:00:00Z",
  "assets": [
    {
      "name": "MyMeta-v1.0.2-windows.zip",
      "browser_download_url": "https://github.com/.../MyMeta-v1.0.2-windows.zip"
    }
  ]
}

App compares:
- Current version (from pubspec.yaml): 1.0.1
- Latest version (from GitHub): 1.0.2 
- If 1.0.2 > 1.0.1 → Update available!
```

---

## 🔐 Important Notes

### **"Set as latest release" is Critical!**

- ✅ **With checkbox**: API returns this release as "latest"
- ❌ **Without checkbox**: API ignores this release
- ℹ️ **Pre-release**: Not returned by `/releases/latest` endpoint

### **Version Format**

Must use semantic versioning:
```
Tag:  v1.0.2  (with 'v' prefix)
Code: 1.0.2   (without 'v' in pubspec.yaml)
```

### **ZIP File Naming**

Must contain "windows" and end with ".zip":
```
✅ MyMeta-v1.0.2-windows.zip
✅ MyMeta-windows-v1.0.2.zip
❌ MyMeta-v1.0.2.zip  (missing "windows")
❌ MyMeta-windows.tar.gz  (wrong extension)
```

---

## 🎨 Update Check UI

Users will see a new card in Settings:

```
┌─────────────────────────────────────┐
│ 🔄 Software Updates                 │
├─────────────────────────────────────│
│ Check for updates from GitHub       │
│ Releases. Your settings and tools   │
│ are preserved during updates.       │
│                                     │
│ [  Check for Updates  ]  ← Button  │
│                                     │
│ View All Releases on GitHub  →     │
└─────────────────────────────────────┘
```

When update is available:
```
┌──────────────────────────────┐
│ 🔄 Update Available          │
│                              │
│ MyMeta v1.0.2 is available!  │
│                              │
│ Release Notes:               │
│ - Episode descriptions       │
│ - Bug fixes                  │
│ - Performance improvements   │
│                              │
│ [ Later ] [ Update Now ]     │
└──────────────────────────────┘
```

During update:
```
┌──────────────────────────────┐
│ Updating MyMeta              │
│                              │
│ ████████████████░░░░  80%    │
│ Installing update...         │
└──────────────────────────────┘
```

---

## ⚙️ Configuration

### **Update Your GitHub Details**

In `lib/services/update_service.dart`:

```dart
// Line 9-10
static const String repoOwner = 'YourUsername';  // ← Your GitHub username
static const String repoName = 'MyMeta';         // ← Your repo name
```

**Example:**
```dart
static const String repoOwner = 'ivburic';
static const String repoName = 'MyMeta';
```

---

## 🛡️ What Gets Preserved During Updates

### **Replaced:**
- ✅ MyMeta.exe (new version)
- ✅ All .dll files (updated runtime)
- ✅ data/ folder (new assets)
- ✅ Documentation (README, LICENSE, etc.)

### **Preserved:**
- ✅ UserData/settings.db (all user settings)
- ✅ UserData/tools/ (FFmpeg, mkvpropedit, etc.)
- ✅ All user configurations
- ✅ Statistics and history

---

## 📝  Release Checklist

Before publishing a release:

- [ ] Update `pubspec.yaml` version
- [ ] Update `CHANGELOG.md`
- [ ] Run `.\build-release.ps1`
- [ ] Test release package on clean system
- [ ] Create Git tag
- [ ] Push tag to GitHub
- [ ] Create GitHub Release
- [ ] Upload ZIP file
- [ ] ✅ **CHECK "Set as latest release"**
- [ ] Verify update shows in app

---

## 🐛 Troubleshooting

### **"No update found" but I just published**

**Check:**
1. Is "Set as latest release" checked? ✅
2. Is tag format correct? (`v1.0.2`)
3. Is ZIP named correctly? (`*windows*.zip`)
4. Did you push the tag? (`git push origin v1.0.2`)

### **Update downloads but fails to install**

**Possible causes:**
- ZIP structure is wrong (should have root folder)
- Missing files in ZIP (exe, dlls, data/)
- Antivirus blocking file replacement

### **How to test without publishing**

You can't easily test the GitHub API locally, but you can:
1. Create a test repository
2. Publish releases there first
3. Point `repoOwner`/`repoName` to test repo
4. Test the full flow
5. Switch back to production repo

---

## 🚀 Your Release is Live!

Once you:
1. ✅ Build with `.\build-release.ps1`
2. ✅ Create GitHub Release  
3. ✅ Upload ZIP
4. ✅ Check "Set as latest release"

**Users can now update automatically!** 🎉

They just need to:
- Open MyMeta
- Go to Settings
- Click "Check for Updates"
- Click "Update Now"
- Restart MyMeta

**Done!** Their settings and tools are preserved.
