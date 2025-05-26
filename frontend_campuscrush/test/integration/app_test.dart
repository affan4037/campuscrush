import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_crush/main.dart';
import 'package:campus_crush/services/api_service.dart';
import 'package:campus_crush/services/auth_service.dart';
import 'package:campus_crush/services/storage_service.dart';
import 'package:campus_crush/modules/google_auth/services/google_auth_service.dart';

void main() {
  late ApiService apiService;
  late StorageService storageService;
  late AuthService authService;
  late GoogleAuthService googleAuthService;

  setUpAll(() async {
    apiService = ApiService(baseUrl: 'http://test.example.com');
    storageService = await StorageService.init();
    authService = AuthService(apiService, storageService);
    googleAuthService = GoogleAuthService(apiService, storageService);
  });

  group('End-to-End Tests', () {
    testWidgets('Complete Login Flow', (WidgetTester tester) async {
      // Start the app
      await tester.pumpWidget(MyApp(
        storageService: storageService,
        apiService: apiService,
        authService: authService,
        googleAuthService: googleAuthService,
      ));

      // Verify we're on the login screen
      expect(find.text('Login'), findsOneWidget);

      // Enter credentials
      await tester.enterText(
          find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'password123');

      // Tap login button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify we're on the home screen after successful login
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Navigation Flow', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(
        storageService: storageService,
        apiService: apiService,
        authService: authService,
        googleAuthService: googleAuthService,
      ));

      // Login first
      await tester.enterText(
          find.byKey(const Key('email_field')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('password_field')), 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Navigate to profile
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      // Navigate to settings
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      // Go back to home
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
