import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/post.dart';
import '../providers/post_provider.dart';
import 'post_footer.dart';
import 'post_image.dart';
import '../comments/screens/comments_screen.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/responsive.dart';

class PostCard extends StatelessWidget {
  final Post post;

  const PostCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);
    final isLargeScreen =
        ResponsiveUtils.getScreenSize(context) == ScreenSize.large;

    return Card(
      margin: ResponsiveSpacing.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(context, isLargeScreen),
          if (post.content.isNotEmpty) _buildPostContent(context),
          if (_hasMedia) _buildMediaContent(context),
          PostFooter(
            postId: post.id,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            shareCount: post.shareCount,
            isLiked: post.isLikedByCurrentUser,
            onLike: () => _handleLike(postProvider),
            onComment: () => _navigateToComments(context),
            onShare: () =>
                _showMessage(context, 'Share functionality coming soon'),
            isLargeScreen: isLargeScreen,
          ),
        ],
      ),
    );
  }

  bool get _hasMedia => post.mediaUrl?.isNotEmpty ?? false;

  Widget _buildPostContent(BuildContext context) {
    return Padding(
      padding: ResponsiveSpacing.content(context),
      child: Text(
        post.content,
        style: ResponsiveTextStyles.body(context),
      ),
    );
  }

  void _handleLike(PostProvider provider) {
    if (post.isLikedByCurrentUser) {
      provider.unlikePost(post.id);
    } else {
      provider.likePost(post.id);
    }
  }

  void _navigateToComments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          postId: post.id,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    // Use the LinkedIn aspect ratio (1.91:1) for post images
    // The width will be the container width, and the height will be calculated based on the aspect ratio
    final screenWidth = MediaQuery.of(context).size.width;
    final cardPadding = ResponsiveSpacing.card(context).horizontal;

    // Account for padding in the calculation to get the actual image width
    final imageWidth = screenWidth - cardPadding;

    // We don't need to set a height - the PostImage widget will calculate it based on the linkedinAspectRatio
    return PostImage(
      post: post,
      width: imageWidth,
    );
  }

  Widget _buildPostHeader(BuildContext context, bool isLargeScreen) {
    final hasAuthor = post.author != null;
    final hasAuthorId = post.authorId.isNotEmpty;

    return Padding(
      padding: ResponsiveSpacing.content(context),
      child: Row(
        children: [
          _buildAuthorAvatar(context, hasAuthor, hasAuthorId, isLargeScreen),
          SizedBox(width: ResponsiveSpacing.horizontal(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuthorName(context, hasAuthor, hasAuthorId),
                _buildPostTimestamp(context),
              ],
            ),
          ),
          _buildOptionsButton(context),
        ],
      ),
    );
  }

  Widget _buildAuthorAvatar(BuildContext context, bool hasAuthor,
      bool hasAuthorId, bool isLargeScreen) {
    if (hasAuthor) {
      return GestureDetector(
        onTap: () => _navigateToUserProfile(context),
        child: ProfileAvatar(
          user: post.author,
          displayName: post.author!.fullName,
          profilePictureUrl: post.author!.safeProfilePictureUrl,
          size: isLargeScreen ? 40 : 36,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAuthorName(
      BuildContext context, bool hasAuthor, bool hasAuthorId) {
    if (hasAuthor) {
      return GestureDetector(
        onTap: () => _navigateToUserProfile(context),
        child: Text(
          post.author!.fullName,
          style: ResponsiveTextStyles.title(context),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPostTimestamp(BuildContext context) {
    return Text(
      timeago.format(post.createdAt),
      style: ResponsiveTextStyles.caption(context),
    );
  }

  Widget _buildOptionsButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () => _showPostOptions(context),
    );
  }

  void _navigateToUserProfile(BuildContext context) {
    if (post.author != null) {
      Navigator.pushNamed(
        context,
        AppRouter.profile,
        arguments: post.author!.id,
      );
    }
  }

  void _showPostOptions(BuildContext context) {
    // Implementation for showing post options
  }
}
