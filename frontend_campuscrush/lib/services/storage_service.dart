import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService._({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs: prefs);
  }

  // Secure storage operations
  Future<void> setSecureValue(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      debugPrint('Failed to save secure value: $e');
      // Fallback to shared preferences if secure storage fails
      await _prefs.setString(key, value);
    }
  }

  Future<String?> getSecureValue(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint('Failed to read secure value: $e');
      // Fallback to shared preferences if secure storage fails
      return _prefs.getString(key);
    }
  }

  Future<void> removeSecureValue(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Failed to remove secure value: $e');
    }
    // Also clean up from shared prefs to ensure complete removal
    await _prefs.remove(key);
  }

  Future<bool> clearSecureStorage() async {
    try {
      await _secureStorage.deleteAll();
      return true;
    } catch (e) {
      debugPrint('Failed to clear secure storage: $e');
      return false;
    }
  }

  // Auth token operations
  Future<void> saveAuthToken(String token) async {
    try {
      // Always store in secure storage first
      await _secureStorage.write(key: AppConstants.tokenKey, value: token);

      // Also save to shared preferences for backup and easier access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);

      debugPrint('✅ Auth token saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving auth token: $e');
      rethrow;
    }
  }

  Future<String?> getAuthToken() async {
    try {
      // Try secure storage first
      final secureToken = await _secureStorage.read(key: AppConstants.tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }

      // Fall back to shared preferences if needed
      final prefs = await SharedPreferences.getInstance();
      final prefToken = prefs.getString(AppConstants.tokenKey);

      // If we found token in prefs but not in secure storage, restore it
      if (prefToken != null &&
          prefToken.isNotEmpty &&
          (secureToken == null || secureToken.isEmpty)) {
        await _secureStorage.write(
            key: AppConstants.tokenKey, value: prefToken);
        debugPrint(
            '🔄 Restored token from shared preferences to secure storage');
      }

      return prefToken;
    } catch (e) {
      debugPrint('❌ Error retrieving auth token: $e');
      return null;
    }
  }

  Future<void> deleteAuthToken() async {
    try {
      // Delete from both storage types
      await _secureStorage.delete(key: AppConstants.tokenKey);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.tokenKey);

      debugPrint('✅ Auth token deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting auth token: $e');
      rethrow;
    }
  }

  // Shared preferences operations
  Future<bool> setValue(String key, dynamic value) async {
    try {
      if (value is String) {
        return await _prefs.setString(key, value);
      } else if (value is int) {
        return await _prefs.setInt(key, value);
      } else if (value is double) {
        return await _prefs.setDouble(key, value);
      } else if (value is bool) {
        return await _prefs.setBool(key, value);
      } else if (value is List<String>) {
        return await _prefs.setStringList(key, value);
      } else {
        // For complex objects, convert to JSON string
        return await _prefs.setString(key, json.encode(value));
      }
    } catch (e) {
      debugPrint('Failed to save value: $e');
      return false;
    }
  }

  // Type-safe getters for primitive types
  String? getStringValue(String key, {String? defaultValue}) =>
      _prefs.getString(key) ?? defaultValue;

  int? getIntValue(String key, {int? defaultValue}) =>
      _prefs.getInt(key) ?? defaultValue;

  double? getDoubleValue(String key, {double? defaultValue}) =>
      _prefs.getDouble(key) ?? defaultValue;

  bool? getBoolValue(String key, {bool? defaultValue}) =>
      _prefs.getBool(key) ?? defaultValue;

  List<String>? getStringListValue(String key, {List<String>? defaultValue}) =>
      _prefs.getStringList(key) ?? defaultValue;

  // Get a complex object from storage
  Map<String, dynamic>? getJsonMapValue(String key) {
    final String? jsonString = _prefs.getString(key);
    if (jsonString == null) return null;

    try {
      final dynamic decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to parse JSON from preferences: $e');
      return null;
    }
  }

  List<dynamic>? getJsonListValue(String key) {
    final String? jsonString = _prefs.getString(key);
    if (jsonString == null) return null;

    try {
      final dynamic decoded = json.decode(jsonString);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to parse JSON list from preferences: $e');
      return null;
    }
  }

  Future<bool> removeValue(String key) async {
    try {
      return await _prefs.remove(key);
    } catch (e) {
      debugPrint('Failed to remove value: $e');
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      // Clear both secure storage and shared prefs
      await clearSecureStorage();
      return await _prefs.clear();
    } catch (e) {
      debugPrint('Failed to clear storage: $e');
      return false;
    }
  }

  // User data operations
  Future<bool> saveUserData(Map<String, dynamic> userData) =>
      setValue(AppConstants.userKey, userData);

  Future<Map<String, dynamic>?> getUserData() {
    return Future.value(getJsonMapValue(AppConstants.userKey));
  }

  Future<bool> deleteUserData() => removeValue(AppConstants.userKey);

  // Theme preference
  Future<bool> saveThemeMode(ThemeMode themeMode) =>
      setValue(AppConstants.themeKey, themeMode.index);

  ThemeMode getThemeMode() {
    final themeModeIndex = getIntValue(AppConstants.themeKey,
        defaultValue: ThemeMode.system.index);

    // Safely handle index bounds
    if (themeModeIndex != null &&
        themeModeIndex >= 0 &&
        themeModeIndex < ThemeMode.values.length) {
      return ThemeMode.values[themeModeIndex];
    }
    return ThemeMode.system;
  }
}
