import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../user_management/models/user.dart';
import '../services/auth_api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authApiService;
  final StorageService _storageService;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;
  User? _currentUser;

  AuthProvider({
    required ApiService apiService,
    required StorageService storageService,
  })  : _authApiService = AuthApiService(apiService),
        _storageService = storageService {
    _initializeAuth();
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  User? get currentUser => _currentUser;

  // Initialize authentication state
  Future<void> _initializeAuth() async {
    _setLoading(true);

    try {
      final token = await _storageService.getAuthToken();

      if (token != null) {
        // Set token in API service
        _authApiService.apiService.setAuthToken(token);

        // Get user data from storage
        final userData = await _storageService.getUserData();

        if (userData != null) {
          _currentUser = User.fromJson(userData);
          _isAuthenticated = true;
        } else {
          // If we have a token but no user data, fetch user profile
          await _fetchUserProfile();
        }
      }
    } catch (e) {
      _handleError(e);
      _isAuthenticated = false;
    } finally {
      _setLoading(false);
    }
  }

  // Fetch user profile
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _authApiService.getUserProfile();

      if (response.isSuccess && response.data != null) {
        _currentUser = User.fromJson(response.data!);
        _isAuthenticated = true;

        // Store user data
        await _storageService.saveUserData(response.data!);
      } else {
        _error = response.error ?? 'Failed to fetch user profile';
        _isAuthenticated = false;
      }
    } catch (e) {
      _handleError(e);
      _isAuthenticated = false;
    }
  }

  // Helper for error handling
  void _handleError(dynamic error) {
    if (error is DioException) {
      _error = error.response?.data?['detail'] ?? error.message;
    } else {
      _error = error.toString();
    }

    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);

    try {
      // Clear token and user data
      await Future.wait([
        _storageService.deleteAuthToken(),
        _storageService.deleteUserData(),
      ]);
      _authApiService.apiService.clearAuthToken();

      _isAuthenticated = false;
      _currentUser = null;
    } catch (e) {
      _handleError(e);
    } finally {
      _setLoading(false);
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
