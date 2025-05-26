import 'package:flutter/foundation.dart';
import '../../user_management/models/user.dart';

enum NotificationType {
  friendshipRequest,
  friendAccepted,
  postLike,
  postComment,
  commentLike,
  mention,
  unknown, // Added for better error handling
}

class NotificationModel {
  final String id;
  final String userId;
  final String actorId;
  final User? actor;
  final NotificationType type;
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.actorId,
    this.actor,
    required this.type,
    this.postId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      return NotificationModel(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        actorId: json['actor_id'] ?? '',
        actor: json['actor'] != null ? User.fromJson(json['actor']) : null,
        type: _parseNotificationType(json['type']),
        postId: json['post_id'],
        commentId: json['comment_id'],
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(
            json['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      debugPrint('Error parsing notification: $e');
      return NotificationModel(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        actorId: json['actor_id'] ?? '',
        actor: null,
        type: NotificationType.unknown,
        isRead: false,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'actor_id': actorId,
      'type': _notificationTypeToString(type),
      'post_id': postId,
      'comment_id': commentId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String _notificationTypeToString(NotificationType type) {
    switch (type) {
      case NotificationType.friendshipRequest:
        return 'friend_request';
      case NotificationType.friendAccepted:
        return 'friend_accepted';
      case NotificationType.postLike:
        return 'post_like';
      case NotificationType.postComment:
        return 'post_comment';
      case NotificationType.commentLike:
        return 'comment_like';
      case NotificationType.mention:
        return 'mention';
      case NotificationType.unknown:
        return 'unknown';
    }
  }

  static NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.unknown;

    final normalizedType = type.toLowerCase().replaceAll('_', '');

    switch (normalizedType) {
      case 'friendrequest':
      case 'friendshiprequest':
        return NotificationType.friendshipRequest;
      case 'friendaccepted':
        return NotificationType.friendAccepted;
      case 'postlike':
        return NotificationType.postLike;
      case 'postcomment':
        return NotificationType.postComment;
      case 'commentlike':
        return NotificationType.commentLike;
      case 'mention':
        return NotificationType.mention;
      default:
        debugPrint('Unknown notification type: $type');
        return NotificationType.unknown;
    }
  }

  String get message {
    final actorName = actor?.fullName ?? 'Someone';

    switch (type) {
      case NotificationType.friendshipRequest:
        return '$actorName sent you a friend request';
      case NotificationType.friendAccepted:
        return '$actorName accepted your friend request';
      case NotificationType.postLike:
        return '$actorName liked your post';
      case NotificationType.postComment:
        return '$actorName commented on your post';
      case NotificationType.commentLike:
        return '$actorName liked your comment';
      case NotificationType.mention:
        return '$actorName mentioned you in a post';
      case NotificationType.unknown:
        return '$actorName interacted with you';
    }
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? actorId,
    User? actor,
    NotificationType? type,
    String? postId,
    String? commentId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actorId: actorId ?? this.actorId,
      actor: actor ?? this.actor,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
