import 'package:flutter/material.dart';
import '../services/post_service.dart';
import '../models/post.dart';
import '../../../services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/cache_manager.dart';
import '../reactions/models/reaction.dart';
import 'package:dio/dio.dart' show Options;

class PostProvider extends ChangeNotifier {
  final PostService _postService;
  final ApiService _apiService;

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Cache for posts that have been loaded
  final Map<String, Post> _postsCache = {};

  // Track current reaction types for posts
  final Map<String, ReactionType> _postReactionTypes = {};

  PostProvider({
    required PostService postService,
    required ApiService apiService,
  })  : _postService = postService,
        _apiService = apiService;

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  // Get the current reaction type for a post
  ReactionType? getReactionType(String postId) {
    return _postReactionTypes[postId];
  }

  // Force remove any reaction for a post (for syncing with HomeFeedProvider)
  void forceRemoveReaction(String postId) {
    _postReactionTypes.remove(postId);
    _updatePostCache(postId, false, null, decrementCount: false);
    notifyListeners();
  }

  // Method to manually sync reaction data from feed
  void syncReactionTypeFromFeed(String postId, String reactionTypeStr) {
    // Only proceed if we don't already have a reaction for this post
    if (_postReactionTypes.containsKey(postId)) return;

    final reactionType = _parseReactionTypeFromString(reactionTypeStr);
    if (reactionType != null) {
      _postReactionTypes[postId] = reactionType;
      _updatePostCache(postId, true, reactionTypeStr);
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(bool hasError, String message) {
    _hasError = hasError;
    _errorMessage = message;
    notifyListeners();
  }

  // React to a post with a specific reaction type
  Future<void> reactToPost(String postId, ReactionType reactionType) async {
    try {
      _setLoading(true);

      // Check if this is the same reaction we already have
      final currentReaction = _postReactionTypes[postId];
      if (currentReaction == reactionType) {
        // If trying to add the same reaction, remove it instead
        return unlikePost(postId);
      }

      // Store the previous reaction type if any
      final previousReactionType = _postReactionTypes[postId];
      final isUpdating = previousReactionType != null;

      // Update the reaction type immediately for responsive UI
      _postReactionTypes[postId] = reactionType;
      notifyListeners();

      // Create reaction type string from enum
      final reactionTypeStr = reactionType.toString().split('.').last;
      final endpoint = '${AppConstants.reactionsBasePath}/$postId/reactions';

      // Send the reaction to the API
      final response = await _apiService.post(
        endpoint,
        data: {'reaction_type': reactionTypeStr, 'post_id': postId},
      );

      if (response.isSuccess) {
        // Update the local cache if the post exists
        _updatePostCache(postId, true, reactionTypeStr,
            incrementCount: !isUpdating);
        _setError(false, '');
      } else {
        // Revert the reaction type if there was an error
        _revertReaction(postId, previousReactionType);
        _setError(true, 'Failed to react to post: ${response.error}');
      }
    } catch (e) {
      // Revert the reaction type if there was an error
      _postReactionTypes.remove(postId);
      _setError(true, 'Failed to react to post: ${e.toString()}');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Like a post (convenience method for common reaction)
  Future<void> likePost(String postId) async {
    return reactToPost(postId, ReactionType.like);
  }

  // Unlike a post - removes any reaction type (not just Like)
  Future<void> unlikePost(String postId) async {
    try {
      _setLoading(true);

      // Store the previous reaction for rollback if needed
      final previousReaction = _postReactionTypes[postId];

      // Remove the reaction type from our tracking map
      _postReactionTypes.remove(postId);
      notifyListeners();

      final endpoint = '${AppConstants.reactionsBasePath}/$postId/reactions';

      // Add explicit headers to ensure proper DELETE request
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        method: 'DELETE',
      );

      // Call the API to remove the reaction
      final response = await _apiService.delete(
        endpoint,
        options: options,
      );

      // Consider 404 as success for DELETE (already removed)
      final isSuccess = response.isSuccess || response.statusCode == 404;

      if (isSuccess) {
        // Update the local cache if the post exists
        _updatePostCache(postId, false, null, decrementCount: true);
        _setError(false, '');
      } else {
        // Revert the removal if the API call failed
        _revertReaction(postId, previousReaction);
        _setError(true, 'Failed to remove reaction: ${response.error}');
      }
    } catch (e) {
      // Safety check - make sure the reaction is removed even if there's an error
      _postReactionTypes.remove(postId);
      _setError(true, 'Failed to remove reaction: ${e.toString()}');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Get a post by ID
  Future<Post?> getPost(String postId) async {
    try {
      _setLoading(true);

      // Check if we have it cached
      if (_postsCache.containsKey(postId)) {
        return _postsCache[postId];
      }

      // Otherwise fetch it
      final post = await _postService.getPost(postId);

      // Cache the post
      _postsCache[postId] = post;

      // Check if post has reaction and update our tracking
      if (post.isLikedByCurrentUser && post.currentUserReactionType != null) {
        final reactionType =
            _parseReactionTypeFromString(post.currentUserReactionType!);
        if (reactionType != null) {
          _postReactionTypes[postId] = reactionType;
        }
      } else {
        _postReactionTypes.remove(postId);
      }

      _setError(false, '');
      return post;
    } catch (e) {
      _setError(true, 'Failed to get post: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Helper method to consistently update the post cache
  void _updatePostCache(
    String postId,
    bool isLiked,
    String? reactionType, {
    bool incrementCount = false,
    bool decrementCount = false,
  }) {
    if (_postsCache.containsKey(postId)) {
      final post = _postsCache[postId]!;

      int newLikeCount = post.likeCount;
      if (incrementCount) {
        newLikeCount += 1;
      } else if (decrementCount && newLikeCount > 0) {
        newLikeCount -= 1;
      }

      _postsCache[postId] = post.copyWith(
        likeCount: newLikeCount,
        isLikedByCurrentUser: isLiked,
        currentUserReactionType: reactionType,
      );
    }
  }

  // Helper method to revert reaction changes on error
  void _revertReaction(String postId, ReactionType? previousReaction) {
    if (previousReaction != null) {
      _postReactionTypes[postId] = previousReaction;
    } else {
      _postReactionTypes.remove(postId);
    }
  }

  // Helper method to parse reaction type from string
  ReactionType? _parseReactionTypeFromString(String reactionTypeStr) {
    try {
      for (var type in ReactionType.values) {
        if (type.toString().split('.').last.toLowerCase() ==
            reactionTypeStr.toLowerCase()) {
          return type;
        }
      }
    } catch (e) {
      debugPrint('Error parsing reaction type: $e');
    }
    return null;
  }

  // Method to refresh post data and clear image cache
  Future<Post?> refreshPost(String postId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // First, get the current cached post
      final cachedPost = _postsCache[postId];

      // Clear the image cache if this post has media
      if (cachedPost?.mediaUrl != null) {
        await CacheManager.clearPostMediaCacheForUrl(
            cachedPost!.mediaUrl, postId);
      }

      // Fetch the post data from the server
      final response = await _postService.getPost(postId);

      // Update the cache
      _postsCache[postId] = response;

      // Clear the image cache again with the fresh URL
      if (response.mediaUrl != null) {
        await CacheManager.clearPostMediaCacheForUrl(
            response.mediaUrl, postId);
      }

      notifyListeners();
      return response;
    
      
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Error refreshing post: $e';
      notifyListeners();
      return _postsCache[postId];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
