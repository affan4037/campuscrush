import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/google_auth_provider.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onError;
  final double height;
  final double borderRadius;
  final Color backgroundColor;
  final Color textColor;
  final bool showIcon;
  final String text;

  const GoogleSignInButton({
    super.key,
    this.onSuccess,
    this.onError,
    this.height = 50.0,
    this.borderRadius = 4.0,
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black87,
    this.showIcon = true,
    this.text = 'Sign in with Google',
  });

  @override
  Widget build(BuildContext context) {
    final googleAuthProvider = Provider.of<GoogleAuthProvider>(context);
    final isLoading = googleAuthProvider.isLoading;

    return SizedBox(
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: const BorderSide(color: Colors.grey, width: 0.5),
          ),
        ),
        onPressed: isLoading ? null : () => _handleGoogleSignIn(context),
        child: _buildButtonContent(isLoading, context),
      ),
    );
  }

  Widget _buildButtonContent(bool isLoading, BuildContext context) {
    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor:
                  AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.8)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Signing in...',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showIcon) ...[
          const FaIcon(
            FontAwesomeIcons.google,
            color: Colors.red,
            size: 18,
          ),
          const SizedBox(width: 12),
        ],
        Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    final googleAuthProvider =
        Provider.of<GoogleAuthProvider>(context, listen: false);

    try {
      if (!context.mounted) return;

      final success = await googleAuthProvider.signInWithGoogle();

      if (!context.mounted) return;

      if (success) {
        onSuccess?.call();
        return;
      }

      final errorMessage = googleAuthProvider.error;

      onError?.call();
      if (context.mounted) {
        _showErrorMessage(context,
            errorMessage ?? 'Unable to complete sign-in. Please try again.');
      }
    } catch (e) {
      onError?.call();
      if (context.mounted) {
        _showErrorMessage(context, _getFriendlyErrorMessage(e.toString()));
      }
    }
  }

  String _getFriendlyErrorMessage(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();

    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('socket')) {
      return 'Network issue. Please check your connection and try again.';
    }

    if (lowerError.contains('cancel') || lowerError.contains('abort')) {
      return 'Sign-in was canceled. Please try again when ready.';
    }

    if (lowerError.contains('credential') || lowerError.contains('auth')) {
      return 'Account verification failed. Please try again.';
    }

    return 'Sign-in failed. Please try again.';
  }

  void _showErrorMessage(BuildContext context, String message) {
    if (onError == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _handleGoogleSignIn(context),
          ),
        ),
      );
    }
  }
}
