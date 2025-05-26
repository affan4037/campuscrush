import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../core/routes/app_router.dart';
import '../services/user_api_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/profile_avatar.dart';
import '../../posts/services/post_service.dart';
import '../../posts/models/post.dart';
import '../../posts/widgets/post_card.dart';
import 'edit_profile_screen.dart';
import '../../../core/utils/cache_manager.dart';

class ProfileScreen extends StatefulWidget {
  static const String routeName = '/profile';

  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  int _refreshTimestamp = DateTime.now().millisecondsSinceEpoch;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  File? _selectedImage;
  bool _isLoadingPosts = false;
  String _postsError = '';
  List<Post> _userPosts = [];
  late PostService _postService;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const Color _primaryBlue = Color(0xFF0A66C2);
  static const Color _textPrimary = Color(0xFF191919);
  static const Color _textSecondary = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final apiService = Provider.of<ApiService>(context, listen: false);
    _postService = PostService(apiService);
    _loadUserPosts();
  }

  void _setLoadingState(bool isLoading, {bool clearError = true}) {
    if (!mounted) return;
    setState(() {
      _isLoading = isLoading;
      if (clearError) _error = null;
    });
  }

  void _showSnackBar(String message,
      {Color? backgroundColor, int duration = 4}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    _setLoadingState(true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final hasValidToken = await authService.hasValidToken();
      if (!hasValidToken) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      final token = authService.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please log in again.');
      }

      apiService.setAuthToken(token);

      await _clearProfileImageCache(authService.currentUser?.profilePicture);
      final refreshSuccess = await authService.refreshUserProfile();

      if (!refreshSuccess) {
        throw Exception('Profile data updated, but email verification pending');
      }

      await _clearProfileImageCache(authService.currentUser?.profilePicture);

      if (mounted) {
        setState(() {
          _refreshTimestamp = DateTime.now().millisecondsSinceEpoch;
        });
      }

      await _loadUserPosts();
    } catch (e) {
      _handleProfileError(e);
    } finally {
      _setLoadingState(false, clearError: false);
    }
  }

  Future<void> _clearProfileImageCache(String? profilePictureUrl) async {
    if (profilePictureUrl != null && profilePictureUrl.isNotEmpty) {
      await CacheManager.clearImageCacheForUrl(profilePictureUrl);
    }
    await CacheManager.clearImageCache();
  }

  void _handleProfileError(dynamic error) {
    String errorMessage = 'Profile loaded, but email verification needed';
    bool isAuthError = false;

    if (error is DioException) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        errorMessage = 'Your session has expired. Please log in again.';
        isAuthError = true;
      }
    } else if (error.toString().toLowerCase().contains('token') ||
        error.toString().toLowerCase().contains('auth') ||
        error.toString().contains('unauthorized')) {
      errorMessage = 'Authentication error. Please log in again.';
      isAuthError = true;
    }

    if (isAuthError && mounted) {
      _showSnackBar(errorMessage);
      _handleAuthError();
    }

    if (mounted) {
      setState(() {
        _error = errorMessage;
      });
    }
  }

  Future<void> _handleAuthError() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.logout();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRouter.login, (route) => false);
      }
    });
  }

  Future<void> _loadUserPosts() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) return;

    setState(() {
      _isLoadingPosts = true;
      _postsError = '';
    });

    try {
      if (authService.token != null && authService.token!.isNotEmpty) {
        apiService.setAuthToken(authService.token!);
      }

      _postService = PostService(apiService);
      final posts = await _postService.getUserPosts(user.id);
      final processedPosts = _processPostsWithAuthor(posts, user);

      if (mounted) {
        setState(() {
          _userPosts = processedPosts;
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
          _postsError = 'Could not load posts. Please try again later.';
        });
      }
    }
  }

  List<Post> _processPostsWithAuthor(List<Post> posts, dynamic user) {
    return posts.map((post) {
      return Post(
        id: post.id,
        content: post.content,
        mediaUrl: post.mediaUrl,
        authorId: user.id,
        author: user,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
        commentCount: post.commentCount,
        likeCount: post.likeCount,
        shareCount: post.shareCount,
        isLikedByCurrentUser: post.isLikedByCurrentUser,
        currentUserReactionType: post.currentUserReactionType,
      );
    }).toList();
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );

    if (result == true) {
      await _refreshProfile();
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);

      final token = await _getFreshToken();
      if (token == null) return;

      apiService.setAuthToken(token);
      await _clearProfileImageCache(authService.currentUser?.profilePicture);

      final userApiService = UserApiService(apiService);
      final pickedImage = await _pickAndCropImage();

      if (pickedImage == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      _selectedImage = pickedImage;
      final uploadResult =
          await userApiService.uploadProfilePicture(_selectedImage!);

      if (uploadResult.isSuccess && uploadResult.data != null) {
        await CacheManager.clearImageCache();
        await _refreshProfile();

        if (mounted) {
          _showSnackBar('Profile picture updated successfully');
        }
      } else {
        _handleUploadError(uploadResult.error);
      }
    } catch (e) {
      _handleUploadError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _getFreshToken() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    String? token = authService.userData?['access_token'] as String?;

    if (token == null || token.isEmpty) {
      try {
        const storage = FlutterSecureStorage();
        token = await storage.read(key: AppConstants.tokenKey);

        if (token != null && token.isNotEmpty && authService.userData != null) {
          authService.userData!['access_token'] = token;
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error accessing secure storage: $e');
        }
      }
    }

    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnackBar('Authentication token not found. Please log in again.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRouter.login, (route) => false);
          }
        });
      }
      return null;
    }

    return token;
  }

  Future<File?> _pickAndCropImage() async {
    final ImagePicker picker = ImagePicker();
    final primaryColor = Theme.of(context).primaryColor;

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return null;

    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.original,
        ],
        cropStyle: CropStyle.circle,
        compressQuality: 90,
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.black.withAlpha((0.2 * 255).round()),
            activeControlsWidgetColor: primaryColor,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            minimumAspectRatio: 1.0,
          ),
        ],
      );

      if (croppedFile == null) {
        if (mounted) {
          _showSnackBar('Cropping canceled. Using original image instead.');
        }
        return File(image.path);
      }

      return File(croppedFile.path);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
            'Error during image cropping: ${e.toString().split('Exception:').last.trim()}. Using original image.');
      }
      return File(image.path);
    }
  }

  void _handleUploadError(dynamic error) {
    String errorMessage = 'Error uploading profile picture';
    bool isAuthError = false;

    if (error is DioException) {
      final dioError = error;
      if (dioError.response != null) {
        final statusCode = dioError.response!.statusCode;
        final data = dioError.response!.data;

        switch (statusCode) {
          case 401:
          case 403:
            errorMessage = 'Authentication failed. Please log in again.';
            isAuthError = true;
            break;
          case 413:
            errorMessage =
                'Image file is too large. Please choose a smaller image.';
            break;
          case 415:
            errorMessage =
                'Unsupported file type. Please choose a valid image file.';
            break;
          default:
            errorMessage = data['detail'] ?? 'Failed to upload profile picture';
        }
      } else if (dioError.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timed out. Please try again.';
      } else if (dioError.type == DioExceptionType.connectionError) {
        errorMessage = 'Network error. Please check your connection.';
      }
    } else if (error is SocketException) {
      errorMessage = 'Network error. Please check your connection.';
    } else if (error is TimeoutException) {
      errorMessage = 'Connection timed out. Please try again.';
    }

    if (mounted) {
      _showSnackBar(errorMessage);
      if (isAuthError) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRouter.login, (route) => false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('No user data available'),
        ),
      );
    }

    final String fullName = user.fullName;
    final String email = user.email;
    final String username = user.username;
    final String university = user.university;
    final String department = user.department ?? 'Not specified';
    final String graduationYear = user.graduationYear ?? 'Not specified';
    final String? bio = user.bio;
    final String? profilePicture = user.profilePicture;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading || _isUploading,
        child: RefreshIndicator(
          onRefresh: _refreshProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null && _error!.isNotEmpty)
                  ErrorDisplay(
                    error: _error!,
                    onRetry: _refreshProfile,
                  ),
                _buildProfileHeader(
                    context, fullName, username, profilePicture),
                _buildProfileInfo(context, bio, university, department,
                    graduationYear, email),
                _buildUserPosts(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    String fullName,
    String username,
    String? profilePicture,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 32, 0, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 55),
                width: double.infinity,
                height: 120,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                ),
              ),
              Positioned(
                top: 65,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      child: ProfileAvatar(
                        displayName: fullName,
                        profilePictureUrl: profilePicture,
                        radius: 52,
                        cacheVersion: _refreshTimestamp,
                        showEditIcon: false,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _uploadProfilePicture,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(
    BuildContext context,
    String? bio,
    String university,
    String department,
    String graduationYear,
    String email,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bio != null && bio.isNotEmpty) ...[
          _buildInfoCard(
            title: 'About',
            child: Text(
              bio,
              style: const TextStyle(
                fontSize: 15,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
        _buildInfoCard(
          title: 'Education & Contact',
          child: Column(
            children: [
              _buildInfoRow(Icons.school, 'University', university),
              const Divider(height: 24),
              _buildInfoRow(Icons.business, 'Department', department),
              const Divider(height: 24),
              _buildInfoRow(
                  Icons.calendar_today, 'Graduation Year', graduationYear),
              const Divider(height: 24),
              _buildInfoRow(Icons.email, 'Email', email),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                    color: _textPrimary,
                  ),
                ),
                if (title == 'Education & Contact') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _navigateToEditProfile,
                    child: const Icon(
                      Icons.edit,
                      size: 18,
                      color: _primaryBlue,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: _primaryBlue,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserPosts() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'My Posts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        if (_isLoadingPosts)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_postsError.isNotEmpty)
          _buildPostsErrorView()
        else if (_userPosts.isEmpty)
          _buildEmptyPostsView()
        else
          _buildPostsList(currentUser),
      ],
    );
  }

  Widget _buildPostsErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _postsError,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUserPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(dynamic currentUser) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        Post postWithAuthor = post;

        if ((post.author == null || post.author!.fullName.isEmpty) &&
            currentUser != null) {
          postWithAuthor = Post(
            id: post.id,
            content: post.content,
            mediaUrl: post.mediaUrl,
            authorId: post.authorId,
            author: currentUser,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            commentCount: post.commentCount,
            likeCount: post.likeCount,
            shareCount: post.shareCount,
            isLikedByCurrentUser: post.isLikedByCurrentUser,
            currentUserReactionType: post.currentUserReactionType,
          );
        }

        return PostCard(post: postWithAuthor);
      },
    );
  }

  Widget _buildEmptyPostsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          children: [
            Icon(
              Icons.post_add,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'You haven\'t created any posts yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/create-post'),
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
