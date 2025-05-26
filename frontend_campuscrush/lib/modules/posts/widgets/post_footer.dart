import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../posts/providers/post_provider.dart';
import '../../posts/widgets/reaction_button.dart';

import '../reactions/models/reaction.dart';

import '../../../core/theme/responsive.dart';

class PostFooter extends StatelessWidget {
  final String postId;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final bool isLargeScreen;

  const PostFooter({
    Key? key,
    required this.postId,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.isLargeScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);
    final userHasReacted = isLiked;
    final currentReactionType = postProvider.getReactionType(postId);
    final hasSpecificReaction = currentReactionType != null;
    final hasLegacyLike = userHasReacted && currentReactionType == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEngagementMetrics(context, userHasReacted, currentReactionType),
        Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
        _buildActionButtons(
            context, postProvider, hasSpecificReaction, hasLegacyLike),
      ],
    );
  }

  Widget _buildEngagementMetrics(BuildContext context, bool userHasReacted,
      ReactionType? currentReactionType) {
    return Padding(
      padding: ResponsiveSpacing.content(context),
      child: Row(
        children: [
          if (likeCount > 0 && userHasReacted)
            _buildReactionIcon(context, currentReactionType),
          if (likeCount > 0)
            SizedBox(width: ResponsiveSpacing.horizontal(context)),
          if (likeCount > 0)
            Text(
              '$likeCount',
              style: ResponsiveTextStyles.caption(context),
            ),
          const Spacer(),
          if (commentCount > 0)
            Text(
              '$commentCount comments',
              style: ResponsiveTextStyles.caption(context),
            ),
          if (commentCount > 0)
            SizedBox(width: ResponsiveSpacing.horizontal(context)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, PostProvider postProvider,
      bool hasSpecificReaction, bool hasLegacyLike) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth = constraints.maxWidth / 3;
        final iconSize = ResponsiveUtils.getIconSize(
          context,
          small: 16.0,
          medium: 18.0,
          large: 20.0,
        );

        return Row(
          children: [
            SizedBox(
              width: buttonWidth,
              child: Center(
                child: ReactionButton(
                  isLiked: isLiked,
                  currentReaction: postProvider.getReactionType(postId),
                  onTap: onLike,
                  onReactionSelected: (reactionType) {
                    postProvider.reactToPost(postId, reactionType);
                  },
                  onReactionRemoved: () {
                    postProvider.unlikePost(postId);
                  },
                ),
              ),
            ),
            _buildActionButton(
              context,
              icon: Icon(Icons.comment, size: iconSize, color: Colors.grey),
              label: Text(
                'Comment',
                style: ResponsiveTextStyles.caption(context).copyWith(
                  color: Colors.grey,
                ),
              ),
              onTap: onComment,
              width: buttonWidth,
            ),
            _buildActionButton(
              context,
              icon: Icon(Icons.share, size: iconSize, color: Colors.grey),
              label: Text(
                'Share',
                style: ResponsiveTextStyles.caption(context).copyWith(
                  color: Colors.grey,
                ),
              ),
              onTap: onShare,
              width: buttonWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required Widget icon,
    required Widget label,
    required VoidCallback onTap,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveSpacing.horizontal(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                SizedBox(width: ResponsiveSpacing.horizontal(context) / 2),
                label,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionIcon(BuildContext context, ReactionType? reactionType) {
    final reactionConfig = _getReactionConfig(reactionType);
    final size = ResponsiveUtils.getIconSize(
      context,
      small: 14.0,
      medium: 15.0,
      large: 16.0,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: reactionConfig.color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: reactionConfig.isEmoji
            ? Text(
                reactionConfig.emoji!,
                style: TextStyle(fontSize: size * 0.625),
              )
            : Icon(
                reactionConfig.icon,
                size: size * 0.625,
                color: Colors.white,
              ),
      ),
    );
  }

  _ReactionConfig _getReactionConfig(ReactionType? reactionType) {
    switch (reactionType) {
      case ReactionType.like:
        return const _ReactionConfig(
          color: Colors.blue,
          icon: Icons.thumb_up,
        );
      case ReactionType.love:
        return const _ReactionConfig(
          color: Colors.red,
          icon: FontAwesomeIcons.heart,
        );
      case ReactionType.haha:
        return const _ReactionConfig(
          color: Colors.amber,
          isEmoji: true,
          emoji: '😂',
        );
      case ReactionType.wow:
        return const _ReactionConfig(
          color: Colors.amber,
          isEmoji: true,
          emoji: '😮',
        );
      case ReactionType.sad:
        return const _ReactionConfig(
          color: Colors.amber,
          isEmoji: true,
          emoji: '😢',
        );
      case ReactionType.angry:
        return const _ReactionConfig(
          color: Colors.orange,
          isEmoji: true,
          emoji: '😡',
        );
      default:
        return const _ReactionConfig(
          color: Colors.blue,
          icon: Icons.thumb_up,
        );
    }
  }
}

class _ReactionConfig {
  final Color color;
  final IconData? icon;
  final bool isEmoji;
  final String? emoji;

  const _ReactionConfig({
    required this.color,
    this.icon,
    this.isEmoji = false,
    this.emoji,
  });
}
