@echo off
echo Setting up Firebase CLI for App Distribution...

REM Check if Node.js is installed
node --version > nul 2>&1
if %errorlevel% neq 0 (
    echo Node.js is not installed. Please install Node.js from https://nodejs.org/
    goto :EOF
)

REM Install Firebase CLI globally if not already installed
call npm list -g firebase-tools > nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Firebase CLI...
    call npm install -g firebase-tools
) else (
    echo Firebase CLI is already installed.
)

REM Login to Firebase
echo.
echo Please login to your Firebase account...
call firebase login

REM Initialize Firebase in the project
echo.
echo Initializing Firebase in the project...
call firebase init

echo.
echo.
echo Firebase setup completed!
echo.
echo Next steps:
echo 1. Build your APK using the build_apk.bat script
echo 2. Get your Firebase App ID from the Firebase console
echo 3. Upload your APK using: firebase appdistribution:distribute build\app\outputs\flutter-apk\app-release.apk --app YOUR_FIREBASE_APP_ID
echo.
echo Press any key to exit...
pause > nul 