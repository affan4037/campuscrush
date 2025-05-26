import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// Temporarily removed image_cropper due to build issues
// import 'package:image_cropper/image_cropper.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../services/api_service.dart';
import 'user_api_service.dart';

class ProfilePictureService {
  final ApiService _apiService;

  ProfilePictureService(this._apiService);

  /// Picks an image from gallery for profile picture
  Future<File?> pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image selected. Cropping feature coming soon.'),
        duration: Duration(seconds: 2),
      ),
    );

    return File(image.path);
  }

  /// Clears cached images when profile picture is updated
  Future<void> clearProfilePictureCache(String? oldUrl, String? newUrl) async {
    if (oldUrl?.isNotEmpty ?? false) {
      await CacheManager.clearImageCacheForUrl(oldUrl!);
    }

    if (newUrl?.isNotEmpty ?? false) {
      await CacheManager.clearImageCacheForUrl(newUrl!);

      // Clear URL with timestamp parameter
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cacheUrl = newUrl.contains('?')
          ? '$newUrl&t=$timestamp'
          : '$newUrl?t=$timestamp';
      await CacheManager.clearImageCacheForUrl(cacheUrl);
    }

    await CacheManager.clearImageCache();
  }

  /// Uploads profile picture to server
  Future<ApiResponse<String>> uploadProfilePicture(File imageFile) async {
    final userApiService = UserApiService(_apiService);
    return userApiService.uploadProfilePicture(imageFile);
  }
}
