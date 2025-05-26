import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/api_service.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/empty_state.dart';
import '../../../core/routes/app_router.dart';
import '../../user_management/models/user.dart';
import '../../user_management/services/user_search_service.dart';
import '../models/friendship.dart';
import '../models/friendship_status.dart';
import '../widgets/friendship_action_button.dart';
import '../services/friendship_service.dart';

/// Screen for managing friend requests and finding friends
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  FriendRequestsScreenState createState() => FriendRequestsScreenState();
}

class FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FriendshipService _friendshipService;
  late UserSearchService _userSearchService;

  // Reference to the received tab to allow refreshing
  final GlobalKey<ReceivedRequestsTabState> _receivedTabKey =
      GlobalKey<ReceivedRequestsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final apiService = Provider.of<ApiService>(context, listen: false);
    _friendshipService = FriendshipService(apiService);
    _userSearchService = UserSearchService(apiService);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Method to refresh the current tab
  void refreshCurrentTab() {
    final currentIndex = _tabController.index;
    if (currentIndex == 0) {
      // Received requests tab
      _receivedTabKey.currentState?.loadRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
            Tab(text: 'Find Friends'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshCurrentTab,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ReceivedRequestsTab(
            key: _receivedTabKey,
            friendshipService: _friendshipService,
            userSearchService: _userSearchService,
          ),
          SentRequestsTab(friendshipService: _friendshipService),
          FindFriendsTab(
            userSearchService: _userSearchService,
            friendshipService: _friendshipService,
          ),
        ],
      ),
    );
  }
}

/// Base class for request tabs with common functionality
abstract class BaseRequestTabState<T extends StatefulWidget> extends State<T> {
  bool _isLoading = false;
  String? _error;
  List<FriendshipRequest> _requests = [];

  /// Load requests from the server
  Future<void> loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requests = await fetchRequests();

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      handleError(e);
    }
  }

  /// Fetch requests from the server - to be implemented by subclasses
  Future<List<FriendshipRequest>> fetchRequests();

  /// Handle errors during request loading
  void handleError(dynamic e) {
    String errorMessage = 'Failed to load requests';

    if (e.toString().contains('not a sub type of')) {
      errorMessage =
          'Server response format error. Please try again or contact support.';
    } else if (e.toString().contains('Connection')) {
      errorMessage =
          'Network connection error. Please check your internet connection.';
    } else {
      errorMessage =
          'Failed to load requests: ${e.toString().split('Exception:').last.trim()}';
    }

    setState(() {
      _error = errorMessage;
      _isLoading = false;
    });
  }

  /// Show a success snackbar
  void showSuccessSnackbar(BuildContext context, String message,
      {bool isCelebration = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: isCelebration
            ? const Row(
                children: [
                  Icon(Icons.celebration, color: Colors.yellow),
                  SizedBox(width: 10),
                  Text('Hooray! You are now friends!'),
                ],
              )
            : Text(message),
        backgroundColor: isCelebration ? Colors.green : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show an error snackbar
  void showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Build the request list item
  Widget buildRequestItem(
    BuildContext context,
    FriendshipRequest request, {
    required User? user,
    required String userId,
    required FriendshipStatus status,
    required Function(String) onAction,
    String? actionLabel,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ProfileAvatar(
          profilePictureUrl: user?.profilePicture,
          radius: 24,
        ),
        title: Text(
          user?.fullName ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(user?.username ?? ''),
        trailing: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.4,
            minWidth: 120,
          ),
          child: FriendshipActionButton(
            status: status,
            onAcceptRequest:
                actionLabel == 'Accept' ? () => onAction(request.id) : null,
            onRejectRequest:
                actionLabel == 'Reject' ? () => onAction(request.id) : null,
            onCancelRequest:
                actionLabel == 'Cancel' ? () => onAction(request.id) : null,
          ),
        ),
        onTap: () {
          if (user != null) {
            Navigator.pushNamed(
              context,
              AppRouter.userProfile,
              arguments: {
                'userId': userId,
                'isCurrentUser': false,
              },
            );
          }
        },
      ),
    );
  }

  /// Build the main content of the tab
  Widget buildContent() {
    if (_isLoading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorDisplay(
          error: _error!,
          onRetry: loadRequests,
          details:
              'An error occurred while loading friend requests. This might be due to a network issue or server problem.',
        ),
      );
    }

    if (_requests.isEmpty) {
      return buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: loadRequests,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        itemCount: _requests.length,
        itemBuilder: (ctx, index) => buildRequestItemBuilder(ctx, index),
      ),
    );
  }

  /// Build the empty state widget - to be implemented by subclasses
  Widget buildEmptyState();

  /// Build the request item - to be implemented by subclasses
  Widget buildRequestItemBuilder(BuildContext context, int index);
}

