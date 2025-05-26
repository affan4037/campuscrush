import 'package:json_annotation/json_annotation.dart';
import '../../../modules/posts/models/post.dart';
import '../../../modules/user_management/models/user.dart';
import '../../../modules/posts/comments/models/comment.dart';

part 'feed_item.g.dart';

@JsonSerializable()
class FeedItem {
  final Post post;
  final User author;
  @JsonKey(name: 'comment_count')
  final int commentCount;
  @JsonKey(name: 'reaction_count')
  final int reactionCount;
  @JsonKey(name: 'has_reacted')
  final bool hasReacted;
  @JsonKey(name: 'reaction_type')
  final String? reactionType;
  @JsonKey(name: 'latest_comment', includeIfNull: false)
  final Comment? latestComment;

  FeedItem({
    required this.post,
    required this.author,
    required this.commentCount,
    required this.reactionCount,
    required this.hasReacted,
    this.reactionType,
    this.latestComment,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => _$FeedItemFromJson(json);
  Map<String, dynamic> toJson() => _$FeedItemToJson(this);
  
  // Create a copy of this FeedItem with updated fields
  FeedItem copyWith({
    Post? post,
    User? author,
    int? commentCount,
    int? reactionCount,
    bool? hasReacted,
    String? reactionType,
    Comment? latestComment,
  }) {
    return FeedItem(
      post: post ?? this.post,
      author: author ?? this.author,
      commentCount: commentCount ?? this.commentCount,
      reactionCount: reactionCount ?? this.reactionCount,
      hasReacted: hasReacted ?? this.hasReacted,
      reactionType: reactionType ?? this.reactionType,
      latestComment: latestComment ?? this.latestComment,
    );
  }
} 