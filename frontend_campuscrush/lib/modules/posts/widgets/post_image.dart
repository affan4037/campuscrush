import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../models/post.dart';
import '../providers/post_provider.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/constants/app_constants.dart';
import '../widgets/full_screen_image_viewer.dart';

// LinkedIn uses approximately a 1.91:1 aspect ratio for post images
const double linkedinAspectRatio = 1.91;

class PostImage extends StatefulWidget {
  final Post post;
  final double? height;
  final double? width;

  const PostImage({
    Key? key,
    required this.post,
    this.height,
    this.width,
  }) : super(key: key);

  @override
  State<PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<PostImage> {
  bool _isRefreshing = false;
  bool _hasError = false;
  String? _workingUrl;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _findWorkingImageUrl();
  }

  Future<void> _findWorkingImageUrl() async {
    if (widget.post.mediaUrl == null) return;

    try {
      final originalUrl = widget.post.cachedMediaUrl;
      if (originalUrl == null) return;

      String? filename =
          _extractFilename(originalUrl) ?? widget.post.mediaFilename;

      final optimizedUrl = filename != null
          ? AppConstants.createImageUrl(filename, category: 'post_media')
          : originalUrl;

      try {
        final response = await _dio
            .head(
              optimizedUrl,
              options: Options(
                receiveTimeout: const Duration(seconds: 2),
                sendTimeout: const Duration(seconds: 2),
                validateStatus: (status) => true,
              ),
            )
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => Response(
                requestOptions: RequestOptions(path: optimizedUrl),
                statusCode: 408,
                statusMessage: 'Timeout',
              ),
            );

        if (response.statusCode == 200) {
          String pattern = _identifyUrlPattern(optimizedUrl);
          await AppConstants.savePreferredUrlPattern(pattern);

          if (mounted) {
            setState(() {
              _workingUrl = optimizedUrl;
              _hasError = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasError = true;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  String? _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
    } catch (e) {
      debugPrint('Error parsing URL: $e');
    }
    return null;
  }

  String _identifyUrlPattern(String url) {
    if (url.contains('/uploads/post_media/')) {
      return "DIRECT_UPLOADS_WITH_CATEGORY";
    } else if (url.contains('/uploads/')) {
      return "DIRECT_UPLOADS_ROOT";
    } else if (url.contains('/api/v1/static/post_media/')) {
      return "API_STATIC_WITH_CATEGORY";
    } else if (url.contains('/api/v1/static/')) {
      return "API_STATIC_ROOT";
    }
    return "UNKNOWN";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.mediaUrl == null || widget.post.mediaUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final imageUrl = _workingUrl ?? widget.post.cachedMediaUrl!;
    final screenWidth = MediaQuery.of(context).size.width;
    final calculatedHeight =
        widget.height ?? (screenWidth / linkedinAspectRatio);

    return GestureDetector(
      onTap: () => _openFullScreenView(context, imageUrl),
      onLongPress: _refreshImage,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _hasError
                ? _buildErrorPlaceholder()
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: widget.width ?? double.infinity,
                    height: calculatedHeight,
                    cacheKey: 'post_media_${widget.post.id}',
                    placeholder: (context, url) => _buildLoadingIndicator(),
                    errorWidget: (context, url, error) {
                      debugPrint('Error loading image: $url - $error');
                      Future.microtask(() {
                        if (mounted) {
                          setState(() {
                            _hasError = true;
                          });
                        }
                      });
                      return _buildErrorPlaceholder();
                    },
                    httpHeaders: const {
                      'Cache-Control': 'no-cache, no-store, must-revalidate',
                      'Pragma': 'no-cache',
                      'Expires': '0',
                    },
                    maxWidthDiskCache: 1280,
                    maxHeightDiskCache: 720,
                    memCacheWidth: 800,
                    memCacheHeight: 600,
                  ),
          ),
          if (_isRefreshing)
            Container(
              width: widget.width ?? double.infinity,
              height: calculatedHeight,
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullScreenView(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          heroTag: 'post_media_${widget.post.id}',
        ),
      ),
    );
  }

  Future<void> _refreshImage() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _workingUrl = null;
    });

    try {
      await _findWorkingImageUrl();
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      await CacheManager.clearPostMediaCacheForUrl(
          widget.post.mediaUrl, widget.post.id);

      await postProvider.refreshPost(widget.post.id);

      if (!mounted) return;

      setState(() {
        _isRefreshing = false;
        _hasError = false;
      });

      _showSuccessMessage('Image refreshed');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isRefreshing = false;
      });

      _showErrorMessage('Failed to refresh: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    final calculatedHeight =
        widget.height ?? (screenWidth / linkedinAspectRatio);

    return Container(
      width: widget.width ?? double.infinity,
      height: calculatedHeight,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }
}