/// Tab for displaying received friend requests
class ReceivedRequestsTab extends StatefulWidget {
  final FriendshipService friendshipService;
  final UserSearchService userSearchService;

  const ReceivedRequestsTab({
    Key? key,
    required this.friendshipService,
    required this.userSearchService,
  }) : super(key: key);

  @override
  ReceivedRequestsTabState createState() => ReceivedRequestsTabState();
}

class ReceivedRequestsTabState
    extends BaseRequestTabState<ReceivedRequestsTab> {
  final Map<String, User> _cachedUsers = {};
  late UserSearchService _userSearchService;

  @override
  void initState() {
    super.initState();
    _userSearchService = widget.userSearchService;
    loadRequests();
  }

  @override
  Future<List<FriendshipRequest>> fetchRequests() async {
    final requests = await widget.friendshipService.getReceivedFriendRequests();

    await _fetchMissingSenderData(requests);
    return requests;
  }

  Future<void> _fetchMissingSenderData(List<FriendshipRequest> requests) async {
    for (int i = 0; i < requests.length; i++) {
      final request = requests[i];
      if (_needsUserData(request)) {
        if (_cachedUsers.containsKey(request.senderId)) {
          requests[i] =
              request.copyWith(sender: _cachedUsers[request.senderId]);
        } else {
          try {
            final user = await _userSearchService.getUserById(request.senderId);
            if (user != null) {
              _cachedUsers[request.senderId] = user;
              requests[i] = request.copyWith(sender: user);
            }
          } catch (e) {
            // Continue with next request
          }
        }
      }
    }
  }

  bool _needsUserData(FriendshipRequest request) {
    return request.sender == null ||
        request.sender?.fullName == 'Anonymous User';
  }

  Future<void> _acceptRequest(String requestId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await widget.friendshipService.acceptFriendRequest(requestId);

      if (!mounted) return;
      setState(() {
        _requests.removeWhere((request) => request.id == requestId);
        _isLoading = false;
      });

      showSuccessSnackbar(context, 'Friend request accepted',
          isCelebration: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackbar(context, 'Failed to accept request: $e');
    }
  }

  @override
  Widget buildEmptyState() {
    return EmptyState.noFriendRequests();
  }

  @override
  Widget buildRequestItemBuilder(BuildContext context, int index) {
    final request = _requests[index];

    if (_hasValidSender(request)) {
      return _buildRequestItemWithUser(context, request, request.sender!);
    }

    if (_shouldFetchUserData(request)) {
      _fetchUserDataAndUpdateUI(request);
    }

    final User? cachedUser = _cachedUsers[request.senderId];
    if (cachedUser != null) {
      return _buildRequestItemWithUser(context, request, cachedUser);
    }

    return _buildRequestItemWithUserId(context, request);
  }

  bool _hasValidSender(FriendshipRequest request) {
    return request.sender != null &&
        request.sender!.fullName != 'Anonymous User';
  }

  bool _shouldFetchUserData(FriendshipRequest request) {
    return request.senderId.isNotEmpty &&
        (!_cachedUsers.containsKey(request.senderId) ||
            _cachedUsers[request.senderId]!.fullName == 'Anonymous User');
  }

  void _fetchUserDataAndUpdateUI(FriendshipRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final user = await _userSearchService.getUserById(request.senderId);

        if (user != null && mounted) {
          setState(() {
            _cachedUsers[request.senderId] = user;

            final idx = _requests.indexWhere((r) => r.id == request.id);
            if (idx >= 0 && idx < _requests.length) {
              _requests[idx] = request.copyWith(sender: user);
            }
          });
        }
      } catch (e) {
        // Silent failure
      }
    });
  }

  Widget _buildRequestItemWithUser(
      BuildContext context, FriendshipRequest request, User user) {
    return buildRequestItem(
      context,
      request,
      user: user,
      userId: request.senderId,
      status: FriendshipStatus.pendingReceived,
      onAction: (id) => _acceptRequest(id),
      actionLabel: 'Accept',
    );
  }

  Widget _buildRequestItemWithUserId(
      BuildContext context, FriendshipRequest request) {
    final tempUser = _createTempUserFromId(request.senderId);

    return buildRequestItem(
      context,
      request,
      user: tempUser,
      userId: request.senderId,
      status: FriendshipStatus.pendingReceived,
      onAction: (id) => _acceptRequest(id),
      actionLabel: 'Accept',
    );
  }

  User _createTempUserFromId(String userId) {
    return User(
      id: userId,
      username: 'user_${userId.substring(0, userId.length.clamp(0, 8))}',
      email: '',
      fullName: 'User ${userId.substring(0, userId.length.clamp(0, 5))}',
      university: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildContent();
  }
}

