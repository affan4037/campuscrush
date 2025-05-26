import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Screens
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/register_screen.dart';
import '../../modules/auth/screens/delete_user_screen.dart';
import '../../modules/user_management/screens/profile_screen.dart';
import '../../modules/user_management/screens/edit_profile_screen.dart';
import '../../modules/user_management/screens/user_profile_screen.dart';
import '../../screens/home_screen.dart';
import '../../modules/posts/screens/create_post_screen.dart';
import '../../modules/posts/screens/post_detail_screen.dart';
import '../../modules/posts/comments/screens/comments_screen.dart';
import '../../modules/friendships/screens/friends_screen.dart';
import '../../modules/friendships/screens/friend_requests_screen.dart';
import '../../modules/notifications/screens/notifications_screen.dart';
import '../../modules/splash/screens/splash_screen.dart';
import '../../modules/google_auth/screens/google_signin_screen.dart';

/// Manages application routing
class AppRouter {
  // Private constructor to prevent instantiation
  AppRouter._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String googleSignIn = '/google-signin';
  static const String deleteUser = '/delete-user';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String userProfile = '/user-profile';
  static const String editProfile = '/edit-profile';
  static const String createPost = '/create-post';
  static const String postDetail = '/post-detail';
  static const String comments = '/comments';
  static const String friends = '/friends';
  static const String friendRequests = '/friend-requests';
  static const String notifications = '/notifications';
  static const String microsoftCallback = '/auth/microsoft-callback';
  static const String debugSection = '/debug';

  /// Creates a MaterialPageRoute with the provided builder
  static MaterialPageRoute<T> _createRoute<T>(
      Widget Function(BuildContext) builder) {
    return MaterialPageRoute<T>(builder: builder);
  }

  /// Main route generator used by MaterialApp
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;

    // Standard routes
    switch (name) {
      case splash:
        return _createRoute((_) => const SplashScreen());
      case login:
        return _createRoute((_) => const LoginScreen());
      case register:
        return _createRoute((_) => const RegisterScreen());
      case googleSignIn:
        // Check if we have email parameter
        final args = settings.arguments as Map<String, dynamic>?;
        final email = args?['email'] as String?;
        return _createRoute((_) => GoogleSignInScreen(prefilledEmail: email));
      case home:
        return _createRoute((_) => const HomeScreen());
      case profile:
        return _createRoute((_) => const ProfileScreen());
      case editProfile:
        return _createRoute((_) => const EditProfileScreen());
      case createPost:
        return _createRoute((_) => const CreatePostScreen());
      case friendRequests:
        return _createRoute((_) => const FriendRequestsScreen());
      case notifications:
        return _createRoute((_) => const NotificationsScreen());
    }

    // Routes with arguments
    try {
      switch (name) {
        case deleteUser:
          return _createRoute(
              (_) => DeleteUserScreen(email: _getArgument<String>(settings)));
        case userProfile:
          final args = _getArgument<Map<String, dynamic>>(settings);
          return _createRoute((_) => UserProfileScreen(
                userId: args['userId'] ?? '',
                username: args['username'],
                isCurrentUser: args['isCurrentUser'] ?? false,
              ));
        case postDetail:
          return _createRoute(
              (_) => PostDetailScreen(postId: _getArgument<String>(settings)));
        case comments:
          final args = _getArgument<Map<String, dynamic>>(settings);
          return _createRoute((_) => CommentsScreen(
                postId: args['postId'],
                initialComments: args['initialComments'],
              ));
        case friends:
          return _createRoute(
              (_) => FriendsScreen(userId: settings.arguments as String?));
        case microsoftCallback:
          final token = settings.arguments as String? ?? '';
          return _createRoute(
              (ctx) => _buildMicrosoftCallbackScreen(token, ctx));
      }
    } catch (e) {
      debugPrint('Route error: $e');
      return _createErrorRoute(name, e.toString());
    }

    // Special routes
    if (_isDebugRoute(name) && kDebugMode) {
      return _createDebugRoute(name);
    }

    // Default - route not found
    return _createErrorRoute(name, 'Route not defined');
  }

  /// Safely extracts arguments from route settings with error handling
  static T _getArgument<T>(RouteSettings settings) {
    try {
      return settings.arguments as T;
    } catch (e) {
      throw Exception(
          'Invalid argument: expected ${T.toString()} for route ${settings.name}');
    }
  }

  /// Checks if a route is a debug route
  static bool _isDebugRoute(String? routeName) {
    return routeName?.startsWith(debugSection) == true;
  }

  /// Creates a debug route
  static Route<dynamic> _createDebugRoute(String? routeName) {
    return _createRoute((context) => Scaffold(
          appBar: AppBar(title: const Text('Debug Mode')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Debug Tools', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 20),
                Text('Current debug route: $routeName'),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed(home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ));
  }

  /// Creates an error route for undefined routes
  static Route<dynamic> _createErrorRoute(String? routeName,
      [String? errorMessage]) {
    return _createRoute((context) => Scaffold(
          appBar: AppBar(title: const Text('Route Not Found')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No route defined for $routeName',
                    style: Theme.of(context).textTheme.titleMedium),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(errorMessage,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed(home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ));
  }

  /// Builds Microsoft callback screen
  static Widget _buildMicrosoftCallbackScreen(
      String token, BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Microsoft Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Microsoft authentication in progress...'),
            Text('Token: $token'),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed(home),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns commonly used routes for MaterialApp.routes property
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (_) => const SplashScreen(),
      login: (_) => const LoginScreen(),
      register: (_) => const RegisterScreen(),
      googleSignIn: (_) => const GoogleSignInScreen(),
      home: (_) => const HomeScreen(),
      profile: (_) => const ProfileScreen(),
      editProfile: (_) => const EditProfileScreen(),
      createPost: (_) => const CreatePostScreen(),
      friendRequests: (_) => const FriendRequestsScreen(),
      notifications: (_) => const NotificationsScreen(),
    };
  }
}
