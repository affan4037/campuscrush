import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_constants.dart';
import '../modules/user_management/models/user.dart';

/// A widget that displays a user's profile picture with proper cache handling.
/// This widget ensures that profile pictures are always up-to-date by applying
/// cache-busting techniques.
class ProfileAvatar extends StatefulWidget {
  /// The URL of the profile picture to display
  final String? profilePictureUrl;

  /// The user's display name or username, used for fallback initials
  final String displayName;

  /// The size of the avatar (radius)
  final double radius;

  /// Optional timestamp for cache-busting (will generate one automatically if not provided)
  final int? cacheVersion;

  /// Whether to show the camera icon for editing
  final bool showEditIcon;

  /// Callback when the avatar is tapped
  final VoidCallback? onTap;

  /// User object to get profile picture and name from
  final User? user;

  /// Whether to show a border around the avatar
  final bool showBorder;

  /// Alternative way to specify avatar size
  final double? size;

  const ProfileAvatar({
    Key? key,
    this.displayName = '',
    this.profilePictureUrl,
    this.radius = 50,
    this.cacheVersion,
    this.showEditIcon = false,
    this.onTap,
    this.user,
    this.showBorder = false,
    this.size,
  }) : super(key: key);

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _hasConnectionError = false;

  static const _cacheDuration = Duration(milliseconds: 300);
  static const _memCacheSize = 250;
  static const _editIconSize = 20.0;
  static const _errorIconSize = 16.0;
  static const _iconPadding = 4.0;
  static const _imagePlaceholderStrokeWidth = 2.0;

  @override
  void initState() {
    super.initState();
    if (widget.profilePictureUrl == null || widget.profilePictureUrl!.isEmpty) {
      _hasConnectionError = false;
    }
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profilePictureUrl != widget.profilePictureUrl ||
        oldWidget.cacheVersion != widget.cacheVersion) {
      setState(() {
        _hasConnectionError = false;
      });
    }
  }

  String get _imageUrl {
    final effectiveProfilePictureUrl =
        widget.user?.profilePicture ?? widget.profilePictureUrl;
    final effectiveDisplayName = widget.user?.fullName ?? widget.displayName;

    if (effectiveProfilePictureUrl == null ||
        effectiveProfilePictureUrl.isEmpty) {
      return AppConstants.getAvatarFallbackUrl(effectiveDisplayName);
    }

    if (effectiveProfilePictureUrl.contains(AppConstants.uiAvatarsBaseUrl)) {
      return effectiveProfilePictureUrl;
    }

    if (_isProfilePicturesPath(effectiveProfilePictureUrl)) {
      return _addCacheBusting(effectiveProfilePictureUrl);
    }

    if (_isLocalhostUrl(effectiveProfilePictureUrl)) {
      return _addCacheBusting(
          AppConstants.convertLocalhostUrl(effectiveProfilePictureUrl));
    }

    return _addCacheBusting(
        AppConstants.fixProfilePictureUrl(effectiveProfilePictureUrl));
  }

  bool _isProfilePicturesPath(String url) {
    return url.contains('/static/profile_pictures/') ||
        url.contains('/api/v1/static/profile_pictures/');
  }

  bool _isLocalhostUrl(String url) {
    return url.contains('localhost') || url.contains('127.0.0.1');
  }

  String _addCacheBusting(String url) {
    if (!url.contains('t=') && !url.contains('timestamp=')) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}t=$timestamp';
    }
    return url;
  }

  Widget _buildEditIcon(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(_iconPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.camera_alt,
          color: Colors.white,
          size: _editIconSize,
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Positioned(
      right: widget.showEditIcon ? 24 : 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(_iconPadding),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_outline,
          color: Colors.white,
          size: _errorIconSize,
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(
      double radius, String initial, Color backgroundColor) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDisplayName = widget.user?.fullName ?? widget.displayName;
    final effectiveInitial = effectiveDisplayName.isNotEmpty
        ? effectiveDisplayName[0].toUpperCase()
        : '?';
    final effectiveRadius =
        widget.size != null ? widget.size! / 2 : widget.radius;
    final effectiveProfilePictureUrl =
        widget.user?.profilePicture ?? widget.profilePictureUrl;
    final bool hasNoValidUrl = effectiveProfilePictureUrl == null ||
        effectiveProfilePictureUrl.isEmpty;

    // Show initials avatar when there's an error or no valid URL
    if (_hasConnectionError || hasNoValidUrl) {
      return _buildAvatarWithStack(
        _buildInitialsAvatar(
          effectiveRadius,
          effectiveInitial,
          _hasConnectionError
              ? Colors.red.shade400
              : Theme.of(context).primaryColor,
        ),
        effectiveRadius,
        effectiveInitial,
        showError: _hasConnectionError,
      );
    }

    // Use ClipOval with cached image for all other cases
    return _buildAvatarWithStack(
      ClipOval(
        child: _buildCachedImage(
          _imageUrl,
          effectiveRadius,
          effectiveInitial,
          context,
        ),
      ),
      effectiveRadius,
      effectiveInitial,
    );
  }

  Widget _buildAvatarWithStack(Widget child, double radius, String initial,
      {bool showError = false}) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          child,
          if (showError) _buildErrorIcon(),
          if (widget.showEditIcon) _buildEditIcon(context),
        ],
      ),
    );
  }

  CachedNetworkImage _buildCachedImage(
    String imageUrl,
    double radius,
    String initial,
    BuildContext context,
  ) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      fadeOutDuration: _cacheDuration,
      fadeInDuration: _cacheDuration,
      useOldImageOnUrlChange: false,
      memCacheWidth: _memCacheSize,
      memCacheHeight: _memCacheSize,
      cacheKey: 'profile_$imageUrl',
      httpHeaders: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
      placeholder: (context, url) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 77),
          child: const CircularProgressIndicator(
            strokeWidth: _imagePlaceholderStrokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      },
      errorWidget: (context, url, error) {
        if (mounted) {
          setState(() {
            _hasConnectionError = true;
          });
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.red.shade400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.white,
                size: radius * 0.6,
              ),
              const SizedBox(height: 2),
              Text(
                initial,
                style: TextStyle(
                  fontSize: radius * 0.5,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
