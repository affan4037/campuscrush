import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/user.dart';

class UserSearchService {
  final ApiService _apiService;
  final String _basePath = '${AppConstants.apiPrefix}/users';

  UserSearchService(this._apiService);

  /// Searches for users by name or username
  Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await _apiService.get('$_basePath/search?q=$query');
      return _parseUserList(response.data);
    } catch (e) {
      _logError('searching users', e);
      return [];
    }
  }

  /// Gets a specific user by ID
  Future<User?> getUserById(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final response = await _apiService.get('$_basePath/$userId');
      return _parseUserData(response.data);
    } catch (e) {
      _logError('fetching user by ID', e);
      return null;
    }
  }

  /// Gets a specific user by username
  Future<User?> getUserByUsername(String username) async {
    if (username.isEmpty) return null;

    try {
      final response =
          await _apiService.get('$_basePath/by-username/$username');
      return _parseUserData(response.data);
    } catch (e) {
      _logError('fetching user by username', e);
      return null;
    }
  }

  List<User> _parseUserList(dynamic data) {
    if (data == null) return [];

    try {
      final List<dynamic> usersJson =
          data is String ? json.decode(data) : (data is List ? data : []);

      return usersJson
          .whereType<Map<String, dynamic>>()
          .map((json) => User.fromJson(json))
          .toList();
    } catch (e) {
      _logError('parsing user list', e);
      return [];
    }
  }

  User? _parseUserData(dynamic data) {
    if (data == null) return null;

    try {
      Map<String, dynamic> userJson;

      if (data is String) {
        userJson = json.decode(data);
      } else if (data is Map) {
        userJson = data as Map<String, dynamic>;
      } else {
        return null;
      }

      return User.fromJson(userJson);
    } catch (e) {
      _logError('parsing user data', e);
      return null;
    }
  }

  void _logError(String operation, dynamic error) {
    if (kDebugMode) {
      debugPrint('Error $operation: $error');
    }
  }
}
