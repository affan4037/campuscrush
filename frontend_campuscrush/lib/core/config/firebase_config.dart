import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration for the app
class FirebaseConfig {
  FirebaseConfig._();

  /// Initialize Firebase with proper options
  static Future<void> initialize() async {
    try {
      // For Android and iOS, Firebase will use google-services.json
      // and GoogleService-Info.plist automatically
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase: $e');
      // Rethrow to allow the app to handle the error
      rethrow;
    }
  }

  /// Get Firebase options for different platforms
  static FirebaseOptions? get platformOptions {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: "YOUR_WEB_API_KEY",
        authDomain: "YOUR_AUTH_DOMAIN",
        projectId: "YOUR_PROJECT_ID",
        storageBucket: "YOUR_STORAGE_BUCKET",
        messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
        appId: "YOUR_APP_ID",
      );
    } else {
      // For Android and iOS, the default options from the firebase_options.dart
      // generated file will be used, which should be created using the Firebase CLI
      return null;
    }
  }
}
