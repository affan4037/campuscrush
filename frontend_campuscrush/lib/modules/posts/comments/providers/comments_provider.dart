import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/comments_service.dart';
import '../../../../services/auth_service.dart';
import '../../reactions/models/reaction.dart';

enum CommentsStatus {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
}

class CommentsProvider extends ChangeNotifier {
  final CommentsService _commentsService;
  final AuthService _authService;

  String _postId = '';
  List<Comment> _comments = [];
  CommentsStatus _status = CommentsStatus.initial;
  String _errorMessage = '';
  bool _hasMore = true;
  int _currentSkip = 0;
  final int _limit = 20;
  String? _parentId;

  final TextEditingController commentController = TextEditingController();
  bool _isSubmitting = false;

  String? _editingCommentId;
  final TextEditingController editCommentController = TextEditingController();
  bool _isEditing = false;

  CommentsProvider(this._commentsService, this._authService);

  List<Comment> get comments => List.unmodifiable(_comments);
  CommentsStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoading =>
      _status == CommentsStatus.loading ||
      _status == CommentsStatus.loadingMore;
  String get postId => _postId;
  String? get parentId => _parentId;
  bool get isSubmitting => _isSubmitting;
  bool get isEditing => _isEditing;
  String? get editingCommentId => _editingCommentId;

  void setInitialComments(String postId, List<Comment> initialComments) {
    _postId = postId;
    _status = CommentsStatus.loaded;
    _comments = List.from(initialComments);
    _hasMore = initialComments.length >= _limit;
    _currentSkip = initialComments.length;
    notifyListeners();
  }

  Future<void> initComments(String postId, {String? parentId}) async {
    if (_status == CommentsStatus.loading) return;

    _resetState(postId, parentId);

    try {
      _validateUser();
      await _fetchComments();
    } catch (e) {
      _handleError(e, 'Failed to load comments');
    }

    notifyListeners();
  }

  Future<void> loadMoreComments() async {
    if (_status == CommentsStatus.loadingMore ||
        _status == CommentsStatus.loading ||
        !_hasMore) {
      return;
    }

    _status = CommentsStatus.loadingMore;
    notifyListeners();

    try {
      await _fetchComments(loadMore: true);
    } catch (e) {
      _handleError(e, 'Failed to load more comments');
    }

    notifyListeners();
  }

  Future<bool> addComment() async {
    final content = commentController.text.trim();
    if (content.isEmpty) return false;

    _isSubmitting = true;
    notifyListeners();

    try {
      await _authService.refreshUserProfile();

      final newComment = await _commentsService.addComment(
        _postId,
        content,
        parentId: _parentId,
      );

      _comments.insert(0, newComment);
      commentController.clear();
      return true;
    } catch (e) {
      _handleError(e, 'Failed to add comment');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void startEditingComment(Comment comment) {
    _editingCommentId = comment.id;
    editCommentController.text = comment.content;
    _isEditing = true;
    notifyListeners();
  }

  void cancelEditing() {
    _resetEditingState();
  }

  Future<bool> saveEditedComment() async {
    if (_editingCommentId == null) return false;

    final content = editCommentController.text.trim();
    if (content.isEmpty) return false;

    _isEditing = true;
    notifyListeners();

    try {
      final updatedComment = await _commentsService.editComment(
        _postId,
        _editingCommentId!,
        content,
      );

      _updateCommentInList(_editingCommentId!, updatedComment);
      _resetEditingState();
      return true;
    } catch (e) {
      _handleError(e, 'Failed to update comment');
      _isEditing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      final success = await _commentsService.deleteComment(_postId, commentId);

      if (success) {
        _comments.removeWhere((c) => c.id == commentId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      _handleError(e, 'Failed to delete comment');
      return false;
    }
  }

  Future<bool> reactToComment(
      String commentId, ReactionType reactionType) async {
    try {
      final success = await _commentsService.reactToComment(
          _postId, commentId, reactionType);

      if (success) {
        _updateCommentReaction(commentId, true);
      }

      return success;
    } catch (e) {
      _handleError(e, 'Failed to react to comment');
      return false;
    }
  }

  Future<bool> likeComment(String commentId) async {
    return reactToComment(commentId, ReactionType.like);
  }

  Future<bool> unlikeComment(String commentId) async {
    try {
      final success = await _commentsService.unlikeComment(_postId, commentId);

      if (success) {
        _updateCommentReaction(commentId, false);
      }

      return success;
    } catch (e) {
      _handleError(e, 'Failed to unlike comment');
      return false;
    }
  }

  Future<void> refreshComments() async {
    _currentSkip = 0;
    await initComments(_postId, parentId: _parentId);
  }

  Future<void> _fetchComments({bool loadMore = false}) async {
    final comments = await _commentsService.getComments(
      _postId,
      skip: _currentSkip,
      limit: _limit,
    );

    if (loadMore) {
      _comments.addAll(comments);
    } else {
      _comments = comments;
    }

    _hasMore = comments.length >= _limit;
    _status = CommentsStatus.loaded;
    _currentSkip += comments.length;
  }

  void _resetState(String postId, String? parentId) {
    _postId = postId;
    _parentId = parentId;
    _status = CommentsStatus.loading;
    _comments = [];
    _currentSkip = 0;
    _errorMessage = '';
    notifyListeners();
  }

  void _validateUser() {
    if (_authService.currentUser == null) {
      throw Exception('Please log in to view comments.');
    }
  }

  void _handleError(dynamic error, String prefix) {
    _status = CommentsStatus.error;

    if (error.toString().contains('type \'List<dynamic>\'')) {
      _errorMessage = 'Error parsing comments from server. Please try again.';
    } else {
      _errorMessage = '$prefix: ${error.toString()}';
    }
  }

  void _updateCommentInList(String commentId, Comment updatedComment) {
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index != -1) {
      _comments[index] = updatedComment;
      notifyListeners();
    }
  }

  void _updateCommentReaction(String commentId, bool hasLiked) {
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index != -1) {
      final comment = _comments[index];
      final newLikeCount = _calculateNewLikeCount(comment, hasLiked);

      _comments[index] = comment.copyWith(
        likeCount: newLikeCount,
        hasLiked: hasLiked,
      );
      notifyListeners();
    }
  }

  int _calculateNewLikeCount(Comment comment, bool hasLiked) {
    if (hasLiked) {
      return !comment.hasLiked ? comment.likeCount + 1 : comment.likeCount;
    } else {
      return comment.likeCount - 1;
    }
  }

  void _resetEditingState() {
    _editingCommentId = null;
    editCommentController.clear();
    _isEditing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    commentController.dispose();
    editCommentController.dispose();
    super.dispose();
  }
}
