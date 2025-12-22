@echo off
setlocal

echo ==========================================
echo    MyMeta - Build Script
echo ==========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not found in your PATH.
    echo Please install Flutter: https://flutter.dev/docs/get-started/install
    echo.
    pause
    exit /b 1
)

REM Display menu
echo Choose an option:
echo.
echo [1] Development Build (with hot reload)
echo [2] Release Build (optimized)
echo [3] Clean and Build Release
echo [4] Setup Project (first time only)
echo [Q] Quit
echo.
set /p choice="Enter choice: "

if /i "%choice%"=="1" goto dev_build
if /i "%choice%"=="2" goto release_build
if /i "%choice%"=="3" goto clean_build
if /i "%choice%"=="4" goto setup
if /i "%choice%"=="Q" goto end
echo Invalid choice. Please try again.
pause
goto end

:dev_build
echo.
echo ==========================================
echo    Starting Development Build
echo ==========================================
echo.
call flutter pub get
call flutter run -d windows
goto end

:release_build
echo.
echo ==========================================
echo    Building Release Version
echo ==========================================
echo.
echo [1/3] Getting dependencies...
call flutter pub get

echo.
echo [2/3] Analyzing code...
call flutter analyze

if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Code analysis found issues.
    echo Press any key to continue anyway, or Ctrl+C to cancel.
    pause >nul
)

echo.
echo [3/3] Building Windows Release...
call flutter build windows --release

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

goto show_success

:clean_build
echo.
echo ==========================================
echo    Clean + Release Build
echo ==========================================
echo.
echo [1/4] Cleaning project...
call flutter clean

echo.
echo [2/4] Getting dependencies...
call flutter pub get

echo.
echo [3/4] Analyzing code...
call flutter analyze

if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Code analysis found issues.
    echo Press any key to continue anyway, or Ctrl+C to cancel.
    pause >nul
)

echo.
echo [4/4] Building Windows Release...
call flutter build windows --release

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

goto show_success

:setup
echo.
echo ==========================================
echo    First-Time Setup
echo ==========================================
echo.
echo [1/3] Checking Windows platform files...
if not exist "windows" (
    echo [INFO] Generating Windows configuration...
    call flutter create . --platforms=windows
)

echo.
echo [2/3] Getting dependencies...
call flutter pub get

echo.
echo [3/3] Running code analysis...
call flutter analyze

echo.
echo ==========================================
echo    Setup Complete!
echo ==========================================
echo.
echo You can now:
echo   - Run development build: flutter run -d windows
echo   - Build release: Use option [2] or [3]
echo.
pause
goto end

:show_success
echo.
echo ==========================================
echo    Build Successful!
echo ==========================================
echo.
echo The executable is located at:
echo build\windows\x64\runner\Release\MyMeta.exe
echo.
echo File size:
dir build\windows\x64\runner\Release\MyMeta.exe | find "MyMeta.exe"
echo.
echo NOTE: Third-party tools (FFmpeg, MKVToolNix, AtomicParsley)
echo are downloaded on first run via the in-app Setup dialog.
echo.
echo To distribute:
echo   1. Test build\windows\x64\runner\Release\MyMeta.exe
echo   2. Package the entire Release folder as ZIP
echo   3. Users can extract and run MyMeta.exe
echo.
pause

:end
endlocal
