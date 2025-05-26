import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/styling.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../widgets/profile_avatar.dart';
import '../../friendships/models/friendship_status.dart';
import '../../friendships/services/friendship_service.dart';
import '../models/user.dart';
import '../services/user_api_service.dart';
import 'user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  final _userApiService = GetIt.instance<UserApiService>();
  final _friendshipService = GetIt.instance<FriendshipService>();

  bool _isLoading = false;
  String? _error;
  List<User>? _searchResults;
  final Map<String, FriendshipStatus> _friendshipStatuses = {};
  static const _batchSize = 20;

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedUsers() async {
    _setLoadingState(true);

    try {
      final response = await _userApiService.getSuggestedUsers(limit: 50);

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        setState(() {
          _searchResults = response.data;
        });

        await _loadFriendshipStatuses(response.data!);
      } else {
        setState(() {
          _error = response.error ?? 'Failed to load suggested users';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      _setLoadingState(false);
    }
  }

  Future<void> _loadFriendshipStatuses(List<User> users) async {
    if (users.isEmpty) return;

    final Set<String> idsToRemove = {};

    for (int i = 0; i < users.length; i += _batchSize) {
      if (!mounted) return;

      final end =
          (i + _batchSize < users.length) ? i + _batchSize : users.length;
      final batch = users.sublist(i, end);
      final Map<String, Future<FriendshipDetails>> statusFutures = {};

      for (final user in batch) {
        statusFutures[user.id] =
            _friendshipService.getFriendshipDetails(user.id);
      }

      for (final userId in statusFutures.keys) {
        try {
          final details = await statusFutures[userId]!;
          if (!mounted) return;

          if (details.status != FriendshipStatus.notFriends) {
            idsToRemove.add(userId);
          }

          if (mounted) {
            setState(() {
              _friendshipStatuses[userId] = details.status;
            });
          }
        } catch (e) {
          debugPrint('Error checking friendship status for $userId: $e');
          if (mounted) {
            _friendshipStatuses[userId] = FriendshipStatus.notFriends;
          }
        }
      }
    }

    if (idsToRemove.isNotEmpty && mounted) {
      setState(() {
        _searchResults = _searchResults!
            .where((user) => !idsToRemove.contains(user.id))
            .toList();
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      _loadSuggestedUsers();
      return;
    }

    _setLoadingState(true);

    try {
      final response = await _userApiService.searchUsers(query);

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        setState(() {
          _searchResults = response.data;
        });
        await _loadFriendshipStatuses(response.data!);
      } else {
        setState(() {
          _error = response.error ?? 'Failed to search users';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      _setLoadingState(false);
    }
  }

  void _setLoadingState(bool isLoading) {
    if (!mounted) return;
    setState(() {
      _isLoading = isLoading;
      if (isLoading) _error = null;
    });
  }

  void _debounceSearch(String value) {
    Future.delayed(AppConstants.shortAnimationDuration, () {
      if (value == _searchController.text) {
        _searchUsers(value);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _loadSuggestedUsers();
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Users'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppStyling.textPrimary,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: LoadingOverlay(
              isLoading: _isLoading,
              child: _error != null
                  ? ErrorDisplay.fromErrorMessage(
                      errorMessage: _error!,
                      onRetry: _loadSuggestedUsers,
                    )
                  : _searchResults == null || _searchResults!.isEmpty
                      ? _buildEmptyState()
                      : _buildSearchResults(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by username or name',
          prefixIcon: const Icon(Icons.search, color: AppStyling.primaryBlue),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.clear, color: AppStyling.textSecondary),
                  onPressed: _clearSearch,
                )
              : null,
          border: _buildSearchBorder(),
          enabledBorder: _buildSearchBorder(),
          focusedBorder: _buildSearchBorder(isFocused: true),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: _debounceSearch,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchUsers,
      ),
    );
  }

  OutlineInputBorder _buildSearchBorder({bool isFocused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      borderSide: BorderSide(
        color: isFocused ? AppStyling.primaryBlue : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Text(
            'No users found',
            style: AppStyling.subheadingStyle.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          Text(
            'Try searching with a different name or username',
            style: AppStyling.bodyStyle.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final filteredUsers = _searchResults!.where((user) {
      final status =
          _friendshipStatuses[user.id] ?? FriendshipStatus.notFriends;
      return status == FriendshipStatus.notFriends;
    }).toList();

    if (filteredUsers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
      ),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) => _buildUserListItem(filteredUsers[index]),
    );
  }

  Widget _buildUserListItem(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.smallPadding),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: ProfileAvatar(
          displayName: user.fullName,
          profilePictureUrl: user.profilePicture,
          radius: 24,
          cacheVersion: DateTime.now().millisecondsSinceEpoch,
        ),
        title: Text(
          user.fullName,
          style: AppStyling.subheadingStyle.copyWith(fontSize: 15),
        ),
        subtitle: Text(
          '@${user.username}',
          style: AppStyling.captionStyle,
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppStyling.primaryBlue,
        ),
        onTap: () => _navigateToUserProfile(user.id),
      ),
    );
  }
}
