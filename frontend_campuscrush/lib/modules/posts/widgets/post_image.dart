import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'dart:async';

import '../models/post.dart';
import '../providers/post_provider.dart';
import '../../../core/utils/cache_manager.dart';
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.post.mediaUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }
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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: widget.width ?? double.infinity,
              height: calculatedHeight,
              cacheKey: 'post_media_${widget.post.id}',
              placeholder: (context, url) => _buildLoadingIndicator(),
              errorWidget: (context, url, error) => _buildErrorPlaceholder(),
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
              color: Colors.black.withValues(alpha: 77),
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
    });

    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      await CacheManager.clearPostMediaCacheForUrl(
          widget.post.mediaUrl, widget.post.id);
      await postProvider.refreshPost(widget.post.id);
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
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
