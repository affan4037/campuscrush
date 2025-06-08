import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../core/constants/app_constants.dart';
import '../modules/user_management/models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Response model for OAuth2 authentication
class OAuth2Response {
  final String accessToken;
  final String tokenType;
  final String? refreshToken;
  final int? expiresIn;

  OAuth2Response({
    required this.accessToken,
    required this.tokenType,
    this.refreshToken,
    this.expiresIn,
  });

  factory OAuth2Response.fromJson(Map<String, dynamic> json) => OAuth2Response(
        accessToken: json['access_token'],
        tokenType: json['token_type'],
        refreshToken: json['refresh_token'],
        expiresIn: json['expires_in'],
      );
}

/// Result model for authentication operations
class AuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;

  AuthResult({
    required this.success,
    this.message,
    this.data,
  });
}

/// Manages authentication state and operations
class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;
  final Dio dio;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _userData;
  String? _token;
  User? _currentUser;

  // Connectivity checker
  final _connectivity = InternetConnectionChecker();
  late StreamSubscription<InternetConnectionStatus> _connectivitySubscription;
  bool _hasConnection = true;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get userData => _userData;
  User? get currentUser => _currentUser;
  String? get token => _token;
  StorageService get storageService => _storageService;
  bool get hasConnection => _hasConnection;

  /// Checks server connectivity
  Future<bool> checkServerConnectivity() async {
    if (!await checkConnectivity()) {
      return false;
    }

    try {
      final response = await dio
          .get(
            '${_apiService.baseUrl}/api/health',
            options: Options(
              validateStatus: (status) => true,
              headers: {'Accept': 'application/json'},
            ),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode != null &&
          (response.statusCode! >= 200 && response.statusCode! < 400 ||
              response.statusCode == 401);
    } catch (e) {
      debugPrint('Server connectivity check failed: $e');
      return false;
    }
  }

  /// Checks if the current token is valid
  Future<bool> hasValidToken() async {
    if (_token == null || _token!.isEmpty) {
      return false;
    }

    try {
      final response = await _apiService.get(
        AppConstants.userProfileEndpoint,
      );
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  AuthService(this._apiService, this._storageService) : dio = Dio() {
    _configureDio();
    _initializeConnectivity();
    _initializeAuth();
  }

  void _configureDio() {
    dio.options.baseUrl = _apiService.baseUrl;
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.sendTimeout = const Duration(seconds: 30);
  }

  void _initializeConnectivity() {
    _connectivitySubscription = _connectivity.onStatusChange.listen(
      (InternetConnectionStatus status) {
        _hasConnection = status == InternetConnectionStatus.connected;
        if (_hasConnection) {
          // Optionally refresh data when connection is restored
          if (_isAuthenticated) {
            refreshUserProfile();
          }
        }
        notifyListeners();
      },
    );
  }

  Future<bool> checkConnectivity() async {
    _hasConnection = await _connectivity.hasConnection;
    return _hasConnection;
  }

  Future<void> _initializeAuth() async {
    _setLoading(true);

    try {
      // Get auth token
      _token = await _storageService.getAuthToken();

      if (_token != null && _token!.isNotEmpty) {
        // Set token in API service
        _apiService.setAuthToken(_token!);

        // Get user data
        final userData = await _storageService.getUserData();
        if (userData != null) {
          _userData = userData;
          _currentUser = User.fromJson(userData);
          _isAuthenticated = true;
        } else {
          // If we have a token but no stored user data, fetch user profile
          await refreshUserProfile();
        }
      }
    } catch (e) {
      debugPrint("AuthService: Error initializing auth: $e");
      _clearAuthState();
    } finally {
      _finishOperation();
    }
  }

  Future<bool> refreshUserProfile() async {
    if (_token == null || _token!.isEmpty) {
      // Try to reload token from storage as a fallback
      debugPrint(
          'AuthService: No token set, attempting to reload from storage');
      _token = await _storageService.getAuthToken();
      if (_token == null || _token!.isEmpty) {
        debugPrint(
            'AuthService: Still no token after reload, cannot fetch user profile');
        return false;
      } else {
        debugPrint(
            'AuthService: Token reloaded from storage: [32m$_token[0m');
        _apiService.setAuthToken(_token!);
      }
    }

    try {
      debugPrint('AuthService: Fetching user profile with token: $_token');
      final response = await _apiService.get(
        AppConstants.userProfileEndpoint,
      );
      debugPrint(
          'AuthService: User profile response status: [36m${response.statusCode}[0m');
      debugPrint(
          'AuthService: User profile response data: [36m${response.data}[0m');
      debugPrint(
          'AuthService: User profile response error: [31m${response.error}[0m');

      if (response.isSuccess && response.data != null) {
        _userData = response.data as Map<String, dynamic>;
        _currentUser = User.fromJson(_userData!);
        _isAuthenticated = true;

        // Store user data
        await _storageService.saveUserData(_userData!);
        return true;
      } else {
        debugPrint(
            'AuthService: Failed to fetch user profile, clearing auth state');
        _clearAuthState();
        return false;
      }
    } catch (e) {
      debugPrint('AuthService: Exception fetching user profile: $e');
      _clearAuthState();
      return false;
    }
  }

  void _clearAuthState() {
    _isAuthenticated = false;
    _userData = null;
    _currentUser = null;
    _token = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setOperationState() {
    _setLoading(true);
    _error = null;
  }

  void _finishOperation() {
    _setLoading(false);
    notifyListeners();
  }

  void _handleException(dynamic e) {
    debugPrint("AuthService: Exception: $e");
    if (e is DioException) {
      final response = e.response;
      if (response != null) {
        if (response.data is Map && response.data['detail'] != null) {
          _error = response.data['detail'];
        } else {
          _error = "Error ${response.statusCode}: ${response.statusMessage}";
        }
      } else {
        _error = e.message ?? "Network error";
      }
    } else {
      _error = e.toString();
    }
  }

  Future<AuthResult> getUserProfile() async {
    if (!await checkConnectivity()) {
      return AuthResult(
        success: false,
        message: "No internet connection",
      );
    }

    _setOperationState();

    try {
      final response = await _apiService.get(
        AppConstants.userProfileEndpoint,
      );

      if (response.isSuccess && response.data != null) {
        _userData = response.data as Map<String, dynamic>;
        _currentUser = User.fromJson(_userData!);
        _isAuthenticated = true;

        // Store user data
        await _storageService.saveUserData(_userData!);

        return AuthResult(
          success: true,
          data: _userData,
        );
      } else {
        _error = response.error ?? "Failed to get user profile";
        return AuthResult(
          success: false,
          message: _error,
        );
      }
    } catch (e) {
      _handleException(e);
      return AuthResult(
        success: false,
        message: _error,
      );
    } finally {
      _finishOperation();
    }
  }

  Future<void> logout() async {
    _setLoading(true);

    try {
      await _storageService.deleteAuthToken();
      await _storageService.deleteUserData();
      _clearAuthState();
      _apiService.clearAuthToken();
    } catch (e) {
      debugPrint("AuthService: Error during logout: $e");
    } finally {
      _finishOperation();
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? university,
    String? department,
    String? graduationYear,
    String? profilePicture,
  }) async {
    if (!await checkConnectivity()) {
      _error = "No internet connection";
      return false;
    }

    _setOperationState();

    try {
      final Map<String, dynamic> data = {};

      if (fullName != null) data['full_name'] = fullName;
      if (username != null) data['username'] = username;
      if (bio != null) data['bio'] = bio;
      if (university != null) data['university'] = university;
      if (department != null) data['department'] = department;
      if (graduationYear != null) data['graduation_year'] = graduationYear;
      if (profilePicture != null) data['profile_picture'] = profilePicture;

      final response = await _apiService.put(
        AppConstants.userProfileEndpoint,
        data: data,
      );

      if (response.isSuccess && response.data != null) {
        // Update local user data with response
        final updatedData = response.data as Map<String, dynamic>;
        _userData = updatedData;
        _currentUser = User.fromJson(updatedData);

        // Store updated user data
        await _storageService.saveUserData(updatedData);
        return true;
      } else {
        _error = response.error ?? "Failed to update profile";
        return false;
      }
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _finishOperation();
    }
  }

  void setToken(String token) {
    _token = token;
    _apiService.setAuthToken(token);
    debugPrint('AuthService: Token set: [32m$token[0m');
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
