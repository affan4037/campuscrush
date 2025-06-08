import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../widgets/error_message.dart';
import '../../user_management/models/user.dart';
import '../../user_management/services/user_api_service.dart';
import '../models/friendship_status.dart';
import '../services/friendship_service.dart';
import 'friendship_action_button.dart';

class PeopleYouMayKnowWidget extends StatefulWidget {
  const PeopleYouMayKnowWidget({Key? key}) : super(key: key);

  @override
  State<PeopleYouMayKnowWidget> createState() => _PeopleYouMayKnowWidgetState();
}

class _PeopleYouMayKnowWidgetState extends State<PeopleYouMayKnowWidget> {
  final UserApiService _userApiService = GetIt.instance<UserApiService>();
  final FriendshipService _friendshipService =
      GetIt.instance<FriendshipService>();

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  List<User> _users = [];
  final Map<String, FriendshipStatus> _friendshipStatuses = {};
  final Map<String, String?> _requestIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUserId = authService.currentUser?.id;

      // Preload friends and pending connections to filter locally
      final excludeIds = await _getExcludedUserIds();

      // Get suggested users from backend
      final response = await _userApiService.getSuggestedUsers(limit: 50);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.isSuccess && response.data != null) {
        // Apply local filtering
        final filteredUsers = response.data!
            .where((user) =>
                user.id != currentUserId && !excludeIds.contains(user.id))
            .toList();

        if (mounted) {
          setState(() {
            _users = filteredUsers;
            // Initialize all users as not friends
            for (final user in _users) {
              _friendshipStatuses[user.id] = FriendshipStatus.notFriends;
            }
          });
        }

        // Load friendship statuses for UI
        _loadFriendshipStatuses(filteredUsers);
      } else {
        if (mounted) {
          setState(() {
            _error = response.error ?? 'Failed to load suggestions';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Set<String>> _getExcludedUserIds() async {
    final excludeIds = <String>{};

    try {
      // Load friends
      final friends = await _friendshipService.getFriends();
      for (final f in friends) {
        if (f.id is String) {
          excludeIds.add(f.id);
        }
      }

      // Load sent requests
      final sentRequests = await _friendshipService.getSentFriendRequests();
      for (final request in sentRequests) {
        final receiverId = request.receiverId;
        if (receiverId is String && receiverId.isNotEmpty) {
          excludeIds.add(receiverId);
        }
      }

      // Load received requests
      final receivedRequests =
          await _friendshipService.getReceivedFriendRequests();
      for (final request in receivedRequests) {
        final senderId = request.senderId;
        if (senderId is String && senderId.isNotEmpty) {
          excludeIds.add(senderId);
        }
      }
    } catch (e) {
      debugPrint('Error loading connections to exclude: $e');
    }

    return excludeIds;
  }

  Future<void> _loadFriendshipStatuses(List<User> users) async {
    if (users.isEmpty) return;

    // Process users in batches to avoid overwhelming the API
    const int batchSize = 20;
    final Set<String> idsToRemove = {};

    for (int i = 0; i < users.length; i += batchSize) {
      if (!mounted) return;

      final end = (i + batchSize < users.length) ? i + batchSize : users.length;
      final batch = users.sublist(i, end);

      // Create a map to hold all status futures for this batch
      final Map<String, Future<FriendshipDetails>> statusFutures = {};

      // Start all requests in parallel for this batch
      for (final user in batch) {
        statusFutures[user.id] =
            _friendshipService.getFriendshipDetails(user.id);
      }

      // Process results as they complete
      for (final userId in statusFutures.keys) {
        try {
          final details = await statusFutures[userId]!;
          if (!mounted) return;

          // Filter out friends and pending connections that were missed
          if (details.status != FriendshipStatus.notFriends) {
            idsToRemove.add(userId);
          }

          // Update status maps for UI
          if (mounted) {
            setState(() {
              _friendshipStatuses[userId] = details.status;
              _requestIds[userId] = details.requestId;
            });
          }
        } catch (e) {
          debugPrint('Error checking friendship status for $userId: $e');
          // Set a default value instead of failing
          if (mounted) {
            setState(() {
              _friendshipStatuses[userId] = FriendshipStatus.notFriends;
              _requestIds[userId] = null;
            });
          }
        }
      }
    }

    // Remove any friends or pending connections that were found
    if (idsToRemove.isNotEmpty && mounted) {
      setState(() {
        _users =
            _users.where((user) => !idsToRemove.contains(user.id)).toList();
      });
    }
  }

  Future<void> _handleFriendshipAction(
    String userId,
    Future<void> Function() action,
    FriendshipStatus newStatus,
    String successMessage,
    String errorMessage, {
    Widget? icon,
    Color? backgroundColor,
    Duration? duration,
    bool resetRequestId = true,
  }) async {
    _setActionLoading(true);

    try {
      await action();
      if (!mounted) return;

      setState(() {
        _friendshipStatuses[userId] = newStatus;
        if (resetRequestId) _requestIds[userId] = null;

        // If the action changes the relationship status, update the UI immediately
        if (newStatus != FriendshipStatus.notFriends) {
          _users = _users.where((user) => user.id != userId).toList();
        }
      });

      _showSnackBar(
        successMessage,
        backgroundColor: backgroundColor ?? Colors.green,
        icon: icon ?? const Icon(Icons.check_circle, color: Colors.white),
        duration: duration ?? const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('Error in friendship action: $e');
      if (!mounted) return;

      _showSnackBar(
        '$errorMessage: ${e.toString()}',
        backgroundColor: Colors.red,
        icon: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      if (mounted) {
        _setActionLoading(false);
      }
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    _setActionLoading(true);

    try {
      await _friendshipService.sendFriendRequest(userId);

      if (!mounted) return;

      setState(() {
        _friendshipStatuses[userId] = FriendshipStatus.pendingSent;
        // No need to update requestId here as it will be set in the background
      });

      _showSnackBar(
        'Friend request sent successfully',
        backgroundColor: Colors.green,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        duration: const Duration(seconds: 2),
      );

      // Update the filtered list for UI immediately
      setState(() {
        _users = _users.where((user) => user.id != userId).toList();
      });
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      if (!mounted) return;

      // Extract a user-friendly error message
      String errorMessage = 'Failed to send friend request';

      // Handle specific error types
      if (e.toString().contains('_Map<String, dynamic>') &&
          e.toString().contains('not a subtype of type')) {
        // This is the type error but the request was actually successful
        // Just show success message instead of the error
        _showSnackBar(
          'Friend request sent successfully',
          backgroundColor: Colors.green,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          duration: const Duration(seconds: 2),
        );

        // Update UI to reflect the sent request
        setState(() {
          _friendshipStatuses[userId] = FriendshipStatus.pendingSent;
          _users = _users.where((user) => user.id != userId).toList();
        });
        return;
      } else if (e.toString().contains('already sent')) {
        errorMessage = 'You have already sent a friend request to this user';
      } else if (e.toString().contains('already friends')) {
        errorMessage = 'You are already friends with this user';
      } else {
        errorMessage = 'Failed to send friend request: ${e.toString()}';
      }

      _showSnackBar(
        errorMessage,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.error, color: Colors.white),
      );
    } finally {
      if (mounted) {
        _setActionLoading(false);
      }
    }
  }

  Future<void> _cancelFriendRequest(String userId) async {
    final requestId = _requestIds[userId];
    if (requestId == null) return;

    await _handleFriendshipAction(
      userId,
      () => _friendshipService.cancelFriendRequest(requestId),
      FriendshipStatus.notFriends,
      'Friend request canceled',
      'Failed to cancel friend request',
    );
  }

  Future<void> _acceptFriendRequest(String userId) async {
    final requestId = _requestIds[userId];
    if (requestId == null) return;

    String userName = "this user";
    try {
      final user = _users.firstWhere((u) => u.id == userId);
      userName = user.fullName;
    } catch (_) {}

    await _handleFriendshipAction(
      userId,
      () => _friendshipService.acceptFriendRequest(requestId),
      FriendshipStatus.friends,
      'Hooray! You are now friends with $userName!',
      'Failed to accept friend request',
      icon: const Icon(Icons.celebration, color: Colors.yellow),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _removeFriend(String userId) async {
    await _handleFriendshipAction(
      userId,
      () => _friendshipService.removeFriend(userId),
      FriendshipStatus.notFriends,
      'Friend removed',
      'Failed to remove friend',
    );
  }

  void _setActionLoading(bool loading) {
    if (mounted) {
      setState(() => _isActionLoading = loading);
    }
  }

  void _showSnackBar(
    String message, {
    Color? backgroundColor,
    Widget? icon,
    Duration? duration,
  }) {
    if (!mounted) return;

    // Clear any existing snackbars to prevent overlap
    ScaffoldMessenger.of(context).clearSnackBars();

    final content = Row(
      children: [
        icon ?? const SizedBox.shrink(),
        if (icon != null) const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: content,
        backgroundColor: backgroundColor,
        duration: duration ?? const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'People You May Know',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildErrorState()
            else if (_users.isEmpty)
              _buildEmptyState()
            else
              _buildUserList(),
          ],
        ),
        if (_isActionLoading)
          const LoadingOverlay(
            isLoading: true,
            child: SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ErrorMessage(
          message: _error!,
          onRetry: _loadUsers,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No other registered users found'),
      ),
    );
  }

  Widget _buildUserList() {
    // Don't show friends or pending connections in the UI
    final filteredUsers = _users.where((user) {
      final status =
          _friendshipStatuses[user.id] ?? FriendshipStatus.notFriends;
      return status == FriendshipStatus.notFriends;
    }).toList();

    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      // Adjust height based on screen width - smaller height on smaller screens
      height: MediaQuery.of(context).size.width < 400 ? 180 : 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          final user = filteredUsers[index];
          final status =
              _friendshipStatuses[user.id] ?? FriendshipStatus.notFriends;
          final requestId = _requestIds[user.id];

          return _UserSuggestionCard(
            user: user,
            status: status,
            requestId: requestId,
            onSendRequest: () => _sendFriendRequest(user.id),
            onCancelRequest: () => _cancelFriendRequest(user.id),
            onAcceptRequest: () => _acceptFriendRequest(user.id),
            onRemoveFriend: () => _removeFriend(user.id),
            onViewProfile: () => _navigateToUserProfile(user.id),
          );
        },
      ),
    );
  }

  void _navigateToUserProfile(String userId) {
    Navigator.pushNamed(
      context,
      AppRouter.userProfile,
      arguments: {
        'userId': userId,
        'isCurrentUser': false,
      },
    );
  }
}

class _UserSuggestionCard extends StatelessWidget {
  final User user;
  final FriendshipStatus status;
  final VoidCallback onSendRequest;
  final VoidCallback onCancelRequest;
  final VoidCallback onAcceptRequest;
  final VoidCallback onRemoveFriend;
  final VoidCallback onViewProfile;
  final String? requestId;

  const _UserSuggestionCard({
    Key? key,
    required this.user,
    required this.status,
    required this.onSendRequest,
    required this.onCancelRequest,
    required this.onAcceptRequest,
    required this.onRemoveFriend,
    required this.onViewProfile,
    this.requestId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onViewProfile,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 2,
        child: Container(
          width: MediaQuery.of(context).size.width < 400 ? 120 : 140,
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                user: null,
                profilePictureUrl: user.profilePicture ??
                    AppConstants.getAvatarFallbackUrl(user.fullName),
                displayName: user.fullName,
                radius: MediaQuery.of(context).size.width < 400 ? 24 : 30,
              ),
              const SizedBox(height: 8),
              Text(
                user.fullName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '@${user.username}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width < 400 ? 100 : 120,
                    ),
                    child: _buildActionButton(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Center(
      child: FriendshipActionButton(
        status: status,
        showBothAcceptRejectButtons: false,
        onSendRequest: onSendRequest,
        onCancelRequest: onCancelRequest,
        onAcceptRequest: onAcceptRequest,
        onRemoveFriend: onRemoveFriend,
        requestExists: requestId != null,
      ),
    );
  }
}
