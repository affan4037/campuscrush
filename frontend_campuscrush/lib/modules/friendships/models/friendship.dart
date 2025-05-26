import 'package:flutter/material.dart';
import '../../user_management/models/user.dart';

/// Represents a friendship request between two users
class FriendshipRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final User? sender;
  final User? receiver;
  final String status; // We'll keep this as string for API compatibility
  final DateTime createdAt;
  final DateTime updatedAt;

  const FriendshipRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.sender,
    this.receiver,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a FriendshipRequest from JSON data with robust error handling
  factory FriendshipRequest.fromJson(Map<String, dynamic> json) {
    try {
      return FriendshipRequest(
        id: json['id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        receiverId: json['receiver_id']?.toString() ?? '',
        sender: _parseUser(json['sender']),
        receiver: _parseUser(json['receiver']),
        status: json['status']?.toString() ?? 'unknown',
        createdAt: _parseDateTime(json['created_at']),
        updatedAt: _parseDateTime(json['updated_at']),
      );
    } catch (e) {
      debugPrint('Error parsing FriendshipRequest: $e');
      return FriendshipRequest(
        id: json['id']?.toString() ?? 'error_id',
        senderId: json['sender_id']?.toString() ?? '',
        receiverId: json['receiver_id']?.toString() ?? '',
        sender: null,
        receiver: null,
        status: 'error',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Converts the FriendshipRequest to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy of this FriendshipRequest with the given fields replaced
  FriendshipRequest copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    User? sender,
    User? receiver,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendshipRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Represents an established friendship between two users
class Friendship {
  final String id;
  final String userId;
  final String friendId;
  final User? user;
  final User? friend;
  final DateTime createdAt;

  const Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    this.user,
    this.friend,
    required this.createdAt,
  });

  /// Creates a Friendship from JSON data with error handling
  factory Friendship.fromJson(Map<String, dynamic> json) {
    try {
      return Friendship(
        id: json['id']?.toString() ?? '',
        userId: json['user_id']?.toString() ?? '',
        friendId: json['friend_id']?.toString() ?? '',
        user: _parseUser(json['user']),
        friend: _parseUser(json['friend']),
        createdAt: _parseDateTime(json['created_at']),
      );
    } catch (e) {
      debugPrint('Error parsing Friendship: $e');
      return Friendship(
        id: json['id']?.toString() ?? 'error_id',
        userId: json['user_id']?.toString() ?? '',
        friendId: json['friend_id']?.toString() ?? '',
        user: null,
        friend: null,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Converts the Friendship to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of this Friendship with the given fields replaced
  Friendship copyWith({
    String? id,
    String? userId,
    String? friendId,
    User? user,
    User? friend,
    DateTime? createdAt,
  }) {
    return Friendship(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      user: user ?? this.user,
      friend: friend ?? this.friend,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Utility functions for parsing
User? _parseUser(dynamic userData) {
  if (userData == null) return null;
  try {
    return User.fromJson(userData);
  } catch (e) {
    debugPrint('Error parsing user data: $e');
    return null;
  }
}

DateTime _parseDateTime(dynamic dateData) {
  if (dateData == null) return DateTime.now();
  try {
    return DateTime.parse(dateData.toString());
  } catch (e) {
    debugPrint('Error parsing date: $dateData');
    return DateTime.now();
  }
}
