import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart';
import '../services/post_service.dart';

const double kAspectRatio = 1.91;

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      final croppedFile = await _cropImage(File(pickedFile.path));
      if (croppedFile != null && mounted) {
        setState(() => _imageFile = croppedFile);
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: kAspectRatio, ratioY: 1),
        compressQuality: 90,
        compressFormat: ImageCompressFormat.jpg,
        cropStyle: CropStyle.rectangle,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            minimumAspectRatio: kAspectRatio,
            aspectRatioPickerButtonHidden: true,
          ),
          WebUiSettings(
            context: context,
            presentStyle: CropperPresentStyle.dialog,
            boundary: const CroppieBoundary(
              width: 520,
              height: 272,
            ),
            viewPort: const CroppieViewPort(
              width: 480,
              height: 251,
              type: 'rectangle',
            ),
            enableExif: true,
            enableZoom: true,
            showZoomer: true,
          ),
        ],
      );

      return croppedFile != null ? File(croppedFile.path) : null;
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to crop image: $e', isError: true);
      }
      return imageFile; // Return original as fallback
    }
  }

  void _removeImage() {
    setState(() => _imageFile = null);
  }

  Future<void> _createPost() async {
    if (_isLoading) return;

    final String content = _contentController.text.trim();
    if (content.isEmpty && _imageFile == null) {
      setState(() => _errorMessage = 'Please enter some text or add an image');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _showSnackbar('Creating post...', duration: 10, showProgress: true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      _checkApiUrl(apiService);

      await PostService(apiService).createPost(
        content: content,
        mediaFile: _imageFile,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackbar('Post created successfully!', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _handleError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    int duration = 4,
    bool showProgress = false,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: showProgress
            ? Row(
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(message),
                ],
              )
            : Text(message),
        backgroundColor: isError
            ? Colors.red
            : isSuccess
                ? Colors.green
                : null,
        duration: Duration(seconds: duration),
        action: action,
      ),
    );
  }

  void _checkApiUrl(ApiService apiService) {
    if (apiService.baseUrl != AppConstants.baseUrl && mounted) {
      _showSnackbar('Using server URL: ${apiService.baseUrl}', duration: 3);
    }
  }

  void _handleError(dynamic error) {
    final displayError = _formatErrorMessage(error.toString());
    setState(() {
      _errorMessage = 'Failed to create post: $displayError';
    });

    _showSnackbar(
      _errorMessage!,
      isError: true,
      duration: 5,
      action: SnackBarAction(
        label: 'RETRY',
        onPressed: _createPost,
      ),
    );

    _checkForRedirectIssue(displayError);
  }

  String _formatErrorMessage(String errorMessage) {
    if (errorMessage.contains('Exception: Error creating post: Exception:')) {
      return errorMessage.replaceAll(
          'Exception: Error creating post: Exception:', 'Error:');
    }

    if (errorMessage.contains('SocketException')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorMessage.contains('timeout')) {
      return 'Connection timeout. Please try again.';
    } else if (errorMessage.contains('307') ||
        errorMessage.contains('redirect')) {
      return 'Server redirect issue. Please try again.';
    }

    return errorMessage;
  }

  void _checkForRedirectIssue(String error) {
    if (error.contains('Server redirect issue')) {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (apiService.baseUrl == AppConstants.baseUrl) {
        final fallbackUrl = AppConstants.fallbackBaseUrls.firstWhere(
          (url) => url != AppConstants.baseUrl,
          orElse: () => AppConstants.baseUrl,
        );

        if (fallbackUrl != AppConstants.baseUrl) {
          apiService.updateBaseUrl(fallbackUrl);
          if (mounted) {
            _showSnackbar(
              'Switching to alternate server: $fallbackUrl',
              duration: 3,
            );
          }
        }
      }
    }
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade100,
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageFile == null) return const SizedBox.shrink();

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.width / kAspectRatio,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: FileImage(_imageFile!),
              fit: BoxFit.cover,
            ),
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: _removeImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text('Add to your post:'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.photo_library, color: AppColors.primary),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, color: AppColors.primary),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
        ),
        if (_imageFile == null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              'Images will be cropped to standard dimensions',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          _isLoading
              ? _buildLoadingIndicator()
              : TextButton(
                  onPressed: _createPost,
                  child: const Text(
                    'Post',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildErrorBanner(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    border: InputBorder.none,
                  ),
                ),
              ),
              _buildImagePreview(),
              const Divider(),
              _buildMediaButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
