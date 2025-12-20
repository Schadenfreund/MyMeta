@echo off
setlocal

echo ==========================================
echo    Simpler FileBot - Windows Build Script
echo ==========================================

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not found in your PATH.
    echo Please install Flutter and add it to your PATH.
    pause
    exit /b 1
)

echo [1.5/4] Checking for Windows platform files...
if not exist "windows" (
    echo [INFO] Windows configuration missing. Generating...
    call flutter create . --platforms=windows
)


echo [1/4] Cleaning project...
call flutter clean

echo [2/4] Getting dependencies...
call flutter pub get

echo [3/4] Building Windows Release...
call flutter build windows --release

if %errorlevel% neq 0 (
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo    Build Successful!
echo ==========================================
echo.
echo The executable is located at:
echo build\windows\runner\Release\simpler_filebot.exe
echo.
echo You can zip the content of 'build\windows\runner\Release' to share your app.
echo.

pause
endlocal
