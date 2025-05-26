import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routes/app_router.dart';
import '../../../services/auth_service.dart';
import '../../../modules/google_auth/services/google_auth_service.dart';
import '../../../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  static const Duration _splashDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _navigateAfterDelay();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(_splashDuration);
    if (!mounted) return;

    final route = await _determineTargetRoute();
    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  Future<String> _determineTargetRoute() async {
    // Check existing authentication state
    final authService = Provider.of<AuthService>(context, listen: false);
    final googleAuthService =
        Provider.of<GoogleAuthService>(context, listen: false);

    if (authService.isAuthenticated || googleAuthService.isAuthenticated) {
      // User is already authenticated, reset the logged_out flag since we're
      // automatically signing them in
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_logged_out', false);
      return AppRouter.home;
    }

    // Check for saved token
    final storageService = Provider.of<StorageService>(context, listen: false);
    final token = await storageService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      // User has a token, reset the logged_out flag since we're
      // automatically signing them in
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_logged_out', false);
      return AppRouter.home;
    }

    // Always use Google Sign-in
    return AppRouter.googleSignIn;
  }

  @override
  Widget build(BuildContext context) {
    // LinkedIn dark background color
    const darkBackground = Color(0xFF1D2226);

    return Scaffold(
      backgroundColor: darkBackground,
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildLogo(),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: const Color(0xFF0A66C2), // LinkedIn blue color for background
          child: Padding(
            padding:
                const EdgeInsets.all(2.0), // Small padding for border effect
            child: ClipOval(
              child: Image.asset(
                'assets/icons/logo_campus_crush.png',
                width: 176,
                height: 176,
                fit: BoxFit
                    .cover, // This helps ensure the image fills the circle
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 176,
                    height: 176,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A66C2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      size: 100,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
