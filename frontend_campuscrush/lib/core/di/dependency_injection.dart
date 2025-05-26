import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../core/constants/app_constants.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/auth/services/auth_api_service.dart';
import '../../modules/friendships/services/friendship_service.dart';
import '../../modules/google_auth/providers/google_auth_provider.dart';
import '../../modules/google_auth/services/google_auth_service.dart';
import '../../modules/home_feed/providers/home_feed_provider.dart';
import '../../modules/home_feed/services/home_feed_service.dart';
import '../../modules/notifications/providers/notification_provider.dart';
import '../../modules/posts/comments/services/comments_service.dart';
import '../../modules/posts/providers/post_provider.dart';
import '../../modules/posts/reactions/providers/reaction_provider.dart';
import '../../modules/posts/services/post_service.dart';
import '../../modules/user_management/providers/user_provider.dart';
import '../../modules/user_management/services/profile_picture_service.dart';
import '../../modules/user_management/services/user_api_service.dart';
import '../../modules/user_management/services/user_search_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';

/// Global GetIt instance for dependency injection
final getIt = GetIt.instance;

/// Manages dependency registrations and initializations
class DependencyInjection {
  DependencyInjection._();

  static bool _initialized = false;
  static bool _emergencyInitialized = false;

  /// Initialize all dependencies
  static Future<void> init({required String baseUrl}) async {
    if (_initialized) return;

    _initEmergencyServices(baseUrl: baseUrl);
    await _initAsyncServices();

    _initialized = true;
  }

  /// Initialize critical services needed for app startup
  static void _initEmergencyServices({required String baseUrl}) {
    if (_emergencyInitialized) return;

    final effectiveBaseUrl = _resolveBaseUrl(baseUrl);
    final apiService = ApiService(baseUrl: effectiveBaseUrl);
    getIt.registerSingleton<ApiService>(apiService);
    getIt.registerSingletonAsync<StorageService>(StorageService.init);

    _registerIndependentServices(apiService);
    _emergencyInitialized = true;
  }

  static String _resolveBaseUrl(String baseUrl) {
    const currentBaseUrl = AppConstants.baseUrl;
    if (baseUrl != currentBaseUrl) {
      if (kDebugMode) {
        debugPrint('Using baseUrl from AppConstants: $currentBaseUrl');
      }
      return currentBaseUrl;
    }
    return baseUrl;
  }

  static void _registerIndependentServices(ApiService apiService) {
    getIt.registerSingleton<UserApiService>(UserApiService(apiService));
    getIt.registerLazySingleton<UserSearchService>(
        () => UserSearchService(apiService));
    getIt.registerLazySingleton<ProfilePictureService>(
        () => ProfilePictureService(apiService));
    getIt.registerLazySingleton<FriendshipService>(
        () => FriendshipService(apiService));
  }

