import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';

/// Manages authentication token storage, retrieval and synchronization
class TokenManager {
  final StorageService _storageService;
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage;

  String? _currentToken;

  // Time buffer (in seconds) before expiration when we should refresh
  static const int _tokenExpiryBuffer = 60;

  /// Creates a TokenManager with required dependencies
  TokenManager(this._storageService, this._apiService)
      : _secureStorage = const FlutterSecureStorage();

  /// Returns the current token from memory without async operations
  String? get currentToken => _currentToken;

  /// Retrieves token with fallback strategy: memory → secure storage
  Future<String?> getToken() async {
    if (_isValidToken(_currentToken)) {
      return _currentToken;
    }

    try {
      final token = await _secureStorage.read(key: AppConstants.tokenKey);
      if (_isValidToken(token)) {
        _currentToken = token;
        _apiService.setAuthToken(token!);
        return token;
      }
    } catch (e) {
      _logError('Error reading token from secure storage', e);
    }

    return null;
  }

  /// Checks if token is about to expire
  bool isTokenExpiring(String token) {
    try {
      // JWT tokens are three base64 parts separated by dots
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Decode the payload (middle part)
      String normalizedPayload = base64Url.normalize(parts[1]);
      final payloadMap =
          json.decode(utf8.decode(base64Url.decode(normalizedPayload)));

      // Check expiration time
      final expiry = payloadMap['exp'];
      if (expiry == null) return true;

      // Convert to seconds and add buffer
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiry < (now + _tokenExpiryBuffer);
    } catch (e) {
      _logError('Error checking token expiration', e);
      // If we can't parse it, assume it needs refresh
      return true;
    }
  }

  /// Stores token in all storage locations and updates API service
  Future<void> setToken(String token) async {
    debugPrint('🟢 setToken called with token: $token');
    if (token.isEmpty) {
      throw ArgumentError('Token cannot be empty');
    }

    try {
      await _secureStorage.write(key: AppConstants.tokenKey, value: token);
      debugPrint('🟢 Token written to secure storage: $token');
      _currentToken = token;
      _apiService.setAuthToken(token);
      await _storageService.saveAuthToken(token);
    } catch (e) {
      _logError('Error saving token', e);
      throw Exception('Failed to save authentication token: $e');
    }
  }

  /// Removes token from all storage locations and updates API service
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: AppConstants.tokenKey);
      _currentToken = null;
      _apiService.clearAuthToken();
      await _storageService.deleteAuthToken();
    } catch (e) {
      _logError('Error clearing token', e);
      throw Exception('Failed to clear authentication token: $e');
    }
  }

  /// Checks if user has a valid authentication token
  Future<bool> hasValidToken() async {
    final token = await getToken();
    if (!_isValidToken(token)) return false;

    // Additionally check for expiration
    if (isTokenExpiring(token!)) {
      debugPrint('🔄 Token is expiring soon, will need refresh');
      return false;
    }

    return true;
  }

  /// Helper to check if a token is valid (not null and not empty)
  bool _isValidToken(String? token) {
    return token != null && token.isNotEmpty;
  }

  /// Helper to log errors in debug mode
  void _logError(String message, dynamic error) {
    if (kDebugMode) {
      debugPrint('$message: $error');
    }
  }
}
