import '../../../user_management/models/user.dart';

enum ReactionType {
  like,
  love,
  haha,
  wow,
  sad,
  angry,
}

class Reaction {
  final String id;
  final ReactionType type;
  final String userId;
  final User? user;
  final String? postId;
  final String? commentId;
  final DateTime createdAt;

  const Reaction({
    required this.id,
    required this.type,
    required this.userId,
    this.user,
    this.postId,
    this.commentId,
    required this.createdAt,
  }) : assert(postId != null || commentId != null,
            'Either postId or commentId must be provided');

  factory Reaction.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] ?? json['reaction_type'] ?? 'like';
    return Reaction(
      id: json['id'] as String? ?? '',
      type: _parseReactionType(typeValue.toString()),
      userId: json['user_id'] as String? ?? '',
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      postId: json['post_id'] as String?,
      commentId: json['comment_id'] as String?,
      createdAt: json.containsKey('created_at')
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString().split('.').last,
        'reaction_type': type.toString().split('.').last,
        'user_id': userId,
        if (postId != null) 'post_id': postId,
        if (commentId != null) 'comment_id': commentId,
        'created_at': createdAt.toIso8601String(),
      };

  static ReactionType _parseReactionType(String type) {
    final normalizedType = type.toLowerCase().trim();
    switch (normalizedType) {
      case 'like':
        return ReactionType.like;
      case 'love':
        return ReactionType.love;
      case 'haha':
        return ReactionType.haha;
      case 'wow':
        return ReactionType.wow;
      case 'sad':
        return ReactionType.sad;
      case 'angry':
        return ReactionType.angry;
      default:
        return ReactionType.like;
    }
  }

  Reaction copyWith({
    String? id,
    ReactionType? type,
    String? userId,
    User? user,
    String? postId,
    String? commentId,
    DateTime? createdAt,
  }) =>
      Reaction(
        id: id ?? this.id,
        type: type ?? this.type,
        userId: userId ?? this.userId,
        user: user ?? this.user,
        postId: postId ?? this.postId,
        commentId: commentId ?? this.commentId,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reaction &&
          id == other.id &&
          type == other.type &&
          userId == other.userId &&
          postId == other.postId &&
          commentId == other.commentId;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      userId.hashCode ^
      (postId?.hashCode ?? 0) ^
      (commentId?.hashCode ?? 0);
}
