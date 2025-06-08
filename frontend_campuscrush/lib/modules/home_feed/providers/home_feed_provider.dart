import 'package:flutter/material.dart';
import '../models/feed_item.dart';
import '../services/home_feed_service.dart';
import '../../../services/auth_service.dart';
import '../../posts/services/post_service.dart';
import '../../posts/comments/services/comments_service.dart';
import '../../posts/comments/models/comment.dart';

enum FeedStatus {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
}

enum ApiStatus {
  initial,
  loading,
  success,
  error,
}

class HomeFeedProvider extends ChangeNotifier {
  final HomeFeedService _homeFeedService;
  final AuthService _authService;
  final int _limit = 20;

  List<FeedItem> _feedItems = [];
  FeedStatus _status = FeedStatus.initial;
  String _errorMessage = '';
  bool _hasMore = true;
  int _currentSkip = 0;
  int _total = 0;

  HomeFeedProvider(this._homeFeedService, this._authService);

  // Public getters
  List<FeedItem> get feedItems => _feedItems;
  FeedStatus get status => _status;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get isLoading =>
      _status == FeedStatus.loading || _status == FeedStatus.loadingMore;
  String? get currentUserId => _authService.currentUser?.id;
  dynamic get currentUser => _authService.currentUser;
  int get total => _total;

  Future<void> initFeed() async {
    if (isLoading) return;
    _setLoadingState(true, clearItems: true);

    try {
      // Ensure proper token initialization and user profile
      final hasValidToken = await _authService.hasValidToken();
      if (!hasValidToken) {
        // Try to refresh token/profile before failing
        final refreshSuccess = await _authService.refreshUserProfile();
        if (!refreshSuccess) {
          throw Exception('Your session has expired. Please log in again.');
        }
      }

      // Double-check after refresh
      if (!await _authService.hasValidToken()) {
        throw Exception('Your session has expired. Please log in again.');
      }

      final isConnected = await _authService.checkServerConnectivity();
      if (!isConnected) {
        throw Exception(
            'Cannot connect to server. Please check your network connection and server status.');
      }

      await _fetchFeed(0);
      await _fetchLatestCommentsForItems();
      await _syncReactionsWithPostProvider();
    } catch (e) {
      _handleFeedError(e.toString());
    }
  }

