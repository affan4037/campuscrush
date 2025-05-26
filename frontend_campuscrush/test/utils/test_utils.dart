import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:campus_crush/services/api_service.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/storage_service.dart';
import 'package:campus_crush/modules/google_auth/services/google_auth_service.dart';
import 'package:campus_crush/modules/auth/providers/auth_provider.dart';

class TestNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {}

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {}

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {}

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {}

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {}

  @override
  void didStopUserGesture() {}
}

/// Creates a testable widget wrapped with necessary providers
Widget createWidgetForTesting({required Widget child}) {
  return MaterialApp(
    home: FutureBuilder<StorageService>(
      future: StorageService.init(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final storageService = snapshot.data!;
        final apiService = ApiService(baseUrl: 'http://test.example.com');
        final authService = AuthService(apiService, storageService);
        final googleAuthService = GoogleAuthService(apiService, storageService);

        return MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            Provider<StorageService>.value(value: storageService),
            Provider<AuthService>.value(value: authService),
            Provider<GoogleAuthService>.value(value: googleAuthService),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(
                apiService: apiService,
                storageService: storageService,
              ),
            ),
          ],
          child: child,
        );
      },
    ),
  );
}

Future<void> pumpWidgetWithContext(
  WidgetTester tester,
  Widget widget,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: widget,
    ),
  );
  await tester.pumpAndSettle();
}

extension WidgetTesterExtension on WidgetTester {
  Future<void> scrollUntilVisible(
    Finder finder,
    double offset,
  ) async {
    while (finder.evaluate().isEmpty) {
      await dragUntilVisible(
        finder,
        find.byType(Scrollable).first,
        const Offset(0, -50),
      );
      await pumpAndSettle();
    }
  }
}

class TestHelper {
  static Future<void> waitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    throw Exception('Widget not found within timeout');
  }
}
