import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/comments_service.dart';
import '../../reactions/models/reaction.dart';

class CommentProvider extends ChangeNotifier {
  final CommentsService _commentsService;

  // State variables
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isSubmitting = false;
  bool _isDeleting = false;

  // Data
  List<Comment> _replies = [];
  bool _hasMoreReplies = true;
  int _currentSkip = 0;
  final int _limit = 10;

  CommentProvider(this._commentsService);

  // Getters
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get isSubmitting => _isSubmitting;
  bool get isDeleting => _isDeleting;
  List<Comment> get replies => List.unmodifiable(_replies);
  bool get hasMoreReplies => _hasMoreReplies;

  // Fetch replies for a comment
  Future<void> fetchReplies(String postId, String commentId,
      {bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    if (refresh) {
      _resetRepliesState();
    }

    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final fetchedReplies = await _commentsService.getComments(
        postId,
        skip: _currentSkip,
        limit: _limit,
      );

      if (refresh) {
        _replies = fetchedReplies;
      } else {
        _replies.addAll(fetchedReplies);
      }

      _hasMoreReplies = fetchedReplies.length >= _limit;
      _currentSkip += fetchedReplies.length;
    } catch (e) {
      _setError('Failed to fetch replies: ${e.toString()}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load more replies
  Future<void> loadMoreReplies(String postId, String commentId) async {
    if (_isLoading || !_hasMoreReplies) return;

    await fetchReplies(postId, commentId);
  }

  // Add a reply to a comment
  Future<Comment?> addReply(
      String postId, String commentId, String content) async {
    if (content.trim().isEmpty) return null;

    return _executeCommentOperation(() async {
      final newReply = await _commentsService.addComment(
        postId,
        content,
        parentId: commentId,
      );

      _replies.insert(0, newReply);
      return newReply;
    }, 'Failed to add reply');
  }

  // Edit a reply
  Future<Comment?> editReply(
      String postId, String commentId, String content) async {
    if (content.trim().isEmpty) return null;

    return _executeCommentOperation(() async {
      final updatedReply = await _commentsService.editComment(
        postId,
        commentId,
        content,
      );

      _updateReplyInList(commentId, updatedReply);
      return updatedReply;
    }, 'Failed to edit reply');
  }

  // Delete a reply
  Future<bool> deleteReply(String postId, String commentId) async {
    _isDeleting = true;
    _clearError();
    notifyListeners();

    try {
      final success = await _commentsService.deleteComment(postId, commentId);

      if (success) {
        _replies.removeWhere((reply) => reply.id == commentId);
      }

      return success;
    } catch (e) {
      _setError('Failed to delete reply: ${e.toString()}');
      return false;
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  // Like a reply
  Future<bool> likeReply(String postId, String commentId) async {
    return _executeReactionOperation(
      postId,
      commentId,
      true,
      () =>
          _commentsService.reactToComment(postId, commentId, ReactionType.like),
      'Failed to like reply',
    );
  }

  // Unlike a reply
  Future<bool> unlikeReply(String postId, String commentId) async {
    return _executeReactionOperation(
      postId,
      commentId,
      false,
      () => _commentsService.unlikeComment(postId, commentId),
      'Failed to unlike reply',
    );
  }

  // Reset the provider state
  void reset() {
    _isLoading = false;
    _hasError = false;
    _errorMessage = '';
    _isSubmitting = false;
    _isDeleting = false;
    _resetRepliesState();
    notifyListeners();
  }

  // Helper methods
  void _resetRepliesState() {
    _replies = [];
    _currentSkip = 0;
    _hasMoreReplies = true;
  }

  void _clearError() {
    _hasError = false;
    _errorMessage = '';
  }

  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }

  Future<T?> _executeCommentOperation<T>(
      Future<T> Function() operation, String errorPrefix) async {
    _isSubmitting = true;
    _clearError();
    notifyListeners();

    try {
      final result = await operation();
      return result;
    } catch (e) {
      _setError('$errorPrefix: ${e.toString()}');
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> _executeReactionOperation(
    String postId,
    String commentId,
    bool hasLiked,
    Future<bool> Function() operation,
    String errorPrefix,
  ) async {
    try {
      final success = await operation();

      if (success) {
        _updateReplyReaction(commentId, hasLiked);
      }

      return success;
    } catch (e) {
      _setError('$errorPrefix: ${e.toString()}');
      return false;
    }
  }

  void _updateReplyInList(String commentId, Comment updatedReply) {
    final index = _replies.indexWhere((reply) => reply.id == commentId);
    if (index != -1) {
      _replies[index] = updatedReply;
      notifyListeners();
    }
  }

  void _updateReplyReaction(String commentId, bool hasLiked) {
    final index = _replies.indexWhere((reply) => reply.id == commentId);
    if (index != -1) {
      final reply = _replies[index];
      final newLikeCount = _calculateNewLikeCount(reply, hasLiked);

      _replies[index] = reply.copyWith(
        likeCount: newLikeCount,
        hasLiked: hasLiked,
      );
      notifyListeners();
    }
  }

  int _calculateNewLikeCount(Comment reply, bool hasLiked) {
    if (hasLiked) {
      return !reply.hasLiked ? reply.likeCount + 1 : reply.likeCount;
    } else {
      return reply.hasLiked ? reply.likeCount - 1 : reply.likeCount;
    }
  }
}
