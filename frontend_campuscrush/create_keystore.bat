@echo off
echo Generating keystore file for Campus Crush app...

set KEYSTORE_PATH=android\key.jks
set KEY_ALIAS=campus_crush
set STORE_PASSWORD=campus123
set KEY_PASSWORD=campus123
set VALIDITY_DAYS=10000

echo Creating keystore at %KEYSTORE_PATH%
keytool -genkeypair -v ^
    -keystore %KEYSTORE_PATH% ^
    -alias %KEY_ALIAS% ^
    -keyalg RSA ^
    -keysize 2048 ^
    -validity %VALIDITY_DAYS% ^
    -storetype JKS ^
    -storepass %STORE_PASSWORD% ^
    -keypass %KEY_PASSWORD% ^
    -dname "CN=Campus Crush, OU=Development Team, O=Campus Crush, L=Your City, S=Your State, C=US"

if %errorlevel% equ 0 (
    echo.
    echo Keystore created successfully at %KEYSTORE_PATH%
    echo Store password: %STORE_PASSWORD%
    echo Key alias: %KEY_ALIAS%
    echo Key password: %KEY_PASSWORD%
    
    echo.
    echo Important: Now update these values in android/app/build.gradle:
    echo signingConfigs {
    echo     release {
    echo         storeFile file("../key.jks")
    echo         storePassword "%STORE_PASSWORD%"
    echo         keyAlias "%KEY_ALIAS%"
    echo         keyPassword "%KEY_PASSWORD%"
    echo     }
    echo }
) else (
    echo Failed to create keystore. Check the error message above.
)

pause 