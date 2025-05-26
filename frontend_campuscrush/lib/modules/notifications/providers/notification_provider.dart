import 'package:flutter/material.dart';

import '../models/notification.dart';
import '../../../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  NotificationProvider({
    required NotificationService notificationService,
  }) : _notificationService = notificationService;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  Future<void> getNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _setLoading(true);
    if (refresh) {
      _notifications = [];
    }

    try {
      final notifications = await _notificationService.getNotifications();
      _notifications = notifications;
      _updateUnreadCount();
      _setError(null);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final result = await _notificationService.markAsRead(notificationId);

      if (result != null) {
        _updateNotificationReadStatus(notificationId, true);
      } else {
        _setError("Failed to mark notification as read");
      }
    } catch (e) {
      _handleError('Error marking notification as read', e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final result = await _notificationService.markAllAsRead();

      if (result != null) {
        _markAllNotificationsAsRead();
      } else {
        _setError("Failed to mark all notifications as read");
      }
    } catch (e) {
      _handleError('Error marking all notifications as read', e);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final result =
          await _notificationService.deleteNotification(notificationId);

      if (result != null) {
        _removeNotification(notificationId);
      } else {
        _setError("Failed to delete notification");
      }
    } catch (e) {
      _handleError('Error deleting notification', e);
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final result = await _notificationService.deleteAllNotifications();

      if (result != null) {
        _clearNotifications();
      } else {
        _setError("Failed to delete all notifications");
      }
    } catch (e) {
      _handleError('Error deleting all notifications', e);
    }
  }

  void clearError() {
    _setError(null);
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMessage) {
    _error = errorMessage;
    if (_error != null && _error!.startsWith('Exception: ')) {
      _error = _error!.substring('Exception: '.length);
    }
    notifyListeners();
  }

  void _handleError(String context, Object error) {
    debugPrint('$context: $error');
    _setError(error.toString());
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  void _updateNotificationReadStatus(String notificationId, bool isRead) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: isRead);
      _updateUnreadCount();
      notifyListeners();
    }
  }

  void _markAllNotificationsAsRead() {
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
  }

  void _removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _updateUnreadCount();
    notifyListeners();
  }

  void _clearNotifications() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }
}
