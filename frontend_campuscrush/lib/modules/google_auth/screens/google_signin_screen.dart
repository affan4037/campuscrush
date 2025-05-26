import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide GoogleAuthProvider;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../widgets/google_sign_in_button.dart';
import '../providers/google_auth_provider.dart';
import '../../../widgets/loading_overlay.dart';

/// Screen for handling Google Sign-In functionality
class GoogleSignInScreen extends StatefulWidget {
  final String? prefilledEmail;

  const GoogleSignInScreen({super.key, this.prefilledEmail});

  @override
  State<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends State<GoogleSignInScreen> {
  // UI constants
  static const _autoSignInDelay = Duration(milliseconds: 500);
  static const _snackBarDuration = Duration(seconds: 3);
  static const _retryDelay = Duration(seconds: 1);
  static const _logoSize = 80.0;
  static const _verticalGapLarge = 48.0;
  static const _verticalGapMedium = 32.0;
  static const _verticalGapSmall = 16.0;
  static const _errorPadding = 8.0;
  static const _errorBorderRadius = 8.0;

  // Default error messages
  static const _defaultSignInError = 'Sign-in failed. Please try again.';
  static const _signInErrorPrefix = 'Error: ';
  static const _firebaseErrorPrefix = 'Service unavailable: ';

  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  int _retryCount = 0;
  static const _maxRetries = 1; // Allow one automatic retry

  @override
  void initState() {
    super.initState();
    _checkFirebaseStatus();

    if (widget.prefilledEmail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          _showPrefilledEmailInfo();
          _autoInitiateSignIn();
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _showPrefilledEmailInfo() {
    if (!mounted) return;

    final email = widget.prefilledEmail;
    if (email == null || email.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Signing in with Google: $email'),
        duration: _snackBarDuration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkFirebaseStatus() async {
    try {
      FirebaseAuth.instance;
      GoogleSignIn();
      debugPrint('Firebase integration check completed');
    } catch (e) {
      debugPrint('Firebase integration check failed: $e');
      _setError('$_firebaseErrorPrefix$e');
    }
  }

  void _setError(String? error) {
    if (mounted && !_disposed) {
      setState(() => _error = error);
    }
  }

  void _setLoading(bool isLoading) {
    if (mounted && !_disposed) {
      setState(() => _isLoading = isLoading);
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.home);
    }
  }

  void _handleSignInError() {
    if (!mounted || _disposed) return;

    final provider = Provider.of<GoogleAuthProvider>(context, listen: false);
    final errorMessage = provider.error ?? _defaultSignInError;

    // Check if this error might be resolved with a retry
    final isRetryableError = _isRetryableError(errorMessage);

    if (isRetryableError && _retryCount < _maxRetries) {
      _retryCount++;

      // Show brief message about retrying
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retrying sign-in...'),
          duration: _retryDelay,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Attempt retry after short delay
      Future.delayed(_retryDelay, () {
        if (mounted && !_disposed) {
          _attemptSignIn();
        }
      });
      return;
    }

    // If we've reached max retries or it's not a retryable error, show the error
    _setError(errorMessage);
  }

  bool _isRetryableError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('temporary') ||
        lowerError.contains('pigeon') ||
        lowerError.contains('list<object?>') ||
        lowerError.contains('timeout') ||
        lowerError.contains('network');
  }

  Future<void> _autoInitiateSignIn() async {
    await Future.delayed(_autoSignInDelay);
    if (!mounted || _disposed) return;

    _attemptSignIn();
  }

  Future<void> _attemptSignIn() async {
    if (!mounted || _disposed) return;

    final googleAuthProvider =
        Provider.of<GoogleAuthProvider>(context, listen: false);

    try {
      _setLoading(true);
      final success = await googleAuthProvider.signInWithGoogle();

      if (!mounted || _disposed) return;

      if (success) {
        _navigateToHome();
      } else {
        _setLoading(false);
        _handleSignInError();
      }
    } catch (e) {
      if (mounted && !_disposed) {
        _setLoading(false);
        _setError('$_signInErrorPrefix$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: _verticalGapMedium),
                    _buildWelcomeText(),
                    if (_error != null) _buildErrorMessage(),
                    const SizedBox(height: _verticalGapLarge),
                    _buildGoogleSignInButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icons/logo_campus_crush.png',
      width: _logoSize,
      height: _logoSize,
    );
  }

  Widget _buildWelcomeText() {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        children: [
          Text(
            'Welcome to ${AppConstants.appName}',
            style:
                textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _verticalGapSmall),
          Text(
            'Sign in with your Google account to continue',
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_error == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: _verticalGapSmall),
      padding: const EdgeInsets.all(_errorPadding),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(_errorBorderRadius),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: _errorPadding),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _setError(null);
                _retryCount = 0;
                _attemptSignIn();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Try Again'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return GoogleSignInButton(
      onSuccess: _navigateToHome,
      onError: _handleSignInError,
    );
  }
}