/// Tab for displaying sent friend requests
class SentRequestsTab extends StatefulWidget {
  final FriendshipService friendshipService;

  const SentRequestsTab({
    Key? key,
    required this.friendshipService,
  }) : super(key: key);

  @override
  SentRequestsTabState createState() => SentRequestsTabState();
}

class SentRequestsTabState extends BaseRequestTabState<SentRequestsTab> {
  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  @override
  Future<List<FriendshipRequest>> fetchRequests() async {
    return await widget.friendshipService.getSentFriendRequests();
  }

  Future<void> _cancelRequest(String requestId) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await widget.friendshipService.cancelFriendRequest(requestId);

      if (!mounted) return;
      setState(() {
        _requests.removeWhere((request) => request.id == requestId);
        _isLoading = false;
      });

      showSuccessSnackbar(context, 'Friend request canceled');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackbar(context, 'Failed to cancel request: $e');
    }
  }

  @override
  Widget buildEmptyState() {
    return EmptyState.noSentRequests();
  }

  @override
  Widget buildRequestItemBuilder(BuildContext context, int index) {
    final request = _requests[index];

    return buildRequestItem(
      context,
      request,
      user: request.receiver,
      userId: request.receiverId,
      status: FriendshipStatus.pendingSent,
      onAction: (id) => _cancelRequest(id),
      actionLabel: 'Cancel',
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildContent();
  }
}

/// Tab for finding and adding friends
class FindFriendsTab extends StatefulWidget {
  final UserSearchService userSearchService;
  final FriendshipService friendshipService;

  const FindFriendsTab({
    Key? key,
    required this.userSearchService,
    required this.friendshipService,
  }) : super(key: key);

  @override
  FindFriendsTabState createState() => FindFriendsTabState();
}

