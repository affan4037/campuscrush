import 'dart:convert';
import '../../../services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../user_management/models/user.dart';
import '../models/friendship.dart';
import '../models/friendship_status.dart';

/// Class to hold friendship details including status and request ID
class FriendshipDetails {
  final FriendshipStatus status;
  final String? requestId;

  FriendshipDetails(this.status, this.requestId);
}

/// Service class for handling friendships and friend requests
class FriendshipService {
  final ApiService _apiService;
  final String _basePath = '${AppConstants.apiPrefix}/friends';

  FriendshipService(this._apiService);

  /// Get current user's friends
  Future<List<User>> getFriends() async {
    try {
      final response = await _apiService.get(_basePath);
      final List<dynamic> friendsJson = json.decode(response.data);
      return friendsJson.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending friend requests received by the current user
  Future<List<FriendshipRequest>> getReceivedFriendRequests() async {
    return _getFriendRequests('$_basePath/requests/received');
  }

  /// Get friend requests sent by the current user
  Future<List<FriendshipRequest>> getSentFriendRequests() async {
    return _getFriendRequests('$_basePath/requests/sent');
  }

  Future<List<FriendshipRequest>> _getFriendRequests(String endpoint) async {
    try {
      final response = await _apiService.get(endpoint);
      final decodedData = _parseResponseData(response.data);
      return _convertToFriendshipRequests(decodedData);
    } catch (e) {
      rethrow;
    }
  }

  dynamic _parseResponseData(dynamic responseData) {
    if (responseData is List) {
      return responseData;
    }

    if (responseData is String) {
      try {
        return json.decode(responseData);
      } catch (e) {
        throw Exception('Invalid response format from server: $e');
      }
    }

    if (responseData is Map) {
      if (responseData.containsKey('data') && responseData['data'] is List) {
        return responseData['data'];
      }
      return [responseData];
    }

    throw Exception('Unexpected response type: ${responseData.runtimeType}');
  }

  List<FriendshipRequest> _convertToFriendshipRequests(dynamic data) {
    if (data is! List) {
      throw Exception(
          'Expected a list of requests but received ${data.runtimeType}');
    }

    final result = <FriendshipRequest>[];

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      try {
        final request = FriendshipRequest.fromJson(item);
        result.add(request);
      } catch (e) {
        // Try to create a simplified version to avoid losing data
        if (item is Map<String, dynamic>) {
          try {
            final id = item['id']?.toString() ?? 'error_id';
            final senderId = item['sender_id']?.toString() ?? '';
            final receiverId = item['receiver_id']?.toString() ?? '';

            // Create fallback request
            final fallbackRequest = FriendshipRequest(
              id: id,
              senderId: senderId,
              receiverId: receiverId,
              status: item['status']?.toString() ?? 'unknown',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            result.add(fallbackRequest);
          } catch (fallbackError) {
            // Silently continue on error
          }
        }
      }
    }

    return result;
  }

  /// Send a friend request
  Future<FriendshipRequest> sendFriendRequest(String receiverId) async {
    _validateId(receiverId, 'Cannot send friend request: Invalid user ID');

    try {
      final response = await _apiService.post(
        '$_basePath/request',
        data: {'receiver_id': receiverId},
      );

      _validateResponse(response, 'Failed to send friend request');

      // Handle different response data types
      final Map<String, dynamic> jsonData = _extractJsonData(response.data);
      return FriendshipRequest.fromJson(jsonData);
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to parse response data consistently
  Map<String, dynamic> _extractJsonData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid response format: $e');
      }
    }

    throw Exception('Unexpected response type: ${data.runtimeType}');
  }

  /// Accept a friend request
  Future<FriendshipRequest> acceptFriendRequest(String requestId) async {
    return _updateFriendRequestStatus(requestId, 'accepted', 'accept');
  }

  /// Reject a friend request
  Future<FriendshipRequest> rejectFriendRequest(String requestId) async {
    return _updateFriendRequestStatus(requestId, 'rejected', 'reject');
  }

  Future<FriendshipRequest> _updateFriendRequestStatus(
      String requestId, String status, String actionName) async {
    _validateId(
        requestId, 'Cannot $actionName friend request: Invalid request ID');

    try {
      final response = await _apiService.put(
        '$_basePath/request/$requestId',
        data: {'status': status},
      );

      _validateResponse(response, 'Failed to $actionName friend request');
      final Map<String, dynamic> jsonData = _extractJsonData(response.data);
      return FriendshipRequest.fromJson(jsonData);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel a sent friend request
  Future<FriendshipRequest> cancelFriendRequest(String requestId) async {
    _validateId(requestId, 'Cannot cancel friend request: Invalid request ID');

    try {
      final response =
          await _apiService.delete('$_basePath/request/$requestId');

      if (!response.isSuccess) {
        throw Exception(response.error ?? 'Failed to cancel friend request');
      }

      if (response.data == null || response.data.isEmpty) {
        return _createCanceledRequest(requestId);
      }

      try {
        final Map<String, dynamic> jsonData = _extractJsonData(response.data);
        return FriendshipRequest.fromJson(jsonData);
      } catch (e) {
        return _createCanceledRequest(requestId);
      }
    } catch (e) {
      rethrow;
    }
  }

  FriendshipRequest _createCanceledRequest(String requestId) {
    return FriendshipRequest(
      id: requestId,
      senderId: '',
      receiverId: '',
      status: 'canceled',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Remove friend
  Future<bool> removeFriend(String friendId) async {
    try {
      final response = await _apiService.delete('$_basePath/$friendId');
      return response.isSuccess;
    } catch (e) {
      rethrow;
    }
  }

  /// Check friendship status with another user
  Future<FriendshipDetails> getFriendshipDetails(String userId,
      {bool forceRefresh = false}) async {
    if (userId.isEmpty) {
      return FriendshipDetails(FriendshipStatus.notFriends, null);
    }

    try {
      final response = await _apiService.get('$_basePath/status/$userId');

      if (!response.isSuccess || response.data == null) {
        return FriendshipDetails(FriendshipStatus.notFriends, null);
      }

      final data = _extractResponseData(response.data);
      if (data == null || !data.containsKey('status')) {
        return FriendshipDetails(FriendshipStatus.notFriends, null);
      }

      final status = data['status'] as String;
      final requestId =
          data.containsKey('request_id') ? data['request_id'] as String? : null;

      return FriendshipDetails(_mapStatusToEnum(status), requestId);
    } catch (e) {
      return FriendshipDetails(FriendshipStatus.notFriends, null);
    }
  }

  dynamic _extractResponseData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData;
    }

    if (responseData is String) {
      try {
        return json.decode(responseData);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  FriendshipStatus _mapStatusToEnum(String status) {
    switch (status) {
      case 'friends':
        return FriendshipStatus.friends;
      case 'request_sent':
        return FriendshipStatus.pendingSent;
      case 'request_received':
        return FriendshipStatus.pendingReceived;
      case 'self':
        return FriendshipStatus.self;
      default:
        return FriendshipStatus.notFriends;
    }
  }

  void _validateResponse(dynamic response, String errorMsg) {
    if (!response.isSuccess) {
      throw Exception(response.error ?? errorMsg);
    }

    if (response.data == null || response.data.isEmpty) {
      throw Exception('Empty response from server');
    }
  }

  void _validateId(String id, String errorMsg) {
    if (id.isEmpty) {
      throw Exception(errorMsg);
    }
  }
}