  /// Initialize services that require async initialization
  static Future<void> _initAsyncServices() async {
    try {
      final storageService = await getIt.getAsync<StorageService>();
      final apiService = getIt<ApiService>();

      _registerAuthServices(apiService, storageService);
      _registerFeatureServices(apiService, getIt<AuthService>());
      _registerProviders();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing services: $e');
      }
      rethrow;
    }
  }

  static void _registerAuthServices(
      ApiService apiService, StorageService storageService) {
    final authService = AuthService(apiService, storageService);
    getIt.registerSingleton<AuthService>(authService);

    getIt.registerSingleton<GoogleAuthService>(
        GoogleAuthService(apiService, storageService));
    getIt.registerLazySingleton<AuthApiService>(
        () => AuthApiService(apiService));
  }

  static void _registerFeatureServices(
      ApiService apiService, AuthService authService) {
    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(authService: authService),
    );
    getIt.registerLazySingleton<PostService>(() => PostService(apiService));
    getIt.registerLazySingleton<HomeFeedService>(
        () => HomeFeedService(apiService, authService));
    getIt.registerFactory<CommentsService>(() => CommentsService(
          apiService: apiService,
          authService: authService,
        ));
  }

  /// Register all providers
  static void _registerProviders() { 
    getIt.registerLazySingleton<AuthProvider>(() => AuthProvider(
          apiService: getIt<ApiService>(),
          storageService: getIt<StorageService>(),
        ));

    getIt.registerLazySingleton<PostProvider>(() => PostProvider(
          postService: getIt<PostService>(),
          apiService: getIt<ApiService>(),
        ));

    getIt.registerLazySingleton<NotificationProvider>(() =>
        NotificationProvider(
            notificationService: getIt<NotificationService>()));

    getIt.registerLazySingleton<HomeFeedProvider>(
        () => HomeFeedProvider(getIt<HomeFeedService>(), getIt<AuthService>()));

    getIt.registerLazySingleton<UserProvider>(
        () => UserProvider(getIt<UserApiService>()));

    getIt.registerLazySingleton<ReactionProvider>(() => ReactionProvider(
          apiService: getIt<ApiService>(),
          authService: getIt<AuthService>(),
        ));

    getIt.registerLazySingleton<GoogleAuthProvider>(() =>
        GoogleAuthProvider(googleAuthService: getIt<GoogleAuthService>()));
  }

  /// Replace a registered service with a new implementation
  static void replaceService<T extends Object>(T implementation) {
    if (getIt.isRegistered<T>()) {
      getIt.unregister<T>();
    }
    getIt.registerSingleton<T>(implementation);
  }

  /// Check if a service is registered
  static bool isRegistered<T extends Object>() => getIt.isRegistered<T>();

  /// Get a registered service
  static T get<T extends Object>() => getIt<T>();

  /// Reset all registered services
  static Future<void> reset() async {
    await getIt.reset();
    _initialized = false;
    _emergencyInitialized = false;
  }

  /// Update base URL of API service
  static void updateApiBaseUrl(String newBaseUrl) {
    if (isRegistered<ApiService>()) {
      get<ApiService>().updateBaseUrl(newBaseUrl);
    }
  }

  /// Set up dependencies for testing
  static Future<void> setupTestDependencies({
    required String baseUrl,
    ApiService? mockApiService,
    AuthService? mockAuthService,
    StorageService? mockStorageService,
  }) async {
    await reset();
    _registerTestServices(
        baseUrl, mockApiService, mockStorageService, mockAuthService);
    _registerProviders();
    _initialized = true;
  }

  static Future<void> _registerTestServices(
    String baseUrl,
    ApiService? mockApiService,
    StorageService? mockStorageService,
    AuthService? mockAuthService,
  ) async {
    _registerTestApiService(baseUrl, mockApiService);
    await _registerTestStorageService(mockStorageService);
    _registerTestAuthService(mockAuthService, mockStorageService);
  }

  static void _registerTestApiService(
      String baseUrl, ApiService? mockApiService) {
    getIt.registerSingleton<ApiService>(
        mockApiService ?? ApiService(baseUrl: baseUrl));
  }

  static Future<void> _registerTestStorageService(
      StorageService? mockStorageService) async {
    if (mockStorageService != null) {
      getIt.registerSingleton<StorageService>(mockStorageService);
    } else {
      getIt.registerSingletonAsync<StorageService>(StorageService.init);
      await getIt.isReady<StorageService>();
    }
  }

  static void _registerTestAuthService(
      AuthService? mockAuthService, StorageService? mockStorageService) {
    if (mockAuthService != null) {
      getIt.registerSingleton<AuthService>(mockAuthService);
    } else if (mockStorageService != null) {
      getIt.registerSingleton<AuthService>(
          AuthService(getIt<ApiService>(), mockStorageService));
    } else {
      getIt.registerSingleton<AuthService>(
          AuthService(getIt<ApiService>(), getIt<StorageService>()));
    }
  }
}

// Global accessors for critical services to support token refresh
// This avoids circular dependencies while enabling cross-service communication
class GlobalServiceAccess {
  static GoogleAuthService? _googleAuthService;

  static void registerGoogleAuthService(GoogleAuthService service) {
    _googleAuthService = service;
  }

  static GoogleAuthService? getGoogleAuthService() {
    return _googleAuthService;
  }
}
