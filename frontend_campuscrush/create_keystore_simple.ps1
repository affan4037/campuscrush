# Set keystore parameters
$keystorePath = "android\key.jks"
$keyAlias = "campus_crush"
$storePassword = "campus123"
$keyPassword = "campus123"
$validityDays = 10000

# Create the keystore using direct command
keytool -genkeypair -v -keystore $keystorePath -alias $keyAlias -keyalg RSA -keysize 2048 -validity $validityDays -storetype JKS -storepass $storePassword -keypass $keyPassword -dname "CN=Campus Crush, OU=Development Team, O=Campus Crush, L=Your City, S=Your State, C=US"

Write-Host "If the keystore was created successfully, update these values in android/app/build.gradle"
Write-Host "storePassword: $storePassword"
Write-Host "keyAlias: $keyAlias"
Write-Host "keyPassword: $keyPassword" 