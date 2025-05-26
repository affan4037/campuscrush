import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/providers/providers.dart';
import 'core/di/dependency_injection.dart';
import 'core/config/firebase_config.dart';
import 'core/utils/cache_manager.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'modules/google_auth/services/google_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeApp();

  final services = _initializeServices();

  // Register services for global access
  GlobalServiceAccess.registerGoogleAuthService(services.googleAuthService);

  await _validateServerConnection(services.authService);

  runApp(MyApp(
    storageService: services.storageService,
    apiService: services.apiService,
    authService: services.authService,
    googleAuthService: services.googleAuthService,
  ));
}

Future<void> _initializeApp() async {
  try {
    await FirebaseConfig.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await CacheManager.clearImageCache();

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(AppConstants.verifiedBaseUrlKey);
  await AppConstants.initializeUrlPatterns();

  await DependencyInjection.init(baseUrl: AppConstants.baseUrl);
}

class _AppServices {
  final ApiService apiService;
  final AuthService authService;
  final StorageService storageService;
  final GoogleAuthService googleAuthService;

  _AppServices({
    required this.apiService,
    required this.authService,
    required this.storageService,
    required this.googleAuthService,
  });
}

_AppServices _initializeServices() {
  return _AppServices(
    apiService: DependencyInjection.get<ApiService>(),
    authService: DependencyInjection.get<AuthService>(),
    storageService: DependencyInjection.get<StorageService>(),
    googleAuthService: DependencyInjection.get<GoogleAuthService>(),
  );
}

Future<void> _validateServerConnection(AuthService authService) async {
  try {
    // For release builds, prioritize Railway URL
    if (kReleaseMode) {
      const railwayUrl = AppConstants.baseUrl;
      debugPrint('🚀 Release build - prioritizing Railway URL: $railwayUrl');
      DependencyInjection.updateApiBaseUrl(railwayUrl);
    }

    // Check if the server is reachable
    final bool isServerReachable = await authService.checkServerConnectivity();
    if (!isServerReachable) {
      debugPrint('⚠️ Primary server not reachable, trying alternatives...');
      await _updateServerUrl();
    } else {
      debugPrint('✅ Server connection validated successfully');
    }
  } catch (e) {
    debugPrint('❌ Server validation error: $e');
  }
}

Future<bool> _updateServerUrl() async {
  try {
    final validUrl = await AppConstants.getValidServerUrl();
    final currentUrl = DependencyInjection.get<ApiService>().baseUrl;

    if (validUrl != currentUrl) {
      DependencyInjection.updateApiBaseUrl(validUrl);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.verifiedBaseUrlKey, validUrl);
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Error updating server URL: $e');
    return false;
  }
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  final ApiService apiService;
  final AuthService authService;
  final GoogleAuthService googleAuthService;

  const MyApp({
    super.key,
    required this.storageService,
    required this.apiService,
    required this.authService,
    required this.googleAuthService,
  });

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      authService: authService,
      apiService: apiService,
      storageService: storageService,
      googleAuthService: googleAuthService,
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        initialRoute: AppRouter.splash,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
