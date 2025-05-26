import 'package:json_annotation/json_annotation.dart';
import 'feed_item.dart';

part 'feed_response.g.dart';

@JsonSerializable()
class FeedResponse {
  final List<FeedItem> items;
  final int total;
  @JsonKey(name: 'has_more')
  final bool hasMore;

  FeedResponse({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  factory FeedResponse.fromJson(Map<String, dynamic> json) => _$FeedResponseFromJson(json);
  Map<String, dynamic> toJson() => _$FeedResponseToJson(this);
} 