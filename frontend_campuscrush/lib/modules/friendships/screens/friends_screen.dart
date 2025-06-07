import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/api_service.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../core/routes/app_router.dart';
import '../../user_management/models/user.dart';
import '../services/friendship_service.dart';

class FriendsScreen extends StatefulWidget {
  final String? userId;

  const FriendsScreen({Key? key, this.userId}) : super(key: key);

  @override
  FriendsScreenState createState() => FriendsScreenState();
}

class FriendsScreenState extends State<FriendsScreen> {
  bool _isLoading = false;
  String? _error;
  List<User> _friends = [];
  late FriendshipService _friendshipService;

  @override
  void initState() {
    super.initState();
    _friendshipService =
        FriendshipService(Provider.of<ApiService>(context, listen: false));
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final friends = await _friendshipService.getFriends();

      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load friends: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    try {
      await _friendshipService.removeFriend(friendId);

      if (mounted) {
        setState(() {
          _friends.removeWhere((friend) => friend.id == friendId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove friend: $e')),
        );
      }
    }
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

  void _showFriendOptions(User friend) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text('View ${friend.fullName}\'s Profile'),
            onTap: () {
              Navigator.pop(context);
              _navigateToUserProfile(friend.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text('Remove ${friend.fullName} as Friend',
                style: const TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showRemoveFriendConfirmation(friend);
            },
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendConfirmation(User friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
            'Are you sure you want to remove ${friend.fullName} as a friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend.id);
            },
            child: const Text('REMOVE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () =>
                Navigator.pushNamed(context, AppRouter.friendRequests),
            tooltip: 'Friend Requests',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFriends,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorDisplay(
        error: _error!,
        onRetry: _loadFriends,
      );
    }

    if (_friends.isEmpty) {
      return _buildEmptyState();
    }

    return _buildFriendsList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No friends yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start connecting with people you may know',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRouter.friendRequests),
            child: const Text('Find Friends'),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          child: ListTile(
            leading: ProfileAvatar(
              profilePictureUrl: friend.profilePicture,
              radius: 24,
            ),
            title: Text(
              friend.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(friend.username),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showFriendOptions(friend),
            ),
            onTap: () => _navigateToUserProfile(friend.id),
          ),
        );
      },
    );
  }
}
