import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/notification_provider.dart';

class NotificationCounter extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const NotificationCounter({
    Key? key,
    this.size = 24.0,
    this.color,
    this.badgeColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (_, provider, __) {
        final unreadCount = provider.unreadCount;
        return _buildNotificationIcon(unreadCount);
      },
    );
  }

  Widget _buildNotificationIcon(int unreadCount) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: size,
            color: color ?? Colors.black,
          ),
          if (unreadCount > 0) _buildCountBadge(unreadCount),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    final displayCount = count > 9 ? '9+' : count.toString();

    return Positioned(
      top: -5,
      right: -5,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: badgeColor ?? AppColors.primary,
          shape: BoxShape.circle,
        ),
        constraints: const BoxConstraints(
          minWidth: 16,
          minHeight: 16,
        ),
        child: Text(
          displayCount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
