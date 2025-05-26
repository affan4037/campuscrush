import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/notification.dart';
import '../providers/notification_provider.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationItem({
    Key? key,
    required this.notification,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    return Dismissible(
      key: Key(notification.id),
      background: _buildDismissBackground(),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDismiss(context),
      onDismissed: (_) => _handleDismiss(context, notificationProvider),
      child: _buildNotificationCard(context, notificationProvider),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(
        Icons.delete,
        color: Colors.white,
      ),
    );
  }

  Future<bool> _confirmDismiss(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text("Confirm"),
            content: Text("Are you sure you want to delete this notification?"),
            actions: <Widget>[
              _CancelButton(),
              _DeleteButton(),
            ],
          ),
        ) ??
        false;
  }

  void _handleDismiss(BuildContext context, NotificationProvider provider) {
    provider.deleteNotification(notification.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification deleted')),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, NotificationProvider provider) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _onNotificationTap(context, provider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? null
              : AppColors.primaryLight.withOpacity(0.1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNotificationContent(theme),
            ),
            if (!notification.isRead) const _UnreadIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          timeago.format(notification.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _onNotificationTap(BuildContext context, NotificationProvider provider) {
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    _handleNotificationTap(context);
    if (onTap != null) onTap!();
  }

  Widget _buildAvatar() {
    final NotificationTypeConfig config = _getNotificationTypeConfig();
    return _buildAvatarWithIcon(config.icon, config.color);
  }

  NotificationTypeConfig _getNotificationTypeConfig() {
    switch (notification.type) {
      case NotificationType.friendshipRequest:
        return const NotificationTypeConfig(
          icon: Icon(Icons.person_add, color: Colors.white, size: 16),
          color: Colors.blue,
        );
      case NotificationType.friendAccepted:
        return const NotificationTypeConfig(
          icon: Icon(Icons.people, color: Colors.white, size: 16),
          color: Colors.green,
        );
      case NotificationType.postLike:
        return const NotificationTypeConfig(
          icon: Icon(Icons.thumb_up, color: Colors.white, size: 16),
          color: Colors.blue,
        );
      case NotificationType.postComment:
        return const NotificationTypeConfig(
          icon: Icon(Icons.comment, color: Colors.white, size: 16),
          color: Colors.amber,
        );
      case NotificationType.commentLike:
        return const NotificationTypeConfig(
          icon: Icon(Icons.thumb_up, color: Colors.white, size: 16),
          color: Colors.purple,
        );
      case NotificationType.mention:
        return const NotificationTypeConfig(
          icon: Icon(Icons.alternate_email, color: Colors.white, size: 16),
          color: Colors.teal,
        );
      case NotificationType.unknown:
        return const NotificationTypeConfig(
          icon: Icon(Icons.notifications, color: Colors.white, size: 16),
          color: Colors.grey,
        );
    }
  }

  Widget _buildAvatarWithIcon(Widget icon, Color backgroundColor) {
    if (notification.actor?.profilePicture != null) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(_getProfilePictureUrl()),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: icon,
            ),
          ),
        ],
      );
    } else {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, color: Colors.grey[600]),
      );
    }
  }

  String _getProfilePictureUrl() {
    if (notification.actor?.profilePicture == null) {
      return '${AppConstants.uiAvatarsBaseUrl}?name=${Uri.encodeComponent(notification.actor?.fullName ?? 'User')}&background=random';
    }

    // Use the safeProfilePictureUrl if User model has it implemented, otherwise use fixProfilePictureUrl
    return notification.actor!.safeProfilePictureUrl ??
        AppConstants.fixProfilePictureUrl(notification.actor!.profilePicture!);
  }

  void _handleNotificationTap(BuildContext context) {
    switch (notification.type) {
      case NotificationType.friendshipRequest:
        Navigator.of(context).pushNamed(AppRouter.friendRequests);
        break;
      case NotificationType.friendAccepted:
        Navigator.of(context).pushNamed(
          AppRouter.profile,
          arguments: notification.actorId,
        );
        break;
      case NotificationType.postLike:
      case NotificationType.postComment:
      case NotificationType.mention:
        _navigateToPostDetail(context);
        break;
      case NotificationType.commentLike:
        _navigateToComments(context);
        break;
      case NotificationType.unknown:
        break;
    }
  }

  void _navigateToPostDetail(BuildContext context) {
    if (notification.postId != null) {
      Navigator.of(context).pushNamed(
        AppRouter.postDetail,
        arguments: notification.postId,
      );
    }
  }

  void _navigateToComments(BuildContext context) {
    if (notification.postId != null) {
      Navigator.of(context).pushNamed(
        AppRouter.comments,
        arguments: {
          'postId': notification.postId,
          'initialComments': null,
        },
      );
    }
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: const Text("CANCEL"),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(true),
      child: const Text("DELETE"),
    );
  }
}

class _UnreadIndicator extends StatelessWidget {
  const _UnreadIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
    );
  }
}

class NotificationTypeConfig {
  final Widget icon;
  final Color color;

  const NotificationTypeConfig({
    required this.icon,
    required this.color,
  });
}
