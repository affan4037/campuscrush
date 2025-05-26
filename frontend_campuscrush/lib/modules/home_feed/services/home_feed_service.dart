import 'package:dio/dio.dart';
import '../models/feed_response.dart';
import '../models/feed_item.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import '../../posts/models/post.dart';
import '../../user_management/models/user.dart';
import 'package:get_it/get_it.dart';
import '../../posts/services/post_service.dart';
import '../../posts/providers/post_provider.dart';

class HomeFeedService {
  final ApiService _apiService;
  final AuthService _authService;

  final List<String> _validReactionTypes = [
    "like",
    "love",
    "haha",
    "wow",
    "sad",
    "angry"
  ];

  HomeFeedService(this._apiService, this._authService);

  // Getter for apiService so it can be accessed by the provider
  ApiService get apiService => _apiService;

  // Getter for authService
  AuthService get authService => _authService;

  // Method to get access to a PostProvider instance
  // This is needed for reaction sync across providers
  PostProvider getPostProvider() {
    // Use GetIt if available, otherwise create a new instance
    try {
      if (GetIt.instance.isRegistered<PostProvider>()) {
        return GetIt.instance<PostProvider>();
      }
    } catch (e) {
      debugPrint(
          '⚠️ GetIt not available for PostProvider, creating new instance');
    }

    // Create a new instance with the same services
    return PostProvider(
      postService: PostService(_apiService),
      apiService: _apiService,
    );
  }

  Future<FeedResponse> getHomeFeed({int skip = 0, int limit = 10}) async {
    try {
      debugPrint('🔄 Fetching home feed: skip=$skip, limit=$limit');

      // First try to load the token from storage if it's not already set
      if (!_apiService.hasAuthToken) {
        await _apiService.ensureValidToken();
      }

      // Check again after loading from storage
      if (!_apiService.hasAuthToken) {
        // Instead of throwing immediately, try to refresh the token one more time
        await _authService.refreshUserProfile();

        // If still no token, then throw the error
        if (!_apiService.hasAuthToken) {
          throw Exception('Authentication required. Please log in.');
        }
      }

      // Try with and without trailing slash if needed
      String endpoint = '${AppConstants.apiPrefix}/feed';

      try {
        return await _fetchFeed(endpoint, skip, limit);
      } catch (e) {
        return await _retryGetHomeFeed(skip: skip, limit: limit);
      }
    } catch (e) {
      debugPrint('❌ Error fetching home feed: $e');
      throw Exception('Error fetching home feed: $e');
    }
  }

