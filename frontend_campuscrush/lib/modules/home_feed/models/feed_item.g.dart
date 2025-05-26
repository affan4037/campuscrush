// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedItem _$FeedItemFromJson(Map<String, dynamic> json) => FeedItem(
      post: Post.fromJson(json['post'] as Map<String, dynamic>),
      author: User.fromJson(json['author'] as Map<String, dynamic>),
      commentCount: (json['comment_count'] as num).toInt(),
      reactionCount: (json['reaction_count'] as num).toInt(),
      hasReacted: json['has_reacted'] as bool,
      reactionType: json['reaction_type'] as String?,
    );

Map<String, dynamic> _$FeedItemToJson(FeedItem instance) => <String, dynamic>{
      'post': instance.post,
      'author': instance.author,
      'comment_count': instance.commentCount,
      'reaction_count': instance.reactionCount,
      'has_reacted': instance.hasReacted,
      'reaction_type': instance.reactionType,
    };
