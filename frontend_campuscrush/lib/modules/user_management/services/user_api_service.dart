import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../../../services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/form_data_helper.dart';
import '../models/user.dart';


/// Service for handling user-related API calls
class UserApiService {
  final ApiService _apiService;
  final String _usersEndpoint = '${AppConstants.apiPrefix}/users';
  static const _retryDelayMs = 500;
  static const _maxRetries = 2;

  UserApiService(this._apiService);

  /// Gets current user profile
  Future<ApiResponse<User>> getUserProfile({int retryCount = 0}) async {
    try {
      final response = await _apiService
          .get<Map<String, dynamic>>(AppConstants.userProfileEndpoint);

      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(User.fromJson(response.data!));
      } else if (response.statusCode == 401 && retryCount < _maxRetries) {
        debugPrint(
            '🔄 Retrying user profile fetch (attempt ${retryCount + 1})');
        await Future.delayed(const Duration(milliseconds: _retryDelayMs));

        await _refreshToken();
        return getUserProfile(retryCount: retryCount + 1);
      } else {
        return ApiResponse.error(
            response.error ?? 'Failed to fetch user profile');
      }
    } catch (e) {
      if (retryCount < _maxRetries) {
        debugPrint('🔄 Retrying after error: $e (attempt ${retryCount + 1})');
        await Future.delayed(const Duration(milliseconds: _retryDelayMs));
        return getUserProfile(retryCount: retryCount + 1);
      }
      return ApiResponse.error(e.toString());
    }
  }

  Future<void> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      if (token != null && token.isNotEmpty) {
        _apiService.setAuthToken(token);
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
  }

  /// Gets a user by ID
  Future<ApiResponse<User>> getUserById(String userId) async {
    try {
      final response = await _apiService
          .get<Map<String, dynamic>>('$_usersEndpoint/$userId');

      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(User.fromJson(response.data!));
      } else {
        return ApiResponse.error(response.error ?? 'Failed to fetch user');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Gets a user by username
  Future<ApiResponse<User>> getUserByUsername(String username) async {
    try {
      final response = await _apiService
          .get<Map<String, dynamic>>('$_usersEndpoint/by-username/$username');

      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(User.fromJson(response.data!));
      } else {
        return ApiResponse.error(
            response.error ?? 'Failed to fetch user profile');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Extracts users from various response formats
  List<User> _extractUsersFromResponse(dynamic responseData) {
    if (responseData == null) return [];

    try {
      // Handle direct list of users
      if (responseData is List) {
        return responseData
            .whereType<Map<String, dynamic>>()
            .map((user) => User.fromJson(user))
            .toList();
      }

      // Handle structured responses with user lists
      if (responseData is Map<String, dynamic>) {
        // Common response structures
        for (final key in ['items', 'users', 'data', 'results']) {
          if (responseData.containsKey(key) && responseData[key] is List) {
            return _extractUsersFromList(responseData[key] as List);
          }
        }

        // Find any list in the response
        final listEntry = responseData.entries
            .where((entry) => entry.value is List)
            .firstOrNull;

        if (listEntry != null) {
          return _extractUsersFromList(listEntry.value as List);
        }
      }

      // Try parsing string data
      if (responseData is String) {
        try {
          final decodedData = json.decode(responseData);
          if (decodedData is List || decodedData is Map) {
            return _extractUsersFromResponse(decodedData);
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error extracting users: $e');
    }

    return [];
  }

  List<User> _extractUsersFromList(List items) {
    return items
        .whereType<Map<String, dynamic>>()
        .map((user) => User.fromJson(user))
        .toList();
  }

  /// Gets users with pagination
  Future<ApiResponse<List<User>>> getUsers(
      {int skip = 0, int limit = 50}) async {
    try {
      final response = await _apiService.get<dynamic>(
          '$_usersEndpoint?skip=$skip&limit=$limit',
          validateTokenFirst: true);

      if (response.isSuccess) {
        final users = _extractUsersFromResponse(response.data);
        return ApiResponse.success(users);
      } else if (response.statusCode == 500) {
        // Handle Pydantic validation errors gracefully
        debugPrint('Server error fetching users: ${response.error}');
        return ApiResponse.success([]);
      } else {
        return ApiResponse.error(response.error ?? 'Failed to fetch users',
            statusCode: response.statusCode);
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return ApiResponse.error('Error fetching users: $e');
    }
  }

  /// Searches users by query
  Future<ApiResponse<List<User>>> searchUsers(String query) async {
    try {
      final response =
          await _apiService.get<dynamic>('$_usersEndpoint/search?q=$query');

      if (response.isSuccess) {
        final users = _extractUsersFromResponse(response.data);
        return ApiResponse.success(users);
      } else if (response.statusCode == 404) {
        return ApiResponse.success([]);
      } else {
        debugPrint(
            'API error: ${response.error} (status: ${response.statusCode})');
        return ApiResponse.success([]);
      }
    } catch (e) {
      return ApiResponse.success([]);
    }
  }

  /// Updates the current user's profile
  Future<ApiResponse<User>> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? university,
    String? department,
    String? graduationYear,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        if (fullName != null) 'full_name': fullName,
        if (username != null) 'username': username,
        if (bio != null) 'bio': bio,
        if (university != null) 'university': university,
        if (department != null) 'department': department,
        if (graduationYear != null) 'graduation_year': graduationYear,
      };

      if (updateData.isEmpty) {
        return ApiResponse.error('No update data provided');
      }

      final response = await _apiService.put<Map<String, dynamic>>(
        '$_usersEndpoint/me',
        data: updateData,
      );

      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(User.fromJson(response.data!));
      } else {
        return ApiResponse.error(response.error ?? 'Failed to update profile');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Uploads a profile picture for the current user
  Future<ApiResponse<String>> uploadProfilePicture(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return ApiResponse.error('Image file does not exist');
      }

      final formData = await FormDataHelper.create(
        files: {'profile_picture': imageFile},
      );

      final response = await _apiService.post<Map<String, dynamic>>(
        '$_usersEndpoint/profile-picture',
        data: formData,
      );

      if (response.isSuccess && response.data != null) {
        final url = response.data!['profile_picture_url'];
        if (url == null) {
          return ApiResponse.error('No profile picture URL in response');
        }
        return ApiResponse.success(url);
      } else {
        return ApiResponse.error(
            response.error ?? 'Failed to upload profile picture');
      }
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Gets suggested users for "People You May Know" widget
  Future<ApiResponse<List<User>>> getSuggestedUsers(
      {int skip = 0, int limit = 50, bool excludeFriends = true}) async {
    try {
      final queryParams = [
        'skip=$skip',
        'limit=$limit',
        'exclude_friends=$excludeFriends',
        'status=not_friends',
      ].join('&');

      final response = await _apiService.get<dynamic>(
          '$_usersEndpoint/suggestions?$queryParams',
          validateTokenFirst: true);

      if (response.isSuccess) {
        final users = _extractUsersFromResponse(response.data);
        return ApiResponse.success(users);
      } else if (response.statusCode == 500) {
        // Handle Pydantic validation errors gracefully
        debugPrint('Server error fetching suggested users: ${response.error}');
        return ApiResponse.success([]);
      } else {
        return ApiResponse.error(
            response.error ?? 'Failed to fetch suggested users');
      }
    } catch (e) {
      debugPrint('Error fetching suggested users: $e');
      return ApiResponse.success([]);
    }
  }
}
