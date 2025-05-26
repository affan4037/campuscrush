import 'dart:io';
import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../core/utils/form_data_helper.dart';
import '../models/post.dart';

class PostService {
  final ApiService _apiService;

  String get postsEndpoint => '${AppConstants.apiPrefix}/posts';
  String get healthEndpoint => AppConstants.healthEndpoint;

  PostService(this._apiService);

  Future<FormData> _createPostFormData({
    required String content,
    File? media,
  }) async {
    final Map<String, dynamic> fields = {'content': content};
    final Map<String, File>? files = media != null ? {'media': media} : null;

    return FormDataHelper.create(
      fields: fields,
      files: files,
    );
  }

  Future<Post> createPost({
    required String content,
    File? mediaFile,
    int redirectCount = 0,
    bool hasTrailingSlash = false,
  }) async {
    try {
      if (redirectCount > 3) {
        throw Exception('Too many redirects (max: 3)');
      }

      _checkAndUpdateBaseUrl();

      // Ensure token is valid before making post request
      await _apiService.ensureValidToken();

      // Check for redirects before sending the main request
      final needsTrailingSlash = await _checkForRedirects(postsEndpoint);
      final endpointToUse = hasTrailingSlash || needsTrailingSlash
          ? '$postsEndpoint/'
          : postsEndpoint;

      // Create form data for the request
      final formData = await _createPostFormData(
        content: content,
        media: mediaFile,
      );

      // Send the request using the uploadFile method
      final response = await _apiService.uploadFile<Map<String, dynamic>>(
        endpointToUse,
        formData: formData,
      );

      // Handle redirects
      if (_isRedirectResponse(response)) {
        return await _handleRedirect(
            response, content, mediaFile, redirectCount + 1);
      }

      if (!response.isSuccess || response.data == null) {
        throw Exception('Failed to create post: ${response.error}');
      }

      // Parse and return the created post
      return Post.fromJson(response.data!);
    } catch (e) {
      throw Exception('Error creating post: ${e.toString()}');
    }
  }

  void _checkAndUpdateBaseUrl() {
    if ((Platform.isAndroid || Platform.isIOS) &&
        (_apiService.baseUrl.contains('localhost') ||
            _apiService.baseUrl.contains('127.0.0.1') ||
            _apiService.baseUrl.contains('10.0.2.2'))) {
      _apiService.updateBaseUrl(AppConstants.baseUrl);
    }
  }

  bool _isRedirectResponse(ApiResponse response) {
    return response.extra != null &&
        response.extra!.containsKey('isRedirect') &&
        response.extra!['isRedirect'] == true;
  }

  Future<Post> _handleRedirect(
    ApiResponse<Map<String, dynamic>> response,
    String content,
    File? mediaFile,
    int redirectCount,
  ) async {
    final redirectUrl = response.extra!['redirectLocation'] as String?;
    if (redirectUrl == null) {
      throw Exception('Redirect URL was null');
    }

    // Update base URL if needed
    if (response.extra!.containsKey('newBaseUrl')) {
      final newBaseUrl = response.extra!['newBaseUrl'] as String?;
      if (newBaseUrl != null && newBaseUrl != _apiService.baseUrl) {
        _apiService.updateBaseUrl(newBaseUrl);
      }
    }

    // Process the redirect path
    final redirectPath = _processRedirectPath(redirectUrl);

    // Create new form data and send the request
    final newFormData = await _createPostFormData(
      content: content,
      media: mediaFile,
    );

    final redirectResponse = await _apiService.uploadFile<Map<String, dynamic>>(
      redirectPath,
      formData: newFormData,
    );

    if (!redirectResponse.isSuccess || redirectResponse.data == null) {
      throw Exception(
          'Failed to create post after redirect: ${redirectResponse.error}');
    }

    return Post.fromJson(redirectResponse.data!);
  }

  String _processRedirectPath(String redirectUrl) {
    String redirectPath;

    if (redirectUrl.startsWith('http')) {
      // For absolute URLs, use the path portion
      final uri = Uri.parse(redirectUrl);
      redirectPath = uri.path;
    } else {
      // For relative URLs, use as is but ensure it has the API prefix
      redirectPath = redirectUrl;
      if (!redirectPath.startsWith('/')) {
        redirectPath = '/$redirectPath';
      }
    }

    // Make sure redirectPath starts with the API prefix
    const apiPrefix = AppConstants.apiPrefix;
    if (!redirectPath.startsWith(apiPrefix)) {
      if (redirectPath.startsWith('/')) {
        // Check if this is a path that might need the API prefix
        if (redirectPath.contains('/posts') ||
            redirectPath.contains('/users') ||
            redirectPath.contains('/auth') ||
            redirectPath.contains('/comments')) {
          redirectPath = '$apiPrefix$redirectPath';
        }
      } else {
        // If there's no leading slash, add the API prefix with a slash
        redirectPath = '$apiPrefix/$redirectPath';
      }
    }

    return redirectPath;
  }

