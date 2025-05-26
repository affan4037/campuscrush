import 'package:flutter/material.dart';
import '../models/friendship_status.dart';

/// A reusable button widget that displays the appropriate friendship action
/// based on the current friendship status between two users
class FriendshipActionButton extends StatelessWidget {
  /// The current friendship status
  final FriendshipStatus status;

  /// Callback for when the user wants to send a friend request
  final VoidCallback? onSendRequest;

  /// Callback for when the user wants to cancel a friend request
  final VoidCallback? onCancelRequest;

  /// Callback for when the user wants to accept a friend request
  final VoidCallback? onAcceptRequest;

  /// Callback for when the user wants to reject a friend request
  final VoidCallback? onRejectRequest;

  /// Callback for when the user wants to remove a friend
  final VoidCallback? onRemoveFriend;

  /// Whether to show both accept and reject buttons for pending received requests
  final bool showBothAcceptRejectButtons;

  /// Whether a request exists that can be deleted (used for showing Delete Request button)
  final bool requestExists;

  // Common UI constants
  static const double _borderRadius = 20.0;
  static const double _standardSpacing = 10.0;
  static const double _compactThreshold = 200.0;
  static const double _extraCompactThreshold = 120.0;
  static const double _superCompactThreshold = 80.0;

  const FriendshipActionButton({
    Key? key,
    required this.status,
    this.onSendRequest,
    this.onCancelRequest,
    this.onAcceptRequest,
    this.onRejectRequest,
    this.onRemoveFriend,
    this.showBothAcceptRejectButtons = true,
    this.requestExists = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Friends status has priority and is handled separately
    if (status == FriendshipStatus.friends) {
      return _buildFriendsButton();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < _compactThreshold;

      // Handle cancellable request with status button
      if (requestExists && onCancelRequest != null) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCancelRequestButton(),
            const SizedBox(width: _standardSpacing),
            _buildStatusButton(context, isCompact),
          ],
        );
      }

      // Otherwise show the regular status button
      return _buildStatusBasedButton(context, isCompact);
    });
  }

  Widget _buildFriendsButton() {
    return OutlinedButton.icon(
      onPressed: onRemoveFriend ?? () {},
      icon: const Icon(Icons.check_circle, color: Colors.green),
      label: const Text(
        'Friends',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: const Color.fromRGBO(0, 255, 0, 0.1),
        side: const BorderSide(color: Colors.green),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
      ),
    );
  }

  Widget _buildCancelRequestButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 0, 0, 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromRGBO(255, 0, 0, 0.3)),
      ),
      child: IconButton(
        onPressed: onCancelRequest,
        icon: const Icon(Icons.cancel, color: Colors.red),
        tooltip: 'Cancel Request',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildStatusBasedButton(BuildContext context, bool isCompact) {
    switch (status) {
      case FriendshipStatus.notFriends:
        return _buildAddFriendButton(context, isCompact);
      case FriendshipStatus.pendingSent:
        return _buildPendingSentButton(isCompact);
      case FriendshipStatus.pendingReceived:
        return showBothAcceptRejectButtons
            ? _buildAcceptRejectButtonRow(context, isCompact)
            : _buildAcceptButton(context, isCompact);
      case FriendshipStatus.self:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusButton(BuildContext context, bool isCompact) {
    switch (status) {
      case FriendshipStatus.notFriends:
        return _buildAddFriendButton(context, isCompact);
      case FriendshipStatus.pendingSent:
        return _buildPendingSentButton(isCompact);
      case FriendshipStatus.pendingReceived:
        return _buildAcceptButton(context, isCompact);
      case FriendshipStatus.self:
      default:
        return const SizedBox.shrink();
    }
  }

  EdgeInsetsGeometry _getPadding(bool isCompact) {
    return EdgeInsets.symmetric(
      horizontal: isCompact ? 8 : 16,
      vertical: isCompact ? 8 : 12,
    );
  }

  EdgeInsetsGeometry _getResponsivePadding(
      bool isCompact, bool isExtraCompact) {
    if (isExtraCompact) {
      return const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 2,
      );
    }
    return EdgeInsets.symmetric(
      horizontal: isCompact ? 6 : 10,
      vertical: isCompact ? 4 : 6,
    );
  }

  Widget _buildAddFriendButton(BuildContext context, bool isCompact) {
    return LayoutBuilder(builder: (context, constraints) {
      // Further adjust compactness based on available width
      final isExtraCompact = constraints.maxWidth < _extraCompactThreshold;
      final isSuperCompact = constraints.maxWidth < _superCompactThreshold;

      // Adjust icon size based on available width
      final double iconSize = isSuperCompact ? 14 : (isExtraCompact ? 16 : 18);

      // For super compact mode, just show icon without text
      if (isSuperCompact) {
        return IconButton(
          onPressed: onSendRequest ?? () {},
          icon: Icon(Icons.person_add, size: iconSize),
          tooltip: 'Add Friend',
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
          ),
        );
      }

      return Container(
        height: 30,
        constraints: BoxConstraints(
          maxWidth: isExtraCompact ? 50 : 60,
        ),
        child: ElevatedButton(
          onPressed: onSendRequest ?? () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            padding: _getResponsivePadding(isCompact, isExtraCompact),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: Size.zero,
            alignment: Alignment.center,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Add',
              style: TextStyle(
                fontSize: isExtraCompact ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildPendingSentButton(bool isCompact) {
    return OutlinedButton.icon(
      onPressed: null, // Disabled as request is already sent
      icon: const Icon(Icons.hourglass_top, color: Colors.orange),
      label: Text(
        isCompact ? 'Pending' : 'Request Sent',
        style: TextStyle(
          color: Colors.orange[700],
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: _getPadding(isCompact),
        backgroundColor: const Color.fromRGBO(255, 165, 0, 0.1),
        side: BorderSide(color: Colors.orange[300]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
      ),
    );
  }

  Widget _buildAcceptButton(BuildContext context, bool isCompact) {
    return ElevatedButton.icon(
      onPressed: onAcceptRequest ?? () {},
      icon: isCompact ? null : const Icon(Icons.check_circle),
      label: Text(isCompact ? 'Accept' : 'Accept Request'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        padding: _getPadding(isCompact),
      ),
    );
  }

  Widget _buildAcceptRejectButtonRow(BuildContext context, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _buildAcceptButton(context, isCompact)),
        SizedBox(width: isCompact ? 4 : 8),
        Flexible(
          child: OutlinedButton.icon(
            onPressed: onRejectRequest ?? () {},
            icon: isCompact ? null : const Icon(Icons.close, color: Colors.red),
            label: const Text(
              'Decline',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_borderRadius),
              ),
              side: const BorderSide(color: Colors.red),
              padding: _getPadding(isCompact),
            ),
          ),
        ),
      ],
    );
  }
}
