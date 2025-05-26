import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../models/feed_item.dart';
import '../providers/home_feed_provider.dart';
import '../../posts/providers/post_provider.dart';
import '../../posts/widgets/post_footer.dart';
import '../../posts/widgets/post_image.dart';
import '../../posts/reactions/models/reaction.dart';

class FeedItemWidget extends StatefulWidget {
  final FeedItem item;

  const FeedItemWidget({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  State<FeedItemWidget> createState() => _FeedItemWidgetState();
}

class _FeedItemWidgetState extends State<FeedItemWidget> {
  bool _isCommentInputVisible = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncReactionState();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _syncReactionState() {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    if (widget.item.hasReacted && widget.item.reactionType != null) {
      // Parse the reaction type string to the enum value
      final reactionType = _parseReactionType(widget.item.reactionType!);
      if (reactionType != null) {
        postProvider.syncReactionTypeFromFeed(
            widget.item.post.id, widget.item.reactionType!);
      }
    } else if (!widget.item.hasReacted) {
      // Make sure reaction is removed if feed shows no reaction
      postProvider.forceRemoveReaction(widget.item.post.id);
    }
  }

  ReactionType? _parseReactionType(String typeStr) {
    try {
      for (var type in ReactionType.values) {
        if (type.toString().split('.').last.toLowerCase() ==
            typeStr.toLowerCase()) {
          return type;
        }
      }
    } catch (e) {
      debugPrint('Error parsing reaction type: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.item.post.content.isNotEmpty) _buildContent(),
          if (widget.item.post.mediaUrl != null) _buildMedia(),
          if (widget.item.commentCount > 0 || widget.item.reactionCount > 0)
            const Divider(),
          _buildFooter(context),
          if (widget.item.commentCount > 0) _buildLatestCommentPreview(context),
          if (_isCommentInputVisible) _buildCommentInput(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAuthorName(),
                const SizedBox(height: 2),
                Text(
                  '@${widget.item.author.username} · ${timeago.format(widget.item.post.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showPostOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        widget.item.post.content,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: _navigateToProfile,
      child: widget.item.author.hasValidProfilePicture
          ? CircleAvatar(
              radius: 20,
              backgroundImage:
                  NetworkImage(widget.item.author.safeProfilePictureUrl!),
            )
          : CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              backgroundImage: NetworkImage(
                  '${AppConstants.uiAvatarsBaseUrl}?name=${Uri.encodeComponent(widget.item.author.fullName)}&background=random&t=${DateTime.now().millisecondsSinceEpoch}'),
              child: widget.item.author.fullName.isEmpty
                  ? const Text(
                      '?',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
    );
  }

  Widget _buildAuthorName() {
    return GestureDetector(
      onTap: _navigateToProfile,
      child: Text(
        widget.item.author.fullName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).pushNamed(
      AppRouter.profile,
      arguments: widget.item.author.id,
    );
  }

  Widget _buildMedia() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: PostImage(post: widget.item.post),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return PostFooter(
      postId: widget.item.post.id,
      likeCount: widget.item.reactionCount,
      commentCount: widget.item.commentCount,
      shareCount: 0,
      isLiked: widget.item.hasReacted,
      onLike: _handleLikeAction,
      onComment: _handleCommentAction,
      onShare: () => _showMessage(context, 'Share functionality coming soon'),
    );
  }

  void _handleLikeAction() {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final hasReaction =
        postProvider.getReactionType(widget.item.post.id) != null ||
            widget.item.hasReacted;

    // If the post already has any reaction, remove it
    if (hasReaction) {
      postProvider.unlikePost(widget.item.post.id);
    } else {
      // Default to like reaction
      postProvider.reactToPost(widget.item.post.id, ReactionType.like);
    }
  }

  void _handleCommentAction() {
    if (widget.item.commentCount > 0) {
      _navigateToComments();
    } else {
      setState(() {
        _isCommentInputVisible = !_isCommentInputVisible;
      });

      if (!_isCommentInputVisible) {
        _commentController.clear();
      }
    }
  }

  void _navigateToComments() {
    Navigator.of(context).pushNamed(
      AppRouter.comments,
      arguments: {
        'postId': widget.item.post.id,
        'initialComments': [],
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showPostOptions(BuildContext context) {
    final feedProvider = Provider.of<HomeFeedProvider>(context, listen: false);
    final isCurrentUser = widget.item.author.id == feedProvider.currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentUser) ...[
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Post'),
              onTap: () {
                Navigator.pop(context);
                _showMessage(context, 'Edit functionality coming soon');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Post',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, feedProvider);
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Report Post'),
            onTap: () {
              Navigator.pop(context);
              _showMessage(context, 'Report functionality coming soon');
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, HomeFeedProvider feedProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deletePost(context, feedProvider),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(
      BuildContext context, HomeFeedProvider feedProvider) async {
    Navigator.pop(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Deleting post...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final success = await feedProvider.deletePost(widget.item.post.id);
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              success ? 'Post deleted successfully' : 'Failed to delete post'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCommentInput(BuildContext context) {
    final feedProvider = Provider.of<HomeFeedProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          _buildUserAvatar(feedProvider),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: _isSubmittingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _isSubmittingComment
                ? null
                : () => _submitComment(context, feedProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(HomeFeedProvider feedProvider) {
    final currentUser = feedProvider.currentUser;
    final hasValidProfilePicture = currentUser?.hasValidProfilePicture ?? false;
    final fullName = currentUser?.fullName ?? 'User';
    final fallbackUrl = currentUser?.fallbackAvatarUrl ??
        AppConstants.getAvatarFallbackUrl(fullName);

    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[200],
      backgroundImage: hasValidProfilePicture
          ? NetworkImage(currentUser!.safeProfilePictureUrl!)
          : NetworkImage(fallbackUrl),
      child: null, // No need for initials since we always have a fallback image
    );
  }

  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  Future<void> _submitComment(
      BuildContext context, HomeFeedProvider feedProvider) async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      final success = await feedProvider.addComment(
        widget.item.post.id,
        comment,
      );

      if (!mounted) return;

      if (success) {
        _commentController.clear();
        setState(() {
          _isCommentInputVisible = false;
          _isSubmittingComment = false;
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Comment added')),
        );
      } else {
        _showErrorMessage(scaffoldMessenger, 'Failed to add comment');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage(scaffoldMessenger, 'Error: $e');
    }
  }

  void _showErrorMessage(
      ScaffoldMessengerState scaffoldMessenger, String message) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
    if (mounted) {
      setState(() {
        _isSubmittingComment = false;
      });
    }
  }

  Widget _buildLatestCommentPreview(BuildContext context) {
    final hasLatestComment = widget.item.latestComment != null;

    return InkWell(
      onTap: _navigateToComments,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hasLatestComment
                ? _buildCommentAuthorAvatar()
                : _buildCommentCountBadge(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommentText(context, hasLatestComment),
                  if (widget.item.commentCount > 1 && hasLatestComment)
                    _buildViewAllCommentsText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentAuthorAvatar() {
    final author = widget.item.latestComment!.author;
    final hasValidProfilePicture = author.hasValidProfilePicture;
    final fallbackUrl = author.fallbackAvatarUrl;

    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey[200],
      backgroundImage: hasValidProfilePicture
          ? NetworkImage(author.safeProfilePictureUrl!)
          : (fallbackUrl.isNotEmpty ? NetworkImage(fallbackUrl) : null),
      child: !hasValidProfilePicture && fallbackUrl.isEmpty
          ? Text(
              _getInitial(author.fullName),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            )
          : null,
    );
  }

  Widget _buildCommentCountBadge() {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Text(
        widget.item.commentCount.toString(),
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCommentText(BuildContext context, bool hasLatestComment) {
    if (hasLatestComment) {
      return RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text:
                  widget.item.latestComment?.author.fullName ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ' '),
            TextSpan(text: widget.item.latestComment?.content ?? ''),
          ],
        ),
      );
    } else {
      return Text(
        'View all ${widget.item.commentCount} comments',
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      );
    }
  }

  Widget _buildViewAllCommentsText() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'View all ${widget.item.commentCount} comments',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }
}