  Future<bool> _checkForRedirects(String endpoint) async {
    try {
      final response = await _apiService.headRequest(
        endpoint,
        headers: {
          'Accept': 'application/json',
          if (_apiService.hasAuthToken)
            'Authorization': 'Bearer ${_apiService.authToken}',
        },
        followRedirects: false,
      );

      // Handle redirect status codes
      if ([301, 302, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value('location');
        if (location != null) {
          final redirectUrl = location;
          final hasTrailingSlash = redirectUrl.endsWith('/');

          try {
            if (redirectUrl.startsWith('http')) {
              final redirectUri = Uri.parse(redirectUrl);
              final newBaseUrl =
                  '${redirectUri.scheme}://${redirectUri.host}:${redirectUri.port}';
              final currentUri = Uri.parse(_apiService.baseUrl);

              // Update base URL only if host, port or scheme has changed
              if (redirectUri.host != currentUri.host ||
                  redirectUri.port != currentUri.port ||
                  redirectUri.scheme != currentUri.scheme) {
                _apiService.updateBaseUrl(newBaseUrl);
              }
            }
          } catch (e) {
            // Error parsing redirect URL, continue with current URL
          }

          return hasTrailingSlash;
        }
      }

      // No redirect or no trailing slash needed
      return endpoint.endsWith('/');
    } catch (e) {
      // Continue with the request even if redirect check fails
      return false;
    }
  }

  Future<Post> getPost(String postId) async {
    try {
      final ApiResponse<Map<String, dynamic>> response =
          await _apiService.get<Map<String, dynamic>>(
        '${AppConstants.apiPrefix}/posts/$postId',
      );

      if (response.isSuccess && response.data != null) {
        return Post.fromJson(response.data!);
      } else {
        throw Exception('Failed to get post: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error fetching post: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      final ApiResponse<dynamic> response = await _apiService.delete<dynamic>(
        '${AppConstants.apiPrefix}/posts/$postId',
      );

      if (!response.isSuccess) {
        throw Exception('Failed to delete post: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error deleting post: $e');
    }
  }

  Future<List<Post>> getUserPosts(String userId,
      {int skip = 0, int limit = 20}) async {
    final endpoint =
        '${AppConstants.apiPrefix}/users/$userId/posts?skip=$skip&limit=$limit';

    try {
      final response = await _apiService.get<dynamic>(endpoint);

      if (!response.isSuccess || response.data == null) {
        return [];
      }

      if (response.data is List) {
        final List<dynamic> postsJson = response.data as List<dynamic>;
        return _processPostsList(postsJson);
      } else if (response.data is Map) {
        return _extractPostsFromMap(response.data as Map<String, dynamic>);
      }

      return [];
    } catch (e) {
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  List<Post> _extractPostsFromMap(Map<String, dynamic> data) {
    // Common response formats for post lists
    final possibleKeys = ['items', 'posts', 'data', 'results'];

    for (final key in possibleKeys) {
      if (data.containsKey(key) && data[key] is List) {
        return _processPostsList(data[key] as List<dynamic>);
      }
    }

    return [];
  }

  List<Post> _processPostsList(List<dynamic> postsJson) {
    final List<Post> posts = [];

    for (final postJson in postsJson) {
      try {
        // Skip invalid entries
        if (postJson == null || postJson is! Map) {
          continue;
        }

        final Map<String, dynamic> postMap = postJson as Map<String, dynamic>;

        // Validate required fields
        if (postMap['id'] == null ||
            postMap['content'] == null ||
            postMap['author_id'] == null) {
          continue;
        }

        // Ensure author is a valid Map or null
        if (postMap.containsKey('author') &&
            postMap['author'] != null &&
            postMap['author'] is! Map) {
          postMap['author'] = null;
        }

        final post = Post.fromJson(postMap);
        posts.add(post);
      } catch (e) {
        // Skip posts that fail to parse
        continue;
      }
    }

    return posts;
  }

  Future<String> getValidServerUrl() async {
    try {
      // Try the current base URL first
      final currentUrl = _apiService.baseUrl;

      if (await _isValidUrl(currentUrl)) {
        return currentUrl;
      }

      // Try fallback URLs
      for (final url in AppConstants.fallbackBaseUrls) {
        if (url != currentUrl && await _isValidUrl(url)) {
          return url;
        }
      }

      // If all checks fail, use the current URL as fallback
      return currentUrl;
    } catch (e) {
      return _apiService.baseUrl;
    }
  }

  Future<bool> _isValidUrl(String url) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
        validateStatus: (status) => true,
      ));

      final response = await dio
          .get(
            '$url$healthEndpoint',
            options: Options(
              headers: {
                'Accept': 'application/json',
                if (_apiService.hasAuthToken)
                  'Authorization': 'Bearer ${_apiService.authToken}',
              },
            ),
          )
          .timeout(const Duration(seconds: 2));

      // Consider 2xx, 3xx and 401 as valid responses
      final statusCode = response.statusCode ?? 0;
      return statusCode < 400 || statusCode == 401;
    } catch (e) {
      return false;
    }
  }

  Future<List<Post>> getPosts({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      // Validate token before request
      await _apiService.ensureValidToken();

      final response = await _apiService.get<dynamic>(
        '$postsEndpoint?skip=$skip&limit=$limit',
        validateTokenFirst: true,
      );

      if (response.isSuccess && response.data != null) {
        final posts = _extractPostsFromResponse(response.data);
        return posts;
      } else if (response.statusCode == 500) {
        // Handle server-side validation errors
        return [];
      } else {
        throw Exception('Failed to fetch posts: ${response.error}');
      }
    } catch (e) {
      throw Exception('Error fetching posts: $e');
    }
  }

  List<Post> _extractPostsFromResponse(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => Post.fromJson(json))
          .toList();
    } else if (data is Map<String, dynamic>) {
      // Check for different response formats
      if (data.containsKey('items') && data['items'] is List) {
        return (data['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map((json) => Post.fromJson(json))
            .toList();
      } else if (data.containsKey('posts') && data['posts'] is List) {
        return (data['posts'] as List)
            .whereType<Map<String, dynamic>>()
            .map((json) => Post.fromJson(json))
            .toList();
      }
    }

    // Default empty list if format doesn't match
    return [];
  }
}
