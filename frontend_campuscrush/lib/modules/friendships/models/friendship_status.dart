enum FriendshipStatus {
  /// No relationship
  notFriends,

  /// The users are friends
  friends,

  /// Current user has sent a request to the other user
  pendingSent,

  /// Current user has received a request from the other user
  pendingReceived,

  /// The current user is viewing their own profile
  self,
}

/// Extension to provide helper methods for the FriendshipStatus enum
extension FriendshipStatusExtension on FriendshipStatus {
  /// Convert API string representation to enum value
  static FriendshipStatus fromString(String? status) {
    if (status == null) return FriendshipStatus.notFriends;

    switch (status.toLowerCase()) {
      case 'friends':
        return FriendshipStatus.friends;
      case 'request_sent':
      case 'pending_sent':
        return FriendshipStatus.pendingSent;
      case 'request_received':
      case 'pending_received':
        return FriendshipStatus.pendingReceived;
      case 'self':
        return FriendshipStatus.self;
      case 'not_friends':
      default:
        return FriendshipStatus.notFriends;
    }
  }

  /// Convert enum value to string representation for UI
  String get displayName {
    switch (this) {
      case FriendshipStatus.friends:
        return 'Friends';
      case FriendshipStatus.pendingSent:
        return 'Request Sent';
      case FriendshipStatus.pendingReceived:
        return 'Accept Request';
      case FriendshipStatus.notFriends:
        return 'Add Friend';
      case FriendshipStatus.self:
        return '';
    }
  }

  /// Convert enum value to string representation for API
  String get apiValue {
    switch (this) {
      case FriendshipStatus.friends:
        return 'friends';
      case FriendshipStatus.pendingSent:
        return 'request_sent';
      case FriendshipStatus.pendingReceived:
        return 'request_received';
      case FriendshipStatus.notFriends:
        return 'not_friends';
      case FriendshipStatus.self:
        return 'self';
    }
  }

  /// Check if the status represents a pending state
  bool get isPending =>
      this == FriendshipStatus.pendingSent ||
      this == FriendshipStatus.pendingReceived;

  /// Check if the status represents an active friendship
  bool get isActive => this == FriendshipStatus.friends;
}
