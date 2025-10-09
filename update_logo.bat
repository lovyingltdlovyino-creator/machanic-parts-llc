@echo off
echo Updating Mechanic Part LLC Logo and Icons...
echo.

echo Step 1: Getting dependencies...
flutter pub get

echo.
echo Step 2: Generating app icons...
flutter pub run flutter_launcher_icons

echo.
echo Step 3: Generating native splash screen...
flutter pub run flutter_native_splash:create

echo.
echo Step 4: Cleaning and rebuilding...
flutter clean
flutter pub get

echo.
echo Logo update complete!
echo.
echo IMPORTANT: Make sure you have placed your new logo as 'logo_new.png' in the assets/images/ folder
echo Then run: flutter build apk --release
echo.
pause
