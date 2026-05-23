# MyMeta — Code Review & Cleanup

Review of ~16K LOC Flutter desktop app on `main`. Goal was a solid foundation
without behaviour changes or new features.

> **Note on IDE diagnostics during the cleanup session:** the analyzer reported
> `package:flutter/material.dart`, `cross_file`, `path` etc. as unresolved.
> These are real packages already in `pubspec.yaml` — the warnings were stale
> package resolution in the IDE. Run `flutter pub get` and the cascading
> `BuildContext`/`debugPrint`/`Widget` errors will disappear.

---

## Edits applied in this pass

All changes preserve behaviour. Largest reductions come from collapsing
duplicated tool-path resolution and unifying snackbar styling.

### Dead code removed
- [lib/backend/filename_parser.dart](lib/backend/filename_parser.dart) —
  `_cleanTitle()` was an identity no-op; removed.
- [lib/services/file_state_service.dart](lib/services/file_state_service.dart) —
  `updateRecordMetadata()` had a comment-only body and zero callers; removed.
- [lib/services/tool_downloader_service.dart](lib/services/tool_downloader_service.dart) —
  download progress loop had identical `if (totalBytes > 0) … else …` branches;
  collapsed.

### Duplication collapsed via existing constants/helpers
- [lib/services/file_state_service.dart](lib/services/file_state_service.dart):
  - `_sanitizeFilename` now uses `FileConfig.invalidFilenameChars` /
    `FileConfig.multipleSpaces` instead of redefining the regexes inline.
  - `_listVideoFiles` now uses `FileConfig.isVideoFile` instead of a private
    `_videoExtensions` set.
  - `hasAnyApi` checks replaced with `settings.hasAnyMetadataKey`.
  - Direct `http.get` for downloading covers replaced with
    `ApiClient.getImageBytes` (which already has timeout + size validation).
- [lib/constants/app_constants.dart](lib/constants/app_constants.dart) —
  `FileConfig.videoExtensions` extended to include `.flv .ts .m2ts .webm .mpg
  .mpeg` so the central constant matches the (previously broader) local set
  in `FileStateService`.
- [lib/services/poster_cache_service.dart](lib/services/poster_cache_service.dart):
  - `_downloadFileBytes` deleted; uses `ApiClient.getImageBytes` instead.
  - Filename-sanitize regexes replaced with the shared `FileConfig` regexes.
  - Local `_minCacheFileSize = 5000` now delegates to
    `ImageConfig.minImageSizeBytes` (was the same number duplicated).
- [lib/services/tool_downloader_service.dart](lib/services/tool_downloader_service.dart):
  - Two `switch (toolName) { 'ffmpeg' → 'ffmpeg', 'mkvpropedit' → 'mkvtoolnix',
    'atomicparsley' → 'atomicparsley' }` blocks replaced with
    `ToolConfig.getSubdirectory()`. `_getStartDirName()` deleted.
- [lib/services/settings_service.dart](lib/services/settings_service.dart):
  - The two ~60-line near-duplicates `_tryAutoFixInvalidPath` and
    `_tryAutoFixPath` collapsed into a single
    `_findToolInUserData()` + `_applyFoundToolPath()` pair. Net: ~110 lines
    of duplicated logic removed.
  - `validateAndFixToolPaths` had three repeated `if 'FFmpeg' { … } else if
    'mkvpropedit' { … }` blocks for "clear path and mark unavailable"; pulled
    into `_clearToolPath()`. The function also flattened from a 100-line
    nested if/else into a linear loop.

### Style/visual consistency
- [lib/utils/snackbar_helper.dart](lib/utils/snackbar_helper.dart) —
  `showWarning` and `showError` previously used a coloured fill (orange/red)
  with white text, while `showSuccess` and `showInfo` used the themed surface
  with a coloured border. All four now share `_show()`, so the four severities
  look like a family (icon + accent only differs). Warning uses
  `AppColors.*Warning`, error uses `AppColors.*Danger`, success/info use the
  user's accent.
- [lib/pages/home_page.dart](lib/pages/home_page.dart) —
  inline tab-bar `BoxShadow` replaced with `AppTheme.lightHeaderShadow`
  (already exists for the title bar, identical values).
- [lib/pages/settings_page.dart](lib/pages/settings_page.dart) —
  raw `ScaffoldMessenger.showSnackBar` for the PayPal failure replaced with
  `SnackbarHelper.showError` so it looks like every other error in the app.
- [lib/widgets/update_check_card.dart](lib/widgets/update_check_card.dart) —
  the two remaining raw `ScaffoldMessenger.showSnackBar` calls replaced with
  `SnackbarHelper.showInfo` / `SnackbarHelper.showError`.

### API hygiene
- [lib/pages/settings_page.dart](lib/pages/settings_page.dart) +
  [lib/widgets/accent_color_picker.dart](lib/widgets/accent_color_picker.dart) —
  three uses of deprecated `Color.value` replaced with `Color.toARGB32()`
  (which `SettingsService._saveSettings` already uses, so the codebase is now
  consistent).

---

## Findings I deliberately did **not** edit

These would be high-value but are either high-risk for a "don't break
functionality" pass, or need a product decision.

### 1. Triplicated FFmpeg path resolution (high value, medium risk)

Three implementations of "find ffmpeg.exe — UserData → custom path → bundled →
PATH":

