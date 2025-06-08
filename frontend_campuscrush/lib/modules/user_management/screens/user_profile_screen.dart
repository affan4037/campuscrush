import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../services/api_service.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../widgets/error_message.dart';
import '../../friendships/services/friendship_service.dart';
import '../../friendships/models/friendship_status.dart';
import '../models/user.dart';
import '../services/user_api_service.dart';
import '../../posts/services/post_service.dart';
import '../../posts/models/post.dart';
import '../../posts/widgets/post_card.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;
  final bool isCurrentUser;

  const UserProfileScreen({
    Key? key,
    this.userId = '',
    this.username,
    this.isCurrentUser = false,
  })  : assert(username != null || userId != ''),
        super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserApiService _userApiService = GetIt.instance<UserApiService>();
  final FriendshipService _friendshipService =
      GetIt.instance<FriendshipService>();
  final PostService _postService = GetIt.instance<PostService>();
  final ApiService _apiService = GetIt.instance<ApiService>();

  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isLoadingPosts = false;
  String _error = '';
  String _postsError = '';
  User? _user;
  List<Post> _userPosts = [];

  FriendshipStatus _friendshipStatus = FriendshipStatus.notFriends;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_user != null && !widget.isCurrentUser) {
      _loadFriendshipStatus(forceRefresh: true);
      Future.delayed(
          const Duration(milliseconds: 100), _verifyFriendshipStatus);
    }
  }

  Future<void> _loadUserProfile() async {
    _friendshipStatus = FriendshipStatus.notFriends;
    _requestId = null;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      ApiResponse<User> response;
      if (widget.username != null) {
        response = await _userApiService.getUserByUsername(widget.username!);
      } else {
        response = await _userApiService.getUserById(widget.userId);
      }

      if (!response.isSuccess || response.data == null) {
        setState(() {
          _isLoading = false;
          _error = response.error ?? 'Failed to load user profile';
        });
        return;
      }

      _user = response.data;

      if (widget.isCurrentUser) {
        setState(() {
          _isLoading = false;
          _friendshipStatus = FriendshipStatus.self;
        });
        _loadUserPosts();
        return;
      }

      await _loadFriendshipStatus();

      if (!widget.isCurrentUser) {
        _verifyFriendshipStatus();
      }

      _loadUserPosts();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred: $e';
      });
    }
  }

  Future<void> _loadFriendshipStatus({bool forceRefresh = false}) async {
    if (_user == null) {
      return;
    }

    try {
      final friendshipDetails = await _friendshipService
          .getFriendshipDetails(_user!.id, forceRefresh: forceRefresh);

      FriendshipStatus newStatus = friendshipDetails.status;
      String? newRequestId = friendshipDetails.requestId;

      if (friendshipDetails.status == FriendshipStatus.friends) {
        newStatus = FriendshipStatus.friends;
      }

      bool statusChanged = _friendshipStatus != newStatus;
      bool requestIdChanged = _requestId != newRequestId;

      if (statusChanged || requestIdChanged) {
        setState(() {
          _isLoading = false;
          _friendshipStatus = newStatus;
          _requestId = newRequestId;
        });

        if (statusChanged) {
          Future.delayed(const Duration(milliseconds: 100), _forceRebuild);
        }
      } else if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }

      _validateFriendshipStatusConsistency(forceRefresh);
    } catch (statusError) {
      setState(() {
        _isLoading = false;
        _friendshipStatus = FriendshipStatus.notFriends;
        _requestId = null;
      });
    }
  }

  void _validateFriendshipStatusConsistency(bool previouslyRefreshed) {
    if ((_friendshipStatus == FriendshipStatus.pendingSent ||
            _friendshipStatus == FriendshipStatus.pendingReceived) &&
        (_requestId == null || _requestId!.isEmpty)) {
      if (!previouslyRefreshed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadFriendshipStatus(forceRefresh: true);
        });
      } else {
        setState(() {
          _friendshipStatus = FriendshipStatus.notFriends;
        });
      }
    }
  }

  Future<void> _loadUserPosts() async {
    if (_user == null) return;

    setState(() {
      _isLoadingPosts = true;
      _postsError = '';
    });

    try {
      final posts = await _postService.getUserPosts(_user!.id);

      if (mounted) {
        setState(() {
          _userPosts = posts;
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

  Future<void> _sendFriendRequest() async {
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot send request: User profile not loaded')),
      );
      return;
    }

    setState(() {
      _friendshipStatus = FriendshipStatus.pendingSent;
      _isActionLoading = true;
      _requestId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    });

    _forceRebuild();

    try {
      final request = await _friendshipService.sendFriendRequest(_user!.id);

      if (mounted) {
        setState(() {
          _requestId = request.id;
          _isActionLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isActionLoading = false;
      });

      // Check if this is the type error but the request was actually sent
      if (e.toString().contains('_Map<String, dynamic>') &&
          e.toString().contains('not a subtype of type')) {
        // The request was sent successfully despite the type error
        _showSnackBar(
          'Friend request sent successfully',
          backgroundColor: Colors.green,
        );
        return;
      }

      // For other errors, reset state and handle normally
      setState(() {
        _friendshipStatus = FriendshipStatus.notFriends;
        _requestId = null;
      });

      await _handleFriendRequestError(e);
    }
  }

  Future<void> _handleFriendRequestError(dynamic e) async {
    final String errorMsg = e.toString();

    if (errorMsg.contains('already sent you a friend request')) {
      setState(() {
        _friendshipStatus = FriendshipStatus.pendingReceived;
      });
      await _loadFriendshipStatus(forceRefresh: true);
      _forceRebuild();

      _showSnackBar(
        '${_user!.fullName} already sent you a friend request. You can accept it.',
        backgroundColor: Colors.blue,
      );
    } else if (errorMsg.contains('already sent')) {
      setState(() {
        _friendshipStatus = FriendshipStatus.pendingSent;
      });
      await _loadFriendshipStatus(forceRefresh: true);
      _forceRebuild();

      _showSnackBar(
        'You already sent a friend request to this user',
        backgroundColor: Colors.orange,
      );
    } else if (errorMsg.contains('already friends')) {
      setState(() => _friendshipStatus = FriendshipStatus.friends);
      _forceRebuild();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _showSnackBar(
            'You are already friends with ${_user!.fullName}',
            backgroundColor: Colors.green,
          );
        }
      });
    } else {
      _showSnackBar(
        'Failed to send friend request: ${errorMsg.split(':').last.trim()}',
        backgroundColor: Colors.red[300],
      );
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _cancelFriendRequest() async {
    if (_requestId == null || _requestId!.isEmpty) {
      _showSnackBar('No pending request to cancel');
      return;
    }

    setState(() => _isActionLoading = true);

    try {
      await _friendshipService.cancelFriendRequest(_requestId!);

      setState(() {
        _friendshipStatus = FriendshipStatus.notFriends;
        _requestId = null;
        _isActionLoading = false;
      });

      _showSnackBar(
        'Friend request canceled',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      setState(() => _isActionLoading = false);

      String errorMessage = 'Failed to cancel friend request';
      bool shouldResetState = false;

      if (e.toString().contains('not found') ||
          e.toString().contains('Invalid request ID')) {
        errorMessage = 'Request not found or already canceled';
        shouldResetState = true;
      }

      if (shouldResetState) {
        setState(() {
          _friendshipStatus = FriendshipStatus.notFriends;
          _requestId = null;
        });
      }

      _showSnackBar(errorMessage, backgroundColor: Colors.red[300]);
    }
  }

  Future<void> _removeFriend() async {
    if (_user == null) {
      _showSnackBar('Cannot remove friend: User profile not loaded');
      return;
    }

    setState(() => _isActionLoading = true);

    try {
      await _friendshipService.removeFriend(_user!.id);

      setState(() {
        _friendshipStatus = FriendshipStatus.notFriends;
        _requestId = null;
        _isActionLoading = false;
      });

      _showSnackBar('Removed ${_user!.fullName} from friends');
    } catch (e) {
      setState(() => _isActionLoading = false);

      String errorMessage = 'Failed to remove friend';
      if (e.toString().contains('not found') ||
          e.toString().contains('no friendship')) {
        errorMessage = 'You are not friends with this user';
        setState(() {
          _friendshipStatus = FriendshipStatus.notFriends;
        });
      }

      _showSnackBar(errorMessage);
    }
  }

  void _forceRebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _verifyFriendshipStatus() async {
    if (_user == null || widget.isCurrentUser) return;

    try {
      final details = await _friendshipService.getFriendshipDetails(_user!.id,
          forceRefresh: true);

      if (details.status == FriendshipStatus.friends) {
        setState(() {
          _friendshipStatus = FriendshipStatus.friends;
        });

        try {
          final posts = await _postService.getUserPosts(_user!.id, limit: 1);
          if (posts.isNotEmpty && mounted) {
            setState(() {
              _friendshipStatus = FriendshipStatus.friends;
            });
          }
        } catch (e) {
          // Ignore post checking errors
        }

        _forceRebuild();
      } else {
        try {
          final response =
              await _apiService.get('${AppConstants.apiPrefix}/friends');

          if (response.isSuccess && response.data != null) {
            final List<dynamic> friendsData = json.decode(response.data);

            bool isFriend = friendsData.any((friend) {
              if (friend is Map<String, dynamic> && friend.containsKey('id')) {
                return friend['id'] == _user!.id;
              }
              return false;
            });

            if (isFriend && mounted) {
              setState(() {
                _friendshipStatus = FriendshipStatus.friends;
              });
              _forceRebuild();
            }
          }
        } catch (e) {
          // Ignore friends list checking errors
        }
      }
    } catch (e) {
      // Ignore verification errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.username ?? 'User Profile'),
        actions: [
          if (!widget.isCurrentUser && _user != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptionsMenu(context),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(
                child: ErrorMessage(message: _error, onRetry: _loadUserProfile))
          else if (_user != null)
            _buildProfileContent(),
          if (_isActionLoading)
            const LoadingOverlay(
              isLoading: true,
              child: SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserProfile();
        if (_user != null) {
          await _loadUserPosts();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildUserDetails(),
            ),
            const SizedBox(height: 16),
            _buildUserPosts(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    List<Widget> columnChildren = [
      ProfileAvatar(
        user: _user!,
        size: 120,
        showBorder: true,
      ),
      const SizedBox(height: 16),
      Text(
        _user!.fullName,
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      Text(
        '@${_user!.username}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
    ];

    if (!widget.isCurrentUser) {
      columnChildren.add(_buildFriendshipIndicator());
    }

    return Center(
      child: Column(
        children: columnChildren,
      ),
    );
  }

  Widget _buildFriendshipIndicator() {
    if (_user != null && !widget.isCurrentUser) {
      bool postsCacheIndicatesFriendship = false;
      if (_userPosts.isNotEmpty) {
        postsCacheIndicatesFriendship = true;
      }

      if (postsCacheIndicatesFriendship &&
          _friendshipStatus != FriendshipStatus.friends) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _friendshipStatus = FriendshipStatus.friends;
            });
          }
        });

        return _buildFriendsLabel();
      }
    }

    if (_friendshipStatus == FriendshipStatus.friends) {
      return _buildFriendsLabel();
    }

    if (_friendshipStatus == FriendshipStatus.pendingSent) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 11),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Text(
                  'Request Sent',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _isActionLoading ? null : _cancelFriendRequest,
            icon: const Icon(Icons.cancel, size: 16),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
              foregroundColor: Colors.red[400],
            ),
          ),
        ],
      );
    }

    if (_friendshipStatus == FriendshipStatus.notFriends) {
      return ElevatedButton.icon(
        onPressed: _isActionLoading ? null : _sendFriendRequest,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Friend'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFriendsLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text(
            'Friends',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetails() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_user!.bio != null && _user!.bio!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(_user!.bio!),
              ),
            _buildDetailRow(Icons.school, 'University', _user!.university),
            if (_user!.department != null && _user!.department!.isNotEmpty)
              _buildDetailRow(Icons.business, 'Department', _user!.department!),
            if (_user!.graduationYear != null &&
                _user!.graduationYear!.isNotEmpty)
              _buildDetailRow(Icons.calendar_today, 'Graduation Year',
                  _user!.graduationYear!),
            if (widget.isCurrentUser ||
                _friendshipStatus == FriendshipStatus.friends)
              _buildDetailRow(Icons.email, 'Email', _user!.email),
            _buildDetailRow(Icons.access_time, 'Joined',
                '${_user!.createdAt.month}/${_user!.createdAt.year}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Posts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload posts',
                onPressed: _loadUserPosts,
              ),
            ],
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
          _buildErrorView(_postsError, _loadUserPosts)
        else if (_userPosts.isEmpty)
          _buildEmptyPostsView()
        else
          _buildPostsList(),
      ],
    );
  }

  Widget _buildErrorView(String errorMessage, VoidCallback onRetry) {
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
              errorMessage,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        Post postWithAuthor = post;

        if ((post.author == null || post.author!.fullName.isEmpty) &&
            _user != null) {
          postWithAuthor = Post(
            id: post.id,
            content: post.content,
            mediaUrl: post.mediaUrl,
            authorId: post.authorId,
            author: _user,
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
            const SizedBox(height: 8),
            Text(
              widget.isCurrentUser
                  ? "You haven't created any posts yet"
                  : "This user hasn't posted anything yet",
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_user != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'User ID: ${_user!.id}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (widget.isCurrentUser)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/create-post',
                  ).then((_) {
                    _loadUserPosts();
                  });
                },
                icon: const Icon(Icons.add),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                label: const Text('Create Your First Post'),
              ),
            ElevatedButton.icon(
              onPressed: _loadUserPosts,
              icon: const Icon(Icons.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
              label: const Text('Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_friendshipStatus == FriendshipStatus.friends)
                ListTile(
                  leading: const Icon(Icons.person_remove),
                  title: const Text('Remove Friend'),
                  onTap: () {
                    Navigator.pop(context);
                    _showRemoveFriendDialog(context);
                  },
                ),
              if (_friendshipStatus == FriendshipStatus.pendingSent)
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel Friend Request'),
                  onTap: () {
                    Navigator.pop(context);
                    _cancelFriendRequest();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('Block user functionality not implemented yet');
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Report User'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar(
                      'Report user functionality not implemented yet');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRemoveFriendDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Friend'),
          content: Text(
              'Are you sure you want to remove ${_user?.fullName} from your friends?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Remove'),
              onPressed: () {
                Navigator.of(context).pop();
                _removeFriend();
              },
            ),
          ],
        );
      },
    );
  }
}
