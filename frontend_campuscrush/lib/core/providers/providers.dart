import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../di/dependency_injection.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/posts/providers/post_provider.dart';
import '../../modules/posts/services/post_service.dart';
import '../../modules/notifications/providers/notification_provider.dart';
import '../../modules/home_feed/providers/home_feed_provider.dart';
import '../../modules/home_feed/services/home_feed_service.dart';
import '../../modules/user_management/providers/user_provider.dart';
import '../../modules/posts/reactions/providers/reaction_provider.dart';
import '../../modules/google_auth/services/google_auth_service.dart';
import '../../modules/google_auth/providers/google_auth_provider.dart';

/// Central widget that provides all application services and providers
class AppProviders extends StatelessWidget {
  final Widget child;
  final AuthService authService;
  final ApiService apiService;
  final StorageService? storageService;
  final GoogleAuthService googleAuthService;

  const AppProviders({
    super.key,
    required this.child,
    required this.authService,
    required this.apiService,
    this.storageService,
    required this.googleAuthService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _buildProviders(),
      child: child,
    );
  }

  List<SingleChildWidget> _buildProviders() {
    return [
      // Service providers
      _createChangeNotifierProvider<AuthService>(),
      _createProvider<ApiService>(),
      _createProvider<StorageService>(),
      _createProvider<NotificationService>(),
      _createProvider<PostService>(),
      _createProvider<HomeFeedService>(),
      _createChangeNotifierProvider<GoogleAuthService>(),

      // State providers
      _createChangeNotifierProvider<AuthProvider>(),
      _createChangeNotifierProvider<PostProvider>(),
      _createChangeNotifierProvider<NotificationProvider>(),
      _createChangeNotifierProvider<HomeFeedProvider>(),
      _createChangeNotifierProvider<UserProvider>(),
      _createChangeNotifierProvider<ReactionProvider>(),
      _createChangeNotifierProvider<GoogleAuthProvider>(),
    ];
  }

  Provider<T> _createProvider<T extends Object>() {
    return Provider<T>.value(value: DependencyInjection.get<T>());
  }

  ChangeNotifierProvider<T> _createChangeNotifierProvider<T extends ChangeNotifier>() {
    return ChangeNotifierProvider<T>.value(value: DependencyInjection.get<T>());
  }
}
