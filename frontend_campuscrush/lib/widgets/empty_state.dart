import 'package:flutter/material.dart';

/// A reusable widget for displaying empty states throughout the app
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Color iconColor;
  final Widget? actionButton;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.iconColor = Colors.grey,
    this.actionButton,
  });

  /// Factory constructor for the friends empty state
  factory EmptyState.noFriends({required VoidCallback onFindFriends}) {
    return EmptyState(
      icon: Icons.people_outline,
      title: 'No friends yet',
      description: 'Start connecting with people you may know',
      actionButton: ElevatedButton(
        onPressed: onFindFriends,
        child: const Text('Find Friends'),
      ),
    );
  }

  /// Factory constructor for the friend requests empty state
  factory EmptyState.noFriendRequests() {
    return const EmptyState(
      icon: Icons.people_outline,
      title: 'No friend requests',
      description:
          'When someone sends you a friend request, you\'ll see it here',
    );
  }

  /// Factory constructor for the sent requests empty state
  factory EmptyState.noSentRequests() {
    return const EmptyState(
      icon: Icons.people_outline,
      title: 'No sent requests',
      description: 'Friend requests you\'ve sent will appear here',
    );
  }

  /// Factory constructor for the search empty state
  factory EmptyState.search() {
    return const EmptyState(
      icon: Icons.search,
      title: 'Search for people',
      description: 'Find people by their name or username',
    );
  }

  /// Factory constructor for the no search results state
  factory EmptyState.noSearchResults() {
    return const EmptyState(
      icon: Icons.search_off,
      title: 'No users found',
      description: 'Try a different search term',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double iconSize = 72;
    const double defaultSpacing = 16;
    const double smallSpacing = 8;
    const double largeSpacing = 24;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(height: defaultSpacing),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: smallSpacing),
            Text(
              description!,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
          if (actionButton != null) ...[
            const SizedBox(height: largeSpacing),
            actionButton!,
          ],
        ],
      ),
    );
  }
}
