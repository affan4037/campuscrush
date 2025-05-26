import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/api_service.dart';
import '../../../../widgets/error_widget.dart';
import '../../../../widgets/loading_widget.dart';
import '../models/comment.dart';
import '../providers/comments_provider.dart';
import '../services/comments_service.dart';
import '../../reactions/models/reaction.dart';
import '../../widgets/reaction_button.dart';

class CommentsScreen extends StatelessWidget {
  final String postId;
  final List<dynamic>? initialComments;

  const CommentsScreen({
    Key? key,
    required this.postId,
    this.initialComments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        final commentsService = CommentsService(
          apiService: apiService,
          authService: authService,
        );
        final provider = CommentsProvider(commentsService, authService);

        Future.microtask(() => _initializeComments(provider));
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comments'),
          elevation: 1,
        ),
        body: Column(
          children: [
            Expanded(child: _buildCommentsList()),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  void _initializeComments(CommentsProvider provider) {
    if (initialComments == null || initialComments!.isEmpty) {
      provider.initComments(postId);
      return;
    }

    final validComments = _parseInitialComments();
    if (validComments.isNotEmpty) {
      provider.setInitialComments(postId, validComments);
    } else {
      provider.initComments(postId);
    }
  }

  List<Comment> _parseInitialComments() {
    if (initialComments == null) return [];

    return initialComments!
        .where((comment) => comment != null)
        .map((comment) {
          try {
            if (comment is Comment) {
              return comment;
            } else if (comment is Map<String, dynamic>) {
              return Comment.safeFromJson(comment);
            }
            return null;
          } catch (_) {
            return null;
          }
        })
        .whereType<Comment>()
        .toList();
  }

  Widget _buildCommentsList() {
    return Consumer<CommentsProvider>(
      builder: (context, provider, _) {
        if (provider.status == CommentsStatus.loading &&
            provider.comments.isEmpty) {
          return const LoadingWidget();
        }

        if (provider.status == CommentsStatus.error) {
          return AppErrorWidget(
            message: provider.errorMessage,
            onRetry: () => provider.refreshComments(),
          );
        }

        if (provider.comments.isEmpty) {
          return const Center(
            child: Text('No comments yet. Be the first to comment!'),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (scrollInfo) {
            if (scrollInfo.metrics.pixels ==
                    scrollInfo.metrics.maxScrollExtent &&
                provider.hasMore &&
                provider.status != CommentsStatus.loadingMore) {
              provider.loadMoreComments();
            }
            return true;
          },
          child: RefreshIndicator(
            onRefresh: () => provider.refreshComments(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: provider.comments.length + (provider.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == provider.comments.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return CommentItem(comment: provider.comments[index]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Consumer<CommentsProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: provider.commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: provider.isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                color: AppColors.primary,
                onPressed: provider.isSubmitting
                    ? null
                    : () {
                        final commentText =
                            provider.commentController.text.trim();
                        if (commentText.isNotEmpty) {
                          provider.addComment();
                        }
                      },
              ),
            ],
          ),
        );
      },
    );
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;

  static final _smallTextStyle = TextStyle(
    color: Colors.grey[600],
    fontSize: 12,
  );

  const CommentItem({
    Key? key,
    required this.comment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CommentsProvider>(context);
    final isCurrentUser =
        Provider.of<AuthService>(context, listen: false).currentUser?.id ==
            comment.author.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommentBubble(),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Row(
                    children: [
                      _buildTimestamp(),
                      _buildReactionButton(provider),
                      _buildReplyButton(context),
                      const Spacer(),
                      if (isCurrentUser) _buildOptionsMenu(context, provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final fullName = comment.author.fullName;
    final firstChar = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final hasValidProfilePicture = comment.author.hasValidProfilePicture;
    final fallbackUrl = comment.author.fallbackAvatarUrl;

    return CircleAvatar(
      radius: 18.0,
      backgroundColor: Colors.grey[200],
      backgroundImage: hasValidProfilePicture
          ? NetworkImage(comment.author.safeProfilePictureUrl ??
              AppConstants.fixProfilePictureUrl(comment.author.profilePicture!))
          : (fallbackUrl.isNotEmpty ? NetworkImage(fallbackUrl) : null),
      child: !hasValidProfilePicture && fallbackUrl.isEmpty
          ? Text(
              firstChar,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            )
          : null,
    );
  }

  Widget _buildCommentBubble() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.author.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(comment.content),
        ],
      ),
    );
  }

  Widget _buildTimestamp() {
    return Row(
      children: [
        Text(
          timeago.format(comment.createdAt),
          style: _smallTextStyle,
        ),
        if (comment.isEdited) ...[
          const SizedBox(width: 4),
          Text('• Edited', style: _smallTextStyle),
        ],
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildReactionButton(CommentsProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        height: 24,
        width: 60,
        child: ReactionButton(
          isLiked: comment.hasLiked,
          currentReaction: comment.hasLiked ? ReactionType.like : null,
          onReactionSelected: (reactionType) =>
              provider.reactToComment(comment.id, reactionType),
          onReactionRemoved: () => provider.unlikeComment(comment.id),
        ),
      ),
    );
  }

  Widget _buildReplyButton(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply functionality coming soon!')),
        );
      },
      child: Text('Reply', style: _smallTextStyle),
    );
  }

  Widget _buildOptionsMenu(BuildContext context, CommentsProvider provider) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: Colors.grey[600],
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          provider.startEditingComment(comment);
          _showEditCommentBottomSheet(context, provider);
        } else if (value == 'delete') {
          _showDeleteCommentDialog(context, provider);
        }
      },
    );
  }

  void _showEditCommentBottomSheet(
      BuildContext context, CommentsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Comment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: provider.editCommentController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Edit your comment',
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      provider.cancelEditing();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _saveEditedComment(context, provider),
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveEditedComment(
      BuildContext context, CommentsProvider provider) async {
    final success = await provider.saveEditedComment();
    if (context.mounted) {
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment updated successfully')),
        );
      }
    }
  }

  void _showDeleteCommentDialog(
      BuildContext context, CommentsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteComment(context, provider),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(
      BuildContext context, CommentsProvider provider) async {
    Navigator.pop(context);
    final success = await provider.deleteComment(comment.id);
    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted successfully')),
      );
    }
  }
}