  Future<void> _fetchFeed(int skip) async {
    final response = await _homeFeedService.getHomeFeed(
      skip: skip,
      limit: _limit,
    );

    if (skip == 0) {
      _feedItems = response.items;
    } else {
      _feedItems.addAll(response.items);
    }

    _total = response.total;
    _hasMore = response.hasMore;
    _currentSkip = skip + response.items.length;
    _status = FeedStatus.loaded;
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> _handleAuthErrors(BuildContext? context) async {
    final containsAuthError = _errorMessage.contains('session has expired') ||
        _errorMessage.contains('Please log in') ||
        _errorMessage.contains('Authentication required') ||
        _errorMessage.contains('Unauthorized') ||
        _errorMessage.contains('Forbidden');

    if (!containsAuthError) return;

    // Always log out and redirect to login if auth error is detected
    await _authService.logout();
    _errorMessage = 'Your session has expired. Please log in again.';
    notifyListeners();
    if (context != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
    }
  }

  void _handleFeedError(String error, {BuildContext? context}) {
    _status = FeedStatus.error;
    _errorMessage = error;
    _handleAuthErrors(context);
    notifyListeners();
  }

  void _setLoadingState(bool isLoading, {bool clearItems = false}) {
    if (isLoading) {
      _status = clearItems ? FeedStatus.loading : FeedStatus.loadingMore;
      if (clearItems) {
        _feedItems = [];
        _currentSkip = 0;
        _hasMore = true;
      }
      _errorMessage = '';
    } else {
      _status = FeedStatus.loaded;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoading || !_hasMore) return;

    _setLoadingState(true);

    try {
      await _authService.checkServerConnectivity();
      await _fetchFeed(_currentSkip);
    } catch (e) {
      _handleFeedError(e.toString());
    }
  }

  Future<void> refreshFeed() async {
    if (isLoading) return;

    _setLoadingState(true, clearItems: true);

    try {
      // Ensure proper token initialization and user profile
      final hasValidToken = await _authService.hasValidToken();
      if (!hasValidToken) {
        final refreshSuccess = await _authService.refreshUserProfile();
        if (!refreshSuccess) {
          throw Exception('Your session has expired. Please log in again.');
        }
      }

      if (!await _authService.hasValidToken()) {
        throw Exception('Your session has expired. Please log in again.');
      }

      final isConnected = await _authService.checkServerConnectivity();
      if (!isConnected) {
        throw Exception(
            'Cannot connect to server. Please check your network connection and server status.');
      }

      await _fetchFeed(0);
      await _fetchLatestCommentsForItems();
      await _syncReactionsWithPostProvider();
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _handleFeedError(e.toString());
    }
  }

  Future<void> reactToPost(String postId, String reactionType) async {
    try {
      await _homeFeedService.reactToPost(postId, reactionType);
      _updateFeedItemReaction(postId, reactionType, true);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeReaction(String postId) async {
    try {
      await _homeFeedService.removeReaction(postId);
      _updateFeedItemReaction(postId, null, false);

      try {
        final postProvider = _homeFeedService.getPostProvider();
        final currentReaction = postProvider.getReactionType(postId);
        if (currentReaction != null) {
          postProvider.forceRemoveReaction(postId);
        }
      } catch (e) {
        // Silently handle non-critical post provider sync error
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _updateFeedItemReaction(
      String postId, String? reactionType, bool hasReacted) {
    final index = _feedItems.indexWhere((item) => item.post.id == postId);
    if (index == -1) return;

    final item = _feedItems[index];
    int newReactionCount = item.reactionCount;

    if (hasReacted && !item.hasReacted) {
      newReactionCount++;
    } else if (!hasReacted && item.hasReacted) {
      newReactionCount = item.reactionCount > 0 ? item.reactionCount - 1 : 0;
    }

    _feedItems[index] = FeedItem(
      post: item.post.copyWith(
          isLikedByCurrentUser: hasReacted,
          currentUserReactionType: reactionType),
      author: item.author,
      commentCount: item.commentCount,
      reactionCount: newReactionCount,
      hasReacted: hasReacted,
      reactionType: reactionType,
      latestComment: item.latestComment,
    );

    notifyListeners();
  }

  Future<bool> deletePost(String postId) async {
    try {
      final postService = PostService(_homeFeedService.apiService);
      await postService.deletePost(postId);

      _feedItems.removeWhere((item) => item.post.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addComment(String postId, String content) async {
    try {
      _status = FeedStatus.loading;
      notifyListeners();

      // Refresh the current user profile first
      await _authService.refreshUserProfile();

      final commentService = _createCommentService();
      final newComment = await commentService.addComment(postId, content);

      _updateFeedItemWithNewComment(postId, newComment);
      _status = FeedStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _status = FeedStatus.error;
      notifyListeners();
      return false;
    }
  }

  CommentsService _createCommentService() {
    return CommentsService(
      apiService: _homeFeedService.apiService,
      authService: _homeFeedService.authService,
    );
  }

  void _updateFeedItemWithNewComment(String postId, Comment newComment) {
    final index = _feedItems.indexWhere((item) => item.post.id == postId);
    if (index == -1) return;

    // Ensure comment has valid author information
    final Comment commentWithAuthor = newComment.author.id == 'unknown-id' ||
            newComment.author.fullName == 'Unknown User'
        ? newComment.copyWith(author: _authService.currentUser!)
        : newComment;

    final item = _feedItems[index];
    _feedItems[index] = item.copyWith(
      commentCount: item.commentCount + 1,
      latestComment: commentWithAuthor,
    );
  }

  Future<void> fetchLatestComment(String postId) async {
    try {
      final commentService = _createCommentService();
      final latestComment = await commentService.getLatestComment(postId);

      final index = _feedItems.indexWhere((item) => item.post.id == postId);
      if (index != -1 && latestComment != null) {
        _feedItems[index] =
            _feedItems[index].copyWith(latestComment: latestComment);
        notifyListeners();
      }
    } catch (e) {
      // Silently handle non-critical comment fetching error
    }
  }

  Future<void> _fetchLatestCommentsForItems() async {
    if (_feedItems.isEmpty) return;

    try {
      final commentService = _createCommentService();

      for (int i = 0; i < _feedItems.length; i++) {
        final item = _feedItems[i];
        if (item.commentCount > 0) {
          final latestComment =
              await commentService.getLatestComment(item.post.id);
          if (latestComment != null) {
            _feedItems[i] = item.copyWith(latestComment: latestComment);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      // Silently handle non-critical batch comment fetching error
    }
  }

  Future<bool> toggleLikeOnComment(FeedItem item, Comment comment) async {
    try {
      final commentService = _createCommentService();
      final bool success =
          await commentService.toggleLikeComment(item.post.id, comment.id);

      if (success) {
        _updateCommentLikeStatus(item, comment);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _updateCommentLikeStatus(FeedItem item, Comment comment) {
    if (item.latestComment == null || item.latestComment!.id != comment.id) {
      return;
    }

    final index =
        _feedItems.indexWhere((feedItem) => feedItem.post.id == item.post.id);
    if (index == -1) return;

    final updatedComment = comment.copyWith(
      hasLiked: !comment.hasLiked,
      likeCount:
          comment.hasLiked ? comment.likeCount - 1 : comment.likeCount + 1,
    );

    _feedItems[index] =
        _feedItems[index].copyWith(latestComment: updatedComment);
    notifyListeners();
  }

  Future<void> _syncReactionsWithPostProvider() async {
    try {
      final postProvider = _homeFeedService.getPostProvider();

      for (final item in _feedItems) {
        if (item.hasReacted && item.reactionType != null) {
          postProvider.syncReactionTypeFromFeed(
              item.post.id, item.reactionType!);
        }
      }
    } catch (e) {
      // Silently handle non-critical reaction sync error
    }
  }
}