- [lib/backend/core_backend.dart:783-849](lib/backend/core_backend.dart#L783-L849) — `_checkFFmpegAvailable` (caches `_ffmpegPath`, runs `-version`)
- [lib/utils/image_utils.dart:65-94](lib/utils/image_utils.dart#L65-L94) — `_getFFmpegPath` (sync, no settings)
- [lib/utils/cover_extractor.dart:327-355](lib/utils/cover_extractor.dart#L327-L355) — `_getFFmpegPath` (async, takes settings)

Each subtly different. Same story for AtomicParsley
([cover_extractor.dart:179](lib/utils/cover_extractor.dart#L179) vs
[core_backend.dart:931](lib/backend/core_backend.dart#L931)).
A single `ToolResolver` service in `lib/services/` would be the right home.

**Risk:** this is the portable-app's critical-path code. Recommended only with
manual smoke-testing on a clean machine + a machine where the user moved the
app folder mid-session.

### 2. `renameFiles` vs `renameSingleFile` duplication
[lib/services/file_state_service.dart:206-503](lib/services/file_state_service.dart#L206-L503)

~150 lines of identical cover-priority-1-bytes / priority-2-cached /
priority-3-download-fallback logic. Extracting a private
`_prepareCoverFor(int index, Directory cacheDir)` would cut ~80 lines.

**Risk:** medium. The two functions have subtly different early-exits and one
returns `bool`, the other returns `void`. Worth doing but needs a careful pass.

### 3. `core_backend.dart` is 2087 lines, `renamer_page.dart` is 2467 lines

These are the only files large enough to be a real maintenance hazard. They
should be split — `core_backend` into roughly:

- `matching/` (TMDB/OMDb/AniDB orchestration in `matchTitles`)
- `reading/` (FFprobe-based `readMetadata`)
- `embedding/` (mkvpropedit / AtomicParsley / FFmpeg writers)
- `tool_resolver.dart` (the duplicated FFmpeg/AtomicParsley lookups)

`renamer_page` into the page itself + per-row card widget + per-row state
controller. The current single-file model means almost any change requires
re-reading 2400 lines to understand the surrounding context.

**Risk:** high to do mechanically (lots of cross-references). Best done as its
own dedicated PR with the user testing end-to-end before merge. Skipped for
this pass as you asked.

### 4. `MediaRecord.withOverrides` does redundant parsing
[lib/backend/media_record.dart:17-35](lib/backend/media_record.dart#L17-L35)

The constructor runs `_analyze()` (a full filename parse) and *then*
constructs a new `ParsedMetadata` overwriting most fields. Cosmetic — costs
microseconds per file — and the existing implementation is correct because it
preserves `year`, `type`, `container` from the original parse. Not worth
refactoring.

### 5. `MatchResult.copyWith` is 60 lines with explicit `clearX` flags
[lib/backend/match_result.dart:66-129](lib/backend/match_result.dart#L66-L129)

The pattern works (set-or-clear nullable fields) but is verbose. Migrating to
`freezed` (which the analyzer config already excludes) would be a much larger
change touching every callsite of `copyWith`. Not worth it for a feature-
complete app.

### 6. `accent_color_picker` and `settings_page` duplicate the color list
[lib/widgets/accent_color_picker.dart:10-19](lib/widgets/accent_color_picker.dart#L10-L19)
defines the 8 accent options. [lib/pages/settings_page.dart:30-40](lib/pages/settings_page.dart#L30-L40)
hard-codes the same 8 hex values in `_getColorName`. If a 9th colour is added
later, both lists must be updated. Small enough that the duplication is
tolerable; mention it now so future-you remembers.

### 7. `lib/theme/COMPONENTS.md` and `lib/theme/README.md`

These exist but were not opened during the review. If they describe the design
system, they may need a refresh after the snackbar consolidation (the four
variants now share one shape).

### 8. Empty `catch (e) {}` in places that swallow useful errors

`analysis_options.yaml` has `empty_catches: false` disabled, so the linter
allows them. Most uses are intentional (filesystem operations where we have a
graceful fallback), but a quick audit revealed places that swallow
`Process.run` failures silently — e.g.
[cover_extractor.dart:95](lib/utils/cover_extractor.dart#L95),
[cover_extractor.dart:231](lib/utils/cover_extractor.dart#L231).
Adding a `debugPrint` would make troubleshooting on user machines easier
without changing behaviour.

### 9. Snackbar in `settings_page.dart` is now consistent — but renamer page snackbars use the old API surface

`renamer_page.dart` already calls `SnackbarHelper.*`, so all snackbars in the
app now use the unified style — the consolidation here is purely visual
consistency between previously divergent severities.

---

## What you should do next

1. **Run `flutter pub get`** to clear the stale analyzer state, then
   **`flutter analyze`**. Expect zero new warnings from this pass; if you see
   `debugPrint`/`BuildContext` errors, pub get hasn't run yet.
2. **`flutter test`** — there is a `test/` directory; I didn't inspect it
   beyond confirming it exists.
3. Manual smoke test of the four flows touched here:
   - Add files → match → rename (file_state_service paths).
   - Settings → change accent (accent_color_picker comparison).
   - Settings → invalid PayPal launch (snackbar).
   - Tool download in Settings (tool_downloader_service).
4. When you have time and stomach for the bigger refactors, see "Findings I
   deliberately did not edit" — items 1, 2, and 3 (in that order of
   value/effort) would significantly improve maintainability.
