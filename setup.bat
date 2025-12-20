@echo off
echo Initializing Flutter project...
flutter create . --platforms=windows,macos,linux
echo installing dependencies...
flutter pub get
echo Done! You can now run 'flutter run -d windows'
pause
