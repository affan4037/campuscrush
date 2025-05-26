import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../modules/google_auth/widgets/google_sign_in_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String? _error;
  final bool _isLoading = false;

  void _setError(String? message) {
    setState(() {
      _error = message;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildErrorMessage(),
                _buildLogoAndAppName(),
                _buildGoogleSignInSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_error == null) return const SizedBox.shrink();

    return ErrorDisplay.fromErrorMessage(
      errorMessage: _error!,
      onRetry: () => _setError(null),
    );
  }

  Widget _buildLogoAndAppName() {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/icons/logo_campus_crush.png',
            height: 80,
            width: 80,
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Email/password registration is no longer supported.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        const Text(
          'For security and convenience, we now only support registration and login through Google.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.defaultPadding * 2),
        GoogleSignInButton(
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign in successful!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacementNamed(context, AppRouter.home);
          },
          onError: () {
            // Error handling is already built into the button
          },
          text: 'Sign up with Google',
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Login'),
            ),
          ],
        ),
      ],
    );
  }
}
