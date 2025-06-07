import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Application-wide constants and utility methods for URL handling and connectivity
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // App info
  static const String appName = 'Campus Crush';
  static const String appVersion = '1.0.0';

  // API configuration
  static const String baseUrl = "https://campuscrush-sb89.onrender.com";
  static const List<String> fallbackBaseUrls = [
    'http://192.168.0.101:8000',
    'http://10.1.32.212:8000',
  ];
  static const bool enableNetworkLogging = true;
  static const String apiPrefix = '/api/v1';

  // API endpoints
  static const String loginEndpoint = '$apiPrefix/auth/login';
  static const String registerEndpoint = '$apiPrefix/auth/register';
  static const String userProfileEndpoint = '$apiPrefix/users/me';
  static const String profilePictureEndpoint =
      '$apiPrefix/users/profile-picture';
  static const String deleteUserEndpoint = '$apiPrefix/auth/delete-user';
  static const String postsEndpoint = '$apiPrefix/posts';
  static const String commentsBasePath = '$apiPrefix/posts';
  static const String reactionsBasePath = '$apiPrefix/posts';
  static const String friendshipsEndpoint = '$apiPrefix/friends';
  static const String notificationsEndpoint = '$apiPrefix/notifications';
  static const String homeFeedEndpoint = '$apiPrefix/feed';
  static const String healthEndpoint = '$apiPrefix/users/me';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String verifiedBaseUrlKey = 'verified_base_url';
  static const String urlPatternKey = 'preferred_url_pattern';
  static const String urlPatternCountsKey = 'url_pattern_counts';

  // Validation
  static const int minPasswordLength = 8;
  static const String emailRegex =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double defaultBorderRadius = 8.0;
  static const double defaultElevation = 2.0;

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 800);

  // Image handling
  static const String uiAvatarsBaseUrl = 'https://ui-avatars.com/api/';
  static const String defaultAvatarBackgroundColor = 'random';
  static const String defaultAvatarTextColor = 'fff';
  static const int defaultAvatarSize = 256;
  static const String defaultUserName = 'User';

  // URL patterns for static content
  static const String r2DirectUrl = 'R2_DIRECT_URL';
  static const String r2ProxyUrl = 'R2_PROXY_URL';
  static const String directUploadsWithCategory =
      'DIRECT_UPLOADS_WITH_CATEGORY';
  static const String apiStaticWithCategory = 'API_STATIC_WITH_CATEGORY';
  static const String directUploadsRoot = 'DIRECT_UPLOADS_ROOT';
  static const String apiStaticRoot = 'API_STATIC_ROOT';
  static const String staticPath = '/static/';
  static const String apiStaticPath = '/api/v1/static/';
  static const String mediaPath = '/api/v1/media/';
  static const String profilePicturesPath = 'profile_pictures';
  static const String uploadsPath = '/uploads/';

  // R2 configuration
  static const String r2PublicUrl =
      "https://pub-8c92ccf4152c44e9bd5c2cc3fc8b774d.r2.dev";

  // Network constants
  static const int connectTimeoutSeconds = 5;
  static const int redirectTimeoutSeconds = 3;
  static const int defaultPort = 8000;
  static const List<int> standardPorts = [80, 443];
  static const List<int> _redirectStatusCodes = [301, 302, 307, 308];
  static const List<String> commonServerIps = [
    '192.168.0.101',
    '10.1.32.212',
    '192.168.10.2',
    '192.168.10.4',
    '192.168.10.8',
    '10.0.2.2',
  ];

  // URL query parameters
  static const String timestampParameter = 't';
  static const String timestampFullParameter = 'timestamp';

  // Cache for preferred URL pattern
  static String? _cachedPreferredPattern;

  /// Checks if a URL is a localhost URL that will have connection issues on mobile
  static bool isLocalUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    if (url.contains(staticPath) ||
        url.contains(apiStaticPath) ||
        url.contains(profilePicturesPath)) {
      return false;
    }

    return commonServerIps.any((pattern) => url.contains(pattern));
  }

  /// Checks if a profile picture URL actually exists and is usable
  static bool isProfilePictureValid(String? url) {
    if (url == null || url.isEmpty) return false;

    // Check for R2 URLs
    if (url.startsWith(r2PublicUrl) || url.contains(mediaPath)) {
      return true;
    }

    if (url.contains('$staticPath$profilePicturesPath/') ||
        url.contains('$apiStaticPath$profilePicturesPath/')) {
      return true;
    }

    if (url.startsWith(baseUrl) &&
        (url.contains('profile') || url.contains('pictures'))) {
      return true;
    }

    if (url.contains(uiAvatarsBaseUrl)) {
      return true;
    }

    if (isLocalUrl(url)) {
      return false;
    }

    return url.startsWith('http');
  }

  /// Generates a fallback avatar URL
  static String getAvatarFallbackUrl(String name,
      {String backgroundColor = defaultAvatarBackgroundColor}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeDisplayName = name.isNotEmpty ? name : defaultUserName;
    final encodedName = Uri.encodeComponent(safeDisplayName);

    return '$uiAvatarsBaseUrl?name=$encodedName&background=$backgroundColor&color=$defaultAvatarTextColor&size=$defaultAvatarSize&$timestampParameter=$timestamp';
  }

  /// Extracts base URL (scheme, host, port) from a full URL
  static String extractBaseUrl(String fullUrl) {
    try {
      final uri = Uri.parse(fullUrl);
      final bool isStandardPort = standardPorts.contains(uri.port);
      return '${uri.scheme}://${uri.host}${isStandardPort ? '' : ':${uri.port}'}';
    } catch (e) {
      debugPrint('Error extracting base URL from $fullUrl: $e');
      return fullUrl;
    }
  }

  /// Adds timestamp to URL for cache busting
  static String addTimestampToUrl(String url) {
    if (url.contains('$timestampParameter=') ||
        url.contains('$timestampFullParameter=')) {
      return url;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final separator = url.contains('?') ? '&' : '?';
    return '$url$separator$timestampParameter=$timestamp';
  }

  /// Converts a localhost URL to an actual server URL
  static String convertLocalhostUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (commonServerIps.any((pattern) => url.contains(pattern))) {
      try {
        final uri = Uri.parse(url);
        String newUrl = '$baseUrl${uri.path}';

        if (uri.hasQuery) {
          newUrl += '?${uri.query}';
        }

        return addTimestampToUrl(newUrl);
      } catch (e) {
        final baseUrlDomain = baseUrl.split('://')[1];
        return url
            .replaceAll('localhost:$defaultPort', baseUrlDomain)
            .replaceAll('127.0.0.1:$defaultPort', baseUrlDomain)
            .replaceAll('10.0.2.2:$defaultPort', baseUrlDomain);
      }
    }

    return url;
  }

  /// Fixes profile picture URLs to use the current baseUrl
  static String fixProfilePictureUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (isLocalUrl(url)) {
      return convertLocalhostUrl(url);
    }

    if (url.startsWith(baseUrl)) {
      return url;
    }

    try {
      final uri = Uri.parse(url);

      if ((url.contains(apiPrefix) || url.contains(staticPath)) &&
          url.contains(profilePicturesPath)) {
        String newUrl = '$baseUrl${uri.path}';

        if (uri.hasQuery) {
          newUrl += '?${uri.query}';
        }

        return newUrl;
      }
    } catch (e) {
      debugPrint('Error fixing profile picture URL: $e');
    }

    return url;
  }

  /// Gets the most valid server URL by checking connectivity
  static Future<String> getValidServerUrl() async {
    String bestUrl = baseUrl;
    int bestResponseTime = -1;

    final List<Future<Map<String, dynamic>>> checks = [];
    checks.add(_checkServerUrl(baseUrl));

    for (final String url in fallbackBaseUrls) {
      if (url != baseUrl) {
        checks.add(_checkServerUrl(url));
      }
    }

    try {
      final results = await Future.wait(checks);

      for (final result in results) {
        final url = result['url'] as String;
        final isValid = result['isValid'] as bool;
        final responseTime = result['responseTime'] as int;

        if (isValid &&
            (bestResponseTime == -1 || responseTime < bestResponseTime)) {
          bestResponseTime = responseTime;
          bestUrl = url;
        }
      }
    } catch (e) {
      debugPrint('Error getting valid server URL: $e');
    }

    return bestUrl;
  }

  /// Creates URL for accessing an image from the backend using the most reliable method
  static String createImageUrl(String filename, {String? category}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final categoryPath = category != null ? '$category/' : '';
    final preferredPattern = _cachedPreferredPattern;

    switch (preferredPattern) {
      case r2DirectUrl:
        // Direct R2 URL using the R2 public endpoint
        return '$r2PublicUrl/$categoryPath$filename?$timestampParameter=$timestamp';
      case r2ProxyUrl:
        // Proxy through our backend to R2
        return '$baseUrl$mediaPath$categoryPath$filename?$timestampParameter=$timestamp';
      case directUploadsWithCategory:
        return '$baseUrl$uploadsPath$categoryPath$filename?$timestampParameter=$timestamp';
      case apiStaticWithCategory:
        return '$baseUrl$apiPrefix$staticPath$categoryPath$filename?$timestampParameter=$timestamp';
      case directUploadsRoot:
        return '$baseUrl$uploadsPath$filename?$timestampParameter=$timestamp';
      case apiStaticRoot:
        return '$baseUrl$apiPrefix$staticPath$filename?$timestampParameter=$timestamp';
      default:
        // Default to R2 proxy if no saved preference (safest option)
        return '$baseUrl$apiPrefix$staticPath$categoryPath$filename?$timestampParameter=$timestamp';
    }
  }

  /// Initialize URL patterns from storage - call this at app startup
  static Future<void> initializeUrlPatterns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPreferredPattern = prefs.getString(urlPatternKey);
      if (kDebugMode) {
        debugPrint('Initialized image URL pattern: $_cachedPreferredPattern');
      }
    } catch (e) {
      debugPrint('Failed to initialize URL patterns: $e');
    }
  }

  /// Saves a successful URL pattern for future use
  static Future<void> savePreferredUrlPattern(String pattern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPreferredPattern = pattern;
      await prefs.setString(urlPatternKey, pattern);

      final Map<String, int> counts = {};
      final countsJson = prefs.getString(urlPatternCountsKey);
      if (countsJson != null && countsJson.isNotEmpty) {
        try {
          final decodedJson = json.decode(countsJson);
          if (decodedJson is Map) {
            counts.addAll(Map<String, int>.from(decodedJson.map((key, value) =>
                MapEntry(key.toString(), value is int ? value : 0))));
          }
        } catch (e) {
          debugPrint('Error parsing URL pattern counts: $e');
        }
      }

      counts[pattern] = (counts[pattern] ?? 0) + 1;
      await prefs.setString(urlPatternCountsKey, json.encode(counts));
      if (kDebugMode) {
        debugPrint('Saved preferred URL pattern: $pattern');
      }
    } catch (e) {
      debugPrint('Failed to save preferred URL pattern: $e');
    }
  }

  /// Checks if a specific server URL is valid and reachable
  static Future<Map<String, dynamic>> _checkServerUrl(String url) async {
    final stopwatch = Stopwatch()..start();
    bool isValid = false;
    String resultUrl = url;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: connectTimeoutSeconds),
      receiveTimeout: const Duration(seconds: connectTimeoutSeconds),
      validateStatus: (status) => true,
    ));

    try {
      final response = await dio
          .get(
            '$url$healthEndpoint',
            options: Options(
              headers: {'Accept': 'application/json'},
              followRedirects: false,
            ),
          )
          .timeout(const Duration(seconds: connectTimeoutSeconds));

      final statusCode = response.statusCode ?? 0;
      isValid = (statusCode >= 200 && statusCode < 300) || statusCode == 401;

      if (!isValid &&
          _redirectStatusCodes.contains(statusCode) &&
          response.headers.value('location') != null) {
        final redirectUrl = response.headers.value('location') ?? '';
        if (redirectUrl.isEmpty) {
          isValid = false;
          stopwatch.stop();
          return {
            'url': resultUrl,
            'isValid': isValid,
            'responseTime': stopwatch.elapsedMilliseconds,
          };
        }

        if (redirectUrl.startsWith('http')) {
          final redirectBaseUrl = extractBaseUrl(redirectUrl);
          final redirectResponse = await dio
              .get(
                '$redirectBaseUrl$healthEndpoint',
                options: Options(
                  headers: {'Accept': 'application/json'},
                  followRedirects: false,
                ),
              )
              .timeout(const Duration(seconds: redirectTimeoutSeconds));

          final redirectStatusCode = redirectResponse.statusCode ?? 0;
          isValid = (redirectStatusCode >= 200 && redirectStatusCode < 300) ||
              redirectStatusCode == 401;

          if (isValid) {
            final originalUri = Uri.parse(url);
            final redirectUri = Uri.parse(redirectBaseUrl);

            if (originalUri.host != redirectUri.host ||
                originalUri.port != redirectUri.port ||
                originalUri.scheme != redirectUri.scheme) {
              resultUrl = redirectBaseUrl;
            }

            stopwatch.stop();
            return {
              'url': resultUrl,
              'isValid': true,
              'responseTime': stopwatch.elapsedMilliseconds,
            };
          }
        } else {
          isValid = true;
        }
      }
    } catch (e) {
      isValid = false;
    }

    stopwatch.stop();
    return {
      'url': resultUrl,
      'isValid': isValid,
      'responseTime': stopwatch.elapsedMilliseconds,
    };
  }

  /// Creates a URL with a different IP but keeping the same path
  static String createUrlWithDifferentIp(String originalUrl, String newIp) {
    try {
      final uri = Uri.parse(originalUrl);
      final port = uri.port == 0 ? defaultPort : uri.port;
      return '${uri.scheme}://$newIp:$port${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    } catch (e) {
      debugPrint('Error creating URL with different IP: $e');
      return originalUrl;
    }
  }
}
