import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Utility class to manage image caching in the application.
class CacheManager {
  /// Private constructor to prevent instantiation
  CacheManager._();

  /// Clears all cached network images
  static Future<void> clearImageCache() async {
    try {
      debugPrint('Clearing all image caches...');
      await _clearAllCaches();
      debugPrint('Image cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing image cache: $e');
    }
  }

  /// Alias for clearImageCache to maintain backward compatibility
  static Future<void> clearAllImageCache() => clearImageCache();

  /// Clear cache for post media files
  static Future<void> clearPostMediaCache() async {
    try {
      debugPrint('Clearing post media cache...');

      await _clearFlutterCache();

      final tempDir = await getTemporaryDirectory();
      await _cleanCacheFiles(tempDir, _postMediaPatterns);
      await _clearCachedImageDirectory(tempDir);
      await _evictCachedNetworkImages();

      debugPrint('Post media cache cleared successfully');
    } catch (e) {
      debugPrint('Error clearing post media cache: $e');
    }
  }

  /// Helper method to get the base URL without query parameters
  static String _getBaseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
      ).toString();
    } catch (e) {
      debugPrint('Error parsing URL: $e');
      return url;
    }
  }

  /// Generate variations of a URL for comprehensive cache clearing
  static List<String> _generateUrlVariations(String baseUrl) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return [
      baseUrl,
      '$baseUrl?t=$timestamp',
      '$baseUrl?v=$timestamp',
      '$baseUrl?_=$timestamp'
    ];
  }

  /// Clean temp directory to resolve socket connection issues
  static Future<void> _cleanTempDirectory() async {
    try {
      final tempDir = await getTemporaryDirectory();
      await _cleanCacheFiles(tempDir, _generalCachePatterns);
      await _clearCachedImageDirectory(tempDir);
    } catch (e) {
      debugPrint('Error cleaning temporary directory: $e');
    }
  }

  /// Clear cache for a specific post's media
  static Future<void> clearPostMediaCacheForUrl(
      String? mediaUrl, String postId) async {
    if (mediaUrl == null || mediaUrl.isEmpty) return;

    try {
      debugPrint('Clearing cache for post media: $postId');

      await clearImageCacheForUrl(mediaUrl);

      final cacheKeys = [
        'post_media_$postId',
        'feed_media_$postId',
        'post_detail_$postId'
      ];

      await _clearKeysFromDefaultManager(cacheKeys);
      await _clearFlutterCache();

      debugPrint('Cache cleared for post media: $postId');
    } catch (e) {
      debugPrint('Error clearing post media cache for $postId: $e');
    }
  }

  static Future<int> _cleanCacheFiles(
      Directory directory, List<String> patterns) async {
    try {
      final files = directory.listSync();
      int deletedFiles = 0;

      for (final file in files) {
        if (file is File &&
            patterns.any((pattern) => file.path.contains(pattern))) {
          try {
            await file.delete();
            deletedFiles++;
          } catch (_) {
            // Silently ignore individual file deletion errors
          }
        }
      }

      return deletedFiles;
    } catch (e) {
      debugPrint('Error cleaning cache files: $e');
      return 0;
    }
  }

  static Future<void> _clearCachedImageDirectory(Directory tempDir) async {
    try {
      final cacheDir = Directory('${tempDir.path}/libCachedImageData');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error cleaning libCachedImageData: $e');
    }
  }

  /// Clears a specific image from the cache
  static Future<void> clearImageCacheForUrl(String url) async {
    if (url.isEmpty) return;

    try {
      debugPrint('Clearing image cache for: $url');

      final baseUrl = _getBaseUrl(url);
      final variations = _generateUrlVariations(baseUrl);

      await _clearSpecificUrls([url, ...variations]);
      await _clearFlutterCache();

      debugPrint('Cleared image cache for: $url');
    } catch (e) {
      debugPrint('Error clearing image cache for $url: $e');
    }
  }

  // Private implementation methods

  static Future<void> _clearAllCaches() async {
    await _clearFlutterCache();
    await DefaultCacheManager().emptyCache();
    await _cleanTempDirectory();
    await _evictCachedNetworkImages();
  }

  static Future<void> _clearFlutterCache() async {
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static Future<void> _evictCachedNetworkImages() async {
    try {
      await CachedNetworkImage.evictFromCache('');
    } catch (e) {
      debugPrint('Error evicting cached network images: $e');
    }
  }

  static Future<void> _clearSpecificUrls(List<String> urls) async {
    // Clear from CachedNetworkImage
    for (final url in urls) {
      _safeEvict(url);
    }

    // Clear from DefaultCacheManager
    await _clearKeysFromDefaultManager(urls);
  }

  static Future<void> _clearKeysFromDefaultManager(List<String> keys) async {
    final cacheManager = DefaultCacheManager();

    for (final key in keys) {
      try {
        await cacheManager.removeFile(key);
      } catch (_) {
        // Ignore errors for individual keys
      }
    }
  }

  /// Safely evict a URL from CachedNetworkImage
  static void _safeEvict(String url) {
    try {
      CachedNetworkImage.evictFromCache(url);
    } catch (_) {
      // Silent failure for individual URL evictions
    }
  }

  // Constants

  static const List<String> _postMediaPatterns = [
    'post_media',
    'post_detail_',
    'feed_media_',
    'static',
    'CachedNetworkImage',
    'libCache'
  ];

  static const List<String> _generalCachePatterns = [
    'cache',
    'image',
    'network'
  ];
}
