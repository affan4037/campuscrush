import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/constants/app_constants.dart';
import '../modules/notifications/models/notification.dart';
import 'auth_service.dart';

class NotificationService {
  final AuthService authService;
  final String baseUrl;
  final String fallbackUrl;
  late final Dio _dio;

  NotificationService({required this.authService})
      : baseUrl =
            '${AppConstants.baseUrl}${AppConstants.notificationsEndpoint}',
        fallbackUrl = '${AppConstants.baseUrl}/api/v1/notifications' {
    _initDio();
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      validateStatus: (status) => true, // Accept all status codes
    ));
  }

  // Headers with token for all API requests
  Map<String, String> _getHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // Validate token availability
  String? _validateToken() {
    final token = authService.token;
    if (token == null || token.isEmpty) {
      debugPrint('No authentication token available');
      return null;
    }
    return token;
  }

  // Main method to fetch notifications
  Future<List<NotificationModel>> getNotifications(
      {bool unreadOnly = false}) async {
    final token = _validateToken();
    if (token == null) return [];

    try {
      // Try primary URL first
      final response = await _dio.get(
        baseUrl,
        queryParameters: {'unread_only': unreadOnly},
        options: Options(headers: _getHeaders(token)),
      );

      // Handle successful response
      if (response.statusCode == 200) {
        return _parseNotificationList(response.data);
      }

      // Try fallback URL if primary URL returns the 404
      if (response.statusCode == 404) {
        final fallbackResponse = await _dio.get(
          fallbackUrl,
          queryParameters: {'unread_only': unreadOnly},
          options: Options(headers: _getHeaders(token)),
        );

        if (fallbackResponse.statusCode == 200) {
          return _parseNotificationList(fallbackResponse.data);
        }
        throw Exception('Notification endpoint not found (404)');
      }

      // Handle auth errors
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentication failed: ${response.statusCode}');
      }

      // Handle other errors
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }

  // Helper method to parse notification list
  List<NotificationModel> _parseNotificationList(dynamic responseData) {
    try {
      final List<dynamic> data =
          responseData is String ? json.decode(responseData) : responseData;
      return data.map((item) => NotificationModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint('JSON parsing failed: $e');
      throw Exception('Failed to parse notification data: $e');
    }
  }

  // Mark single notification as read
  Future<NotificationModel?> markAsRead(String notificationId) async {
    final token = _validateToken();
    if (token == null) return null;

    try {
      final response = await _dio.put(
        '$baseUrl/$notificationId',
        data: {'is_read': true},
        options: Options(headers: _getHeaders(token)),
      );

      if (response.statusCode == 200) {
        return NotificationModel.fromJson(response.data);
      } else {
        debugPrint(
            'Failed to mark notification as read: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return null;
    }
  }

  // Mark all notifications as read
  Future<Map<String, dynamic>?> markAllAsRead() async {
    return _performPutRequest('$baseUrl/mark-all-read');
  }

  // Delete single notification
  Future<NotificationModel?> deleteNotification(String notificationId) async {
    final token = _validateToken();
    if (token == null) return null;

    try {
      final response = await _dio.delete(
        '$baseUrl/$notificationId',
        options: Options(headers: _getHeaders(token)),
      );

      if (response.statusCode == 200) {
        return NotificationModel.fromJson(response.data);
      } else {
        debugPrint('Failed to delete notification: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return null;
    }
  }

  // Delete all notifications
  Future<Map<String, dynamic>?> deleteAllNotifications() async {
    return _performDeleteRequest(baseUrl);
  }

  // Helper method for PUT requests
  Future<Map<String, dynamic>?> _performPutRequest(String url,
      {Map<String, dynamic>? body}) async {
    final token = _validateToken();
    if (token == null) return null;

    try {
      final response = await _dio.put(
        url,
        data: body,
        options: Options(headers: _getHeaders(token)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        debugPrint('PUT request failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in PUT request: $e');
      return null;
    }
  }

  // Helper method for DELETE requests
  Future<Map<String, dynamic>?> _performDeleteRequest(String url) async {
    final token = _validateToken();
    if (token == null) return null;

    try {
      final response = await _dio.delete(
        url,
        options: Options(headers: _getHeaders(token)),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        debugPrint('DELETE request failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in DELETE request: $e');
      return null;
    }
  }
}
