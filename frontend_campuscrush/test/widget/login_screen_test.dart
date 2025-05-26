import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_crush/modules/auth/screens/login_screen.dart';
import '../utils/test_utils.dart';

void main() {
  testWidgets('Login Screen Widget Tests', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(createWidgetForTesting(child: const LoginScreen()));

    // Verify initial state
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);

    // Test email input
    await tester.enterText(
        find.byKey(const Key('email_field')), 'test@example.com');
    expect(find.text('test@example.com'), findsOneWidget);

    // Test password input
    await tester.enterText(
        find.byKey(const Key('password_field')), 'password123');
    expect(find.text('password123'), findsOneWidget);

    // Test login button tap
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Verify loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Login Screen Validation Tests', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetForTesting(child: const LoginScreen()));

    // Test empty email validation
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email'), findsOneWidget);

    // Test invalid email format
    await tester.enterText(
        find.byKey(const Key('email_field')), 'invalid-email');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email'), findsOneWidget);

    // Test empty password validation
    await tester.enterText(
        find.byKey(const Key('email_field')), 'test@example.com');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your password'), findsOneWidget);
  });
}