  Future<FeedResponse> _fetchFeed(String endpoint, int skip, int limit) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '$endpoint?skip=$skip&limit=$limit',
      validateTokenFirst: true,
    );

    if (response.isSuccess && response.data != null) {
      return _processFeedResponse(response.data!);
    } else if (response.statusCode == 404) {
      // If 404, try with trailing slash
      debugPrint('⚠️ Feed endpoint 404, trying with trailing slash');
      final retryResponse = await _apiService.get<Map<String, dynamic>>(
        '$endpoint/?skip=$skip&limit=$limit',
      );

      if (retryResponse.isSuccess && retryResponse.data != null) {
        return _processFeedResponse(retryResponse.data!);
      } else {
        throw Exception('Failed to fetch home feed: ${retryResponse.error}');
      }
    } else {
      // Check for specific errors like server connection
      if (response.error != null) {
        if (_isConnectionError(response.error!)) {
          // Try to get the feed with a different base URL
          debugPrint('⚠️ Connection issue, trying fallback...');
          return await _retryGetHomeFeed(skip: skip, limit: limit);
        } else if (_isAuthError(response.error!)) {
          throw Exception('Please log in to view your feed.');
        }
      }

      throw Exception('Failed to fetch home feed: ${response.error}');
    }
  }

  bool _isConnectionError(String error) {
    return error.contains('Connection') ||
        error.contains('network') ||
        error.contains('timeout');
  }

  bool _isAuthError(String error) {
    return error.contains('Could not validate credentials') ||
        error.contains('Authentication required');
  }

  // Helper method to process feed response data
  FeedResponse _processFeedResponse(Map<String, dynamic> data) {
    // Parse response into FeedResponse model
    if (data.containsKey('items') && data['items'] is List) {
      return FeedResponse.fromJson(data);
    } else if (data.containsKey('posts') && data['posts'] is List) {
      // Convert old format to new format if needed
      final List<dynamic> postsJson = data['posts'];
      final bool hasMore = data['has_more'] ?? data['hasMore'] ?? false;
      final int total = data['total'] ?? postsJson.length;

      // Create equivalent FeedResponse
      return FeedResponse(
          items: postsJson.map((json) => _createFeedItem(json)).toList(),
          total: total,
          hasMore: hasMore);
    } else {
      throw Exception('Invalid response format');
    }
  }

  // Helper method to create a FeedItem from a post JSON
  FeedItem _createFeedItem(Map<String, dynamic> postJson) {
    final Post post = Post.fromJson(postJson);
    final User author =
        postJson.containsKey('author') && postJson['author'] is Map
            ? User.fromJson(postJson['author'])
            : User(
                id: post.authorId,
                username: '',
                email: '',
                fullName: 'Unknown',
                university: 'Unknown',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

    return FeedItem(
      post: post,
      author: author,
      commentCount: postJson['comment_count'] ?? 0,
      reactionCount: postJson['reaction_count'] ?? 0,
      hasReacted: postJson['has_reacted'] ?? false,
      reactionType: postJson['reaction_type'],
    );
  }

  Future<FeedResponse> _retryGetHomeFeed({int skip = 0, int limit = 10}) async {
    // Try with fallback URLs
    for (final url in AppConstants.fallbackBaseUrls) {
      if (url != _apiService.baseUrl) {
        try {
          debugPrint('🔄 Retrying with fallback URL: $url');
          _apiService.updateBaseUrl(url);

          final retryResponse = await _apiService.get<Map<String, dynamic>>(
            '${AppConstants.apiPrefix}/feed?skip=$skip&limit=$limit',
          );

          if (retryResponse.isSuccess && retryResponse.data != null) {
            final Map<String, dynamic> data = retryResponse.data!;
            // Parse response into FeedResponse model
            if (data.containsKey('items') && data['items'] is List) {
              return FeedResponse.fromJson(data);
            } else if (data.containsKey('posts') && data['posts'] is List) {
              // Convert old format to new format if needed
              final List<dynamic> postsJson = data['posts'];
              final bool hasMore = data['has_more'] ?? data['hasMore'] ?? false;
              final int total = data['total'] ?? postsJson.length;

              // Create equivalent FeedResponse
              return FeedResponse(
                  items:
                      postsJson.map((json) => _createFeedItem(json)).toList(),
                  total: total,
                  hasMore: hasMore);
            }
          }
        } catch (e) {
          debugPrint('❌ Fallback URL failed: $e');
          continue;
        }
      }
    }

    throw Exception('Failed to fetch home feed with all available URLs');
  }

  Future<void> reactToPost(String postId, String reactionType) async {
    try {
      final String normalizedType = reactionType.toLowerCase();
      final String finalReactionType =
          _validReactionTypes.contains(normalizedType)
              ? normalizedType
              : "like";

      if (finalReactionType != reactionType) {
        debugPrint(
            '⚠️ Normalized reaction type from "$reactionType" to "$finalReactionType"');
      }

      // Use the reactions path constant with the postId
      final endpoint = '${AppConstants.reactionsBasePath}/$postId/reactions';
      debugPrint('🔄 Trying to react to post with endpoint: $endpoint');

      // Get the auth token from _apiService
      final authToken = _apiService.authToken;
      debugPrint(
          '🔑 Using auth token: ${authToken != null ? "✅ Token exists" : "❌ No token"}');

      // Create options with proper headers
      final options = Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'Bearer $authToken',
        },
      );

      // Try all possible payload formats in sequence until one works
      await _tryReactionFormats(endpoint, postId, finalReactionType, options);
    } catch (e) {
      debugPrint('❌ Error reacting to post: $e');
      throw Exception('Error reacting to post: $e');
    }
  }

  Future<void> _tryReactionFormats(String endpoint, String postId,
      String reactionType, Options options) async {
    final payloads = [
      {'reaction_type': reactionType, 'post_id': postId},
      {'reaction_type': reactionType},
      {'type': reactionType}
    ];

    for (var payload in payloads) {
      try {
        final response = await _apiService.post<Map<String, dynamic>>(
          endpoint,
          data: payload,
          options: options,
        );

        if (response.isSuccess) {
          return;
        }

        // Only try alternative formats if we get specific error codes
        if (response.statusCode != 403 && response.statusCode != 422) {
          throw Exception('Failed to react to post: ${response.error}');
        }
      } catch (e) {
        // Continue to next payload format on specific errors
        if (e is! DioException) {
          rethrow;
        }

        final statusCode = e.response?.statusCode;
        if (statusCode != 403 && statusCode != 422) {
          rethrow;
        }
      }
    }

    throw Exception('Failed to react to post after trying all payload formats');
  }

  Future<void> removeReaction(String postId) async {
    try {
      // Use the reactions path constant with the postId
      final endpoint = '${AppConstants.reactionsBasePath}/$postId/reactions';
      debugPrint('🔄 Trying to remove reaction with endpoint: $endpoint');

      // Get the auth token from _apiService
      final authToken = _apiService.authToken;
      debugPrint(
          '🔑 Using auth token for removal: ${authToken != null ? "✅ Token exists" : "❌ No token"}');

      if (authToken == null || authToken.isEmpty) {
        debugPrint('❌ Cannot remove reaction: No auth token available');
        throw Exception('Authentication required to remove reaction');
      }

      // Create options with proper headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

      final options = Options(
        headers: headers,
      );

      // Log detailed request information
      debugPrint('📤 HOMEFEED_DELETE | Post ID: $postId | Headers: $headers');

      // Check if the request URL is correctly formatted
      // Display different parts of the URL for debugging
      final baseUrl = _apiService.baseUrl;
      final fullUrl = '$baseUrl$endpoint';
      debugPrint('🌐 API Base URL: $baseUrl');
      debugPrint('🌐 Endpoint path: $endpoint');
      debugPrint('🌐 Full URL: $fullUrl');

      // Attempt to delete the reaction
      debugPrint('📡 Sending DELETE request to: $endpoint');
      final response = await _apiService.delete<Map<String, dynamic>>(
        endpoint,
        options: options,
      );

      // Log the API response
      debugPrint(
          '📥 HOMEFEED_DELETE | Status: ${response.statusCode} | Post ID: $postId');
      if (response.isSuccess) {
        debugPrint('✅ HOMEFEED_DELETE successful for post $postId');
      } else {
        debugPrint('❌ HOMEFEED_DELETE failed: ${response.error}');
      }

      // Log detailed response information
      debugPrint('📥 Response status code: ${response.statusCode}');

      // Consider both 200 OK and 404 Not Found as "success" for deletion
      // 404 means the reaction doesn't exist (which achieves the same end goal)
      if (response.isSuccess || response.statusCode == 404) {
        String successMessage = response.isSuccess
            ? "✅ Successfully deleted reaction for post $postId"
            : "✅ No reaction found to delete (404) - considering this a success";
        debugPrint(successMessage);

        // Operation considered successful regardless
        return;
      } else {
        debugPrint(
            '❌ Failed to remove reaction with status: ${response.statusCode}');
        debugPrint('❌ Error message: ${response.error}');

        // For errors other than 404, throw an exception
        throw Exception('Failed to remove reaction: ${response.error}');
      }
    } catch (e) {
      debugPrint('❌ Error in HOMEFEED_DELETE for post $postId: $e');
      debugPrint('❌ Error removing reaction: $e');
      throw Exception('Error removing reaction: $e');
    }
  }
}
