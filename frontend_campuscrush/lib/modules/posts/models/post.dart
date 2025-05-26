import 'package:flutter/foundation.dart';
import '../../user_management/models/user.dart';
import '../../../core/constants/app_constants.dart';

class Post {
  final String id;
  final String content;
  final String? mediaUrl;
  final String authorId;
  final User? author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int commentCount;
  final int likeCount;
  final int shareCount;
  final bool isLikedByCurrentUser;
  final String? currentUserReactionType;

  const Post({
    required this.id,
    required this.content,
    this.mediaUrl,
    required this.authorId,
    this.author,
    required this.createdAt,
    required this.updatedAt,
    this.commentCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.isLikedByCurrentUser = false,
    this.currentUserReactionType,
  });

  String? get cachedMediaUrl {
    if (mediaUrl == null || mediaUrl!.isEmpty) return null;

    String adjustedUrl = mediaUrl!;

    // Fix localhost URLs that might not work on mobile devices
    if (adjustedUrl.contains('localhost') ||
        adjustedUrl.contains('127.0.0.1') ||
        adjustedUrl.contains('10.0.2.2')) {
      final baseUrlDomain = Uri.parse(AppConstants.baseUrl).host;
      adjustedUrl = adjustedUrl
          .replaceAll('localhost:8000', baseUrlDomain)
          .replaceAll('127.0.0.1:8000', baseUrlDomain)
          .replaceAll('10.0.2.2:8000', baseUrlDomain);
    }

    // Ensure URL is fully qualified
    if (adjustedUrl.startsWith('/') && !adjustedUrl.startsWith('//')) {
      adjustedUrl = '${AppConstants.baseUrl}$adjustedUrl';
    }

    // Fix media path
    adjustedUrl = _tryFixMediaPath(adjustedUrl);

    // Add cache busting parameter
    if (!adjustedUrl.contains('t=') && !adjustedUrl.contains('timestamp=')) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final separator = adjustedUrl.contains('?') ? '&' : '?';
      return '$adjustedUrl${separator}t=$timestamp';
    }

    return adjustedUrl;
  }

  String? get mediaFilename {
    if (mediaUrl == null || mediaUrl!.isEmpty) return null;

    try {
      final uri = Uri.parse(mediaUrl!);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (_) {
      // Extract filename using string operations as fallback
      final segments = mediaUrl!.split('/');
      if (segments.isNotEmpty) {
        final lastSegment = segments.last;
        return lastSegment.contains('?')
            ? lastSegment.split('?').first
            : lastSegment;
      }
    }

    return null;
  }

  String _tryFixMediaPath(String url) {
    try {
      final filename = mediaFilename;
      if (filename == null) return url;

      return AppConstants.createImageUrl(filename, category: 'post_media');
    } catch (e) {
      debugPrint('Error fixing media path: $e');
      return url;
    }
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      final id = _extractString(json, ['id', '_id', 'postId'], '');
      final content = _extractString(json, ['content', 'text', 'body'], '');
      final authorId = _extractString(
          json, ['author_id', 'authorId', 'user_id', 'userId'], '');

      if (id.isEmpty || content.isEmpty || authorId.isEmpty) {
        debugPrint('Post missing required fields');
      }

      final mediaUrl = _extractString(
          json, ['media_url', 'mediaUrl', 'image', 'image_url'], null);

      final createdAt = _extractDateTime(
          json, ['created_at', 'createdAt', 'timestamp', 'date']);
      final updatedAt = _extractDateTime(
          json, ['updated_at', 'updatedAt', 'last_modified', 'lastModified'],
          fallback: createdAt);

      User? author;
      try {
        if (json.containsKey('author') &&
            json['author'] is Map<String, dynamic>) {
          author = User.fromJson(json['author'] as Map<String, dynamic>);
        } else if (json.containsKey('user') &&
            json['user'] is Map<String, dynamic>) {
          author = User.fromJson(json['user'] as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('Error parsing author: $e');
      }

      final commentCount = _extractInt(
          json, ['comment_count', 'commentCount', 'comments_count'], 0);
      final likeCount = _extractIntOrListLength(
          json, ['like_count', 'likeCount', 'likes'], 0);
      final shareCount = _extractIntOrListLength(
          json, ['share_count', 'shareCount', 'shares'], 0);

      final isLikedByCurrentUser = _extractBool(
          json,
          [
            'is_liked_by_current_user',
            'isLikedByCurrentUser',
            'liked',
            'is_liked'
          ],
          false);

      final currentUserReactionType = _extractString(
          json,
          [
            'current_user_reaction_type',
            'currentUserReactionType',
            'reaction_type',
            'reactionType'
          ],
          null);

      return Post(
        id: id,
        content: content,
        mediaUrl: mediaUrl,
        authorId: authorId,
        author: author,
        createdAt: createdAt,
        updatedAt: updatedAt,
        commentCount: commentCount,
        likeCount: likeCount,
        shareCount: shareCount,
        isLikedByCurrentUser: isLikedByCurrentUser,
        currentUserReactionType: currentUserReactionType,
      );
    } catch (e) {
      debugPrint('Error creating Post from JSON: $e');
      return Post(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        content: 'Error loading post content',
        authorId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'media_url': mediaUrl,
      'author_id': authorId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'comment_count': commentCount,
      'like_count': likeCount,
      'share_count': shareCount,
      'is_liked_by_current_user': isLikedByCurrentUser,
      'current_user_reaction_type': currentUserReactionType,
    };
  }

  Post copyWith({
    String? id,
    String? content,
    String? mediaUrl,
    String? authorId,
    User? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? commentCount,
    int? likeCount,
    int? shareCount,
    bool? isLikedByCurrentUser,
    String? currentUserReactionType,
  }) {
    return Post(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      shareCount: shareCount ?? this.shareCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      currentUserReactionType:
          currentUserReactionType ?? this.currentUserReactionType,
    );
  }

  // Helper methods for JSON parsing
  static String _extractString(
      Map<String, dynamic> json, List<String> keys, String? defaultValue) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key].toString();
      }
    }
    return defaultValue ?? '';
  }

  static DateTime _extractDateTime(Map<String, dynamic> json, List<String> keys,
      {DateTime? fallback}) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        try {
          return DateTime.parse(json[key].toString());
        } catch (e) {
          debugPrint('Error parsing date $key: $e');
        }
      }
    }
    return fallback ?? DateTime.now();
  }

  static int _extractInt(
      Map<String, dynamic> json, List<String> keys, int defaultValue) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        try {
          return (json[key] as num).toInt();
        } catch (_) {
          // Continue to next key if parsing fails
        }
      }
    }
    return defaultValue;
  }

  static int _extractIntOrListLength(
      Map<String, dynamic> json, List<String> keys, int defaultValue) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        if (json[key] is num) {
          return (json[key] as num).toInt();
        } else if (json[key] is List) {
          return (json[key] as List).length;
        }
      }
    }
    return defaultValue;
  }

  static bool _extractBool(
      Map<String, dynamic> json, List<String> keys, bool defaultValue) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key] == true;
      }
    }
    return defaultValue;
  }
}
