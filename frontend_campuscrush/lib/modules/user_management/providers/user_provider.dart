import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_api_service.dart';

class UserProvider extends ChangeNotifier {
  final UserApiService _apiService;

  bool _isLoading = false;
  User? _currentUser;
  String? _error;

  UserProvider(this._apiService) {
    loadUserProfile();
  }

  // Getters
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
  String? get error => _error;

  Future<void> loadUserProfile() async {
    _setLoadingState(true);

    try {
      final response = await _apiService.getUserProfile();

      if (response.isSuccess && response.data != null) {
        _currentUser = response.data;
        _error = null;
      } else {
        _error = response.error ?? 'Failed to load user profile';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoadingState(false);
    }
  }

  void _setLoadingState(bool isLoading) {
    _isLoading = isLoading;
    _error = isLoading ? null : _error;
    notifyListeners();
  }

  Future<void> refreshUserProfile() => loadUserProfile();
}
