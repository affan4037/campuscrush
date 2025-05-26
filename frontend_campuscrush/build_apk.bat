@echo off
echo Building Flutter APK for Campus Crush...

REM Clean the project
flutter clean

REM Get dependencies
flutter pub get

echo.
echo Using keystore in android/key.jks for signing the APK
echo.
timeout /t 2 > nul

REM Build the APK with release signing
flutter build apk --release

echo.
echo APK build completed!
echo.
echo You can find the APK at: build\app\outputs\flutter-apk\app-release.apk
echo.
echo To upload to Firebase App Distribution, navigate to:
echo https://console.firebase.google.com/project/_/appdistribution
echo.
echo Press any key to exit...
pause > nul 