class FindFriendsTabState extends State<FindFriendsTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  List<User> _searchResults = [];
  final Map<String, FriendshipStatus> _friendshipStatuses = {};
  final Map<String, String> _requestIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await widget.userSearchService.searchUsers(query);

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

      _checkFriendshipStatusForResults();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to search users: $e';
        _isLoading = false;
      });
    }
  }

  void _checkFriendshipStatusForResults() {
    for (final user in _searchResults) {
      if (mounted) {
        _checkFriendshipStatus(user.id);
      }
    }
  }

  Future<void> _checkFriendshipStatus(String userId) async {
    try {
      final friendshipDetails =
          await widget.friendshipService.getFriendshipDetails(userId);

      if (!mounted) return;
      setState(() {
        _friendshipStatuses[userId] = friendshipDetails.status;
        if (friendshipDetails.requestId != null) {
          _requestIds[userId] = friendshipDetails.requestId!;
        }
      });
    } catch (e) {
      // Silent failure for background status checks
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      final request = await widget.friendshipService.sendFriendRequest(userId);

      if (!mounted) return;
      setState(() {
        _friendshipStatuses[userId] = FriendshipStatus.pendingSent;
        _requestIds[userId] = request.id;
      });

      _showSnackBar('Friend request sent');
    } catch (e) {
      if (!mounted) return;

      // Handle type error that indicates successful request
      if (_isSuccessfulDespiteTypeError(e)) {
        setState(() {
          _friendshipStatuses[userId] = FriendshipStatus.pendingSent;
        });

        _showSnackBar('Friend request sent');
        return;
      }

      _showSnackBar('Failed to send friend request: $e');
    }
  }

  bool _isSuccessfulDespiteTypeError(dynamic error) {
    final errorStr = error.toString();
    return errorStr.contains('_Map<String, dynamic>') &&
        errorStr.contains('not a subtype of type');
  }

  Future<void> _cancelFriendRequest(String userId) async {
    final requestId = _requestIds[userId];
    if (requestId == null) return;

    try {
      await widget.friendshipService.cancelFriendRequest(requestId);

      if (!mounted) return;
      setState(() {
        _friendshipStatuses[userId] = FriendshipStatus.notFriends;
        _requestIds.remove(userId);
      });

      _showSnackBar('Friend request canceled');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to cancel request: $e');
    }
  }

  Future<void> _acceptFriendRequest(String userId) async {
    final requestId = _requestIds[userId];
    if (requestId == null) return;

    try {
      await widget.friendshipService.acceptFriendRequest(requestId);

      if (!mounted) return;
      setState(() {
        _friendshipStatuses[userId] = FriendshipStatus.friends;
        _requestIds.remove(userId);
      });

      _showCelebrationSnackBar();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to accept request: $e');
    }
  }

  void _showCelebrationSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.celebration, color: Colors.yellow),
            SizedBox(width: 10),
            Text('Hooray! You are now friends!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _removeFriend(String userId) async {
    try {
      await widget.friendshipService.removeFriend(userId);

      if (!mounted) return;
      setState(() {
        _friendshipStatuses[userId] = FriendshipStatus.notFriends;
      });

      _showSnackBar('Friend removed');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to remove friend: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchField(),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _buildErrorDisplay()
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          Expanded(child: EmptyState.noSearchResults())
        else if (_searchController.text.isEmpty)
          Expanded(child: EmptyState.search())
        else
          _buildSearchResultsList(),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search for people',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                    });
                  },
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (value.length >= 2) {
            _searchUsers(value);
          } else if (value.isEmpty) {
            setState(() {
              _searchResults = [];
            });
          }
        },
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ErrorDisplay(
        error: _error!,
        onRetry: () => _searchUsers(_searchController.text),
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) =>
            _buildUserListItem(_searchResults[index]),
      ),
    );
  }

  Widget _buildUserListItem(User user) {
    final status = _friendshipStatuses[user.id] ?? FriendshipStatus.notFriends;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: ProfileAvatar(
          profilePictureUrl: user.profilePicture,
          radius: 24,
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(user.username),
        trailing: SizedBox(
          width: 110,
          child: _buildFriendshipButton(user.id, status),
        ),
        onTap: () => Navigator.pushNamed(
          context,
          AppRouter.userProfile,
          arguments: {
            'userId': user.id,
            'isCurrentUser': false,
          },
        ),
      ),
    );
  }

  Widget _buildFriendshipButton(String userId, FriendshipStatus status) {
    return FriendshipActionButton(
      status: status,
      showBothAcceptRejectButtons: false,
      onSendRequest: () => _sendFriendRequest(userId),
      onCancelRequest: () => _cancelFriendRequest(userId),
      onAcceptRequest: () => _acceptFriendRequest(userId),
      onRemoveFriend: () => _removeFriend(userId),
      requestExists: _requestIds.containsKey(userId),
    );
  }
}
