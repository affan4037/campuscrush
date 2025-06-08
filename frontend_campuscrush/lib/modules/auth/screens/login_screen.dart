import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../screens/api_test_screen.dart';
import '../../../modules/google_auth/providers/google_auth_provider.dart';
import '../../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _defaultSpacing = 16.0;
  static const double _largeSpacing = 24.0;

  String? _error;
  bool _isLoading = false;

  void _setError(String? message) {
    setState(() => _error = message);
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
      if (loading) _error = null;
    });
  }

  void _showSnackbar(String message,
      {Color? backgroundColor, int duration = 4}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
      ),
    );
  }

  Future<void> _checkConnectivity() async {
    _setLoading(true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (!mounted) return;
      final bool isServerReachable =
          await authService.checkServerConnectivity();
      if (!isServerReachable) {
        throw Exception(
            'Cannot connect to the server. Check your internet connection.');
      }

      await _navigateToGoogleSignIn();
    } catch (e) {
      debugPrint('Connection check exception: $e');
      if (mounted) {
        _handleException(e);
      }
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  void _handleException(dynamic e) {
    final message = e.toString();
    if (message.contains('SocketException') ||
        message.contains('Connection') ||
        message.contains('network') ||
        message.contains('connect to the server')) {
      _setError(
          'Network error: Cannot connect to the server. Check your connection.');
    } else {
      _setError(message);
    }
  }

  Future<void> _navigateToGoogleSignIn(
      {bool forceAccountPicker = false}) async {
    // Only set preferences when explicitly requested to force account picker
    if (forceAccountPicker) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_google_signin', true);
      await prefs.setBool('force_account_picker', true);
      await _clearGoogleSignInCache();

      // For force account picker, we still use the redirect flow
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.googleSignIn,
          arguments: {'forceAccountPicker': true});
      return;
    }

    // For normal sign in, directly authenticate without redirecting
    _setLoading(true);

    try {
      final googleAuthProvider =
          Provider.of<GoogleAuthProvider>(context, listen: false);
      final success = await googleAuthProvider.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        // Ensure token is set on the global ApiService and AuthService before navigating
        final token = googleAuthProvider.token;
        final apiService = Provider.of<ApiService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        if (token != null && token.isNotEmpty) {
          apiService.setAuthToken(token);
          authService.setToken(token);
        }
        // Fetch user profile before navigating
        final profileSuccess = await authService.refreshUserProfile();
        if (profileSuccess) {
          Navigator.pushReplacementNamed(context, AppRouter.home);
        } else {
          _setLoading(false);
          _showSnackbar(
            'Failed to load your profile. Please try logging in again.',
            backgroundColor: Colors.red[300],
            duration: 4,
          );
        }
      } else {
        _setLoading(false);
        _showSnackbar(
            googleAuthProvider.error ??
                'Failed to sign in with Google. Please try again.',
            backgroundColor: Colors.red[300],
            duration: 4);
      }
    } catch (e) {
      if (!mounted) return;
      _setLoading(false);
      _showSnackbar('Error during Google sign-in: ${e.toString()}',
          backgroundColor: Colors.red[300], duration: 4);
    }
  }

  Future<void> _clearGoogleSignInCache() async {
    // Remove any existing auth tokens to ensure we show the account picker
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_auth_user');
    await prefs.remove('google_signin_user');
    debugPrint('Cleared Google sign-in cache to force account picker');
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/icons/logo_campus_crush_without_bg.png',
          height: 36,
          width: 36,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultPadding,
                  vertical: AppConstants.largePadding,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign in',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),
                    _buildErrorMessage(),
                    _buildGoogleSignInSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_error == null) return const SizedBox.shrink();

    return Column(
      children: [
        ErrorDisplay(
          message: _error!,
          onRetry: () => _setError(null),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
      ],
    );
  }

  Widget _buildGoogleSignInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _largeSpacing),
        const Text(
          'Sign in with your Google account',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: _largeSpacing),
        _buildGoogleSignInButton(),
        const SizedBox(height: _defaultSpacing),
        _buildAddAccountButton(),
        const SizedBox(height: _largeSpacing),
        _buildApiTestButton(),
      ],
    );
  }

  Widget _buildApiTestButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.network_check, size: 18),
      label: const Text('Test API Connection'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.secondary,
        side: BorderSide(color: Theme.of(context).colorScheme.secondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ApiTestScreen()),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: _checkConnectivity,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 24,
            width: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
            ),
            child: const Center(
              child: FaIcon(
                FontAwesomeIcons.google,
                color: Colors.red,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Sign in with Google',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black87
                  : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAccountButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextButton.icon(
        onPressed: () => _navigateToGoogleSignIn(forceAccountPicker: true),
        icon: const Icon(Icons.person_add, size: 18),
        label: const Text('Use a different account'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
