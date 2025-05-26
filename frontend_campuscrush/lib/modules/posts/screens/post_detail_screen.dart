import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/post_provider.dart';
import '../models/post.dart';
import '../widgets/post_image.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
      ),
      body: FutureBuilder<Post?>(
        future:
            Provider.of<PostProvider>(context, listen: false).getPost(postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorView(context, snapshot.error.toString());
          }

          final post = snapshot.data;
          if (post == null) {
            return _buildNotFoundView(context);
          }

          return _buildPostDetails(context, post);
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String errorMessage) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading post',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(errorMessage),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Post not found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostDetails(BuildContext context, Post post) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorInfo(context, post),
          Text(post.content),
          if (post.mediaUrl != null) ...[
            const SizedBox(height: 16),
            _buildPostImage(post),
          ],
          const SizedBox(height: 16),
          _buildEngagementRow(post),
          const SizedBox(height: 16),
          Text(
            'Posted ${_formatTimeAgo(post.createdAt)}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorInfo(BuildContext context, Post post) {
    if (post.author == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.author!.fullName,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (post.author!.username.isNotEmpty)
          Text(
            '@${post.author!.username}',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPostImage(Post post) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: PostImage(
        post: post,
        height: 300,
      ),
    );
  }

  Widget _buildEngagementRow(Post post) {
    return Row(
      children: [
        _buildEngagementItem(
          icon: Icons.favorite,
          count: post.likeCount,
          isActive: post.isLikedByCurrentUser,
          activeColor: Colors.red,
        ),
        const SizedBox(width: 16),
        _buildEngagementItem(
          icon: Icons.comment,
          count: post.commentCount,
        ),
        const SizedBox(width: 16),
        _buildEngagementItem(
          icon: Icons.share,
          count: post.shareCount,
        ),
      ],
    );
  }

  Widget _buildEngagementItem({
    required IconData icon,
    required int count,
    bool isActive = false,
    Color activeColor = Colors.grey,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isActive ? activeColor : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text('$count'),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }
}
