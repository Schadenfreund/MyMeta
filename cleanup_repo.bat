@echo off
echo ========================================
echo MyMeta Repository Cleanup Script
echo ========================================
echo.
echo THIS WILL:
echo 1. Remove large binary files from git
echo 2. Update .gitignore
echo 3. Clean git history (requires force push)
echo.
echo WARNING: This rewrites git history!
echo Press Ctrl+C to cancel, or
pause

REM Update .gitignore first
echo.
echo [1/4] Updating .gitignore...
(
echo # Tool binaries ^(downloaded on-demand^)
echo windows/ffmpeg/
echo assets/*.zip
echo assets/*.7z
echo assets/*.exe
echo.
echo # User data
echo UserData/
) >> .gitignore

REM Remove large files from current working tree
echo.
echo [2/4] Removing binary files from working tree...
del /Q assets\*.zip 2>nul
del /Q assets\*.7z 2>nul
rmdir /S /Q windows\ffmpeg 2>nul

REM Remove from git
echo.
echo [3/4] Removing from git index...
git rm --cached -r assets/*.zip 2>nul
git rm --cached -r assets/*.7z 2>nul
git rm --cached -r windows/ffmpeg/ 2>nul

REM Commit changes
echo.
echo [4/4] Committing cleanup...
git add .gitignore
git commit -m "chore: remove binary files, update gitignore for on-demand downloads"

echo.
echo ========================================
echo NEXT STEPS:
echo ========================================
echo.
echo To completely remove from history (optional but recommended):
echo.
echo   git filter-branch --force --index-filter ^
echo     "git rm --cached --ignore-unmatch assets/*.zip assets/*.7z windows/ffmpeg/*" ^
echo     --prune-empty --tag-name-filter cat -- --all
echo.
echo   Then: git push origin --force --all
echo.
echo WARNING: Force push will rewrite public history!
echo Only do this if repo is still private or no one else has cloned.
echo.
pause
