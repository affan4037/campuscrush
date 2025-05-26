import 'package:json_annotation/json_annotation.dart';
import '../../../user_management/models/user.dart';
import '../../../../core/constants/app_constants.dart';

part 'comment.g.dart';

@JsonSerializable()
class Comment {
  final String id;
  @JsonKey(name: 'post_id')
  final String postId;
  final String content;
  final User author;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @JsonKey(name: 'like_count')
  final int likeCount;
  @JsonKey(name: 'has_liked')
  final bool hasLiked;
  @JsonKey(name: 'parent_id')
  final String? parentId;
  @JsonKey(name: 'replies_count')
  final int repliesCount;
  @JsonKey(name: 'is_edited')
  final bool isEdited;

  const Comment({
    required this.id,
    required this.postId,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    this.likeCount = 0,
    this.hasLiked = false,
    this.parentId,
    this.repliesCount = 0,
    this.isEdited = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);

  Map<String, dynamic> toJson() => _$CommentToJson(this);

  Comment copyWith({
    String? id,
    String? postId,
    String? content,
    User? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    bool? hasLiked,
    String? parentId,
    int? repliesCount,
    bool? isEdited,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      content: content ?? this.content,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      hasLiked: hasLiked ?? this.hasLiked,
      parentId: parentId ?? this.parentId,
      repliesCount: repliesCount ?? this.repliesCount,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  static Comment safeFromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException("Cannot create Comment from null JSON");
    }

    try {
      return Comment(
        id: _extractString(json, 'id') ?? _generateFallbackId(),
        postId: _extractString(json, 'post_id') ?? '',
        content: _extractString(json, 'content') ?? 'No content',
        author: _extractAuthor(json),
        createdAt: _extractDateTime(json, 'created_at') ?? DateTime.now(),
        updatedAt: _extractDateTime(json, 'updated_at') ?? DateTime.now(),
        likeCount: _extractInt(json, 'like_count') ?? 0,
        hasLiked: json['has_liked'] == true,
        parentId: _extractString(json, 'parent_id'),
        repliesCount: _extractInt(json, 'replies_count') ?? 0,
        isEdited: json['is_edited'] == true,
      );
    } catch (e) {
      throw FormatException("Error creating Comment: $e");
    }
  }

  static String? _extractString(Map<String, dynamic> json, String key) {
    return json[key]?.toString();
  }

  static int? _extractInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;

    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static DateTime? _extractDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;

    try {
      if (value is String) {
        return DateTime.parse(value);
      }
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static User _extractAuthor(Map<String, dynamic> json) {
    if (json['author'] is Map<String, dynamic>) {
      try {
        return User.fromJson(json['author'] as Map<String, dynamic>);
      } catch (_) {}
    }

    final authorId = json['author_id']?.toString() ?? 'unknown-id';
    final authorName = _determineAuthorName(json);

    return User(
      id: authorId,
      username: json['username']?.toString() ?? 'anonymous',
      email: '',
      fullName: authorName,
      university: json['university']?.toString() ?? 'Unknown',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      profilePicture: AppConstants.getAvatarFallbackUrl(authorName),
    );
  }

  static String _determineAuthorName(Map<String, dynamic> json) {
    if (json['author_name'] is String) {
      return json['author_name'] as String;
    } else if (json['username'] is String) {
      return json['username'] as String;
    }
    return 'Unknown User';
  }

  static String _generateFallbackId() =>
      DateTime.now().millisecondsSinceEpoch.toString();
}
