import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../modules/google_auth/providers/google_auth_provider.dart';
import '../../../widgets/loading_overlay.dart';

class DeleteUserScreen extends StatefulWidget {
  final String email;

  const DeleteUserScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<DeleteUserScreen> createState() => _DeleteUserScreenState();
}

class _DeleteUserScreenState extends State<DeleteUserScreen> {
  bool _isDeleting = false;
  String? _error;
  bool _isConfirmed = false;

  Future<void> _deleteUser() async {
    if (!_isConfirmed) {
      _setError('Please confirm the deletion by checking the box');
      return;
    }

    _setLoadingState(true);

    try {
      final googleAuthProvider =
          Provider.of<GoogleAuthProvider>(context, listen: false);

      // First sign out from the system
      final success = await googleAuthProvider.signOut();

      if (!mounted) return;

      if (success) {
        _navigateToLoginAndShowSuccess();
      } else {
        _setError(googleAuthProvider.error ?? 'Failed to delete user');
      }
    } catch (e) {
      if (mounted) {
        _setError(e.toString());
      }
    }
  }

  void _setError(String errorMessage) {
    setState(() {
      _error = errorMessage;
      _isDeleting = false;
    });
  }

  void _setLoadingState(bool isLoading) {
    setState(() {
      _isDeleting = isLoading;
      if (isLoading) _error = null;
    });
  }

  void _navigateToLoginAndShowSuccess() {
    Navigator.pushNamedAndRemoveUntil(
        context, AppRouter.login, (route) => false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'You have been signed out. To delete your Google account, please visit your Google account settings.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isDeleting,
        message: 'Signing out...',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 80,
          color: Colors.red,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        Text(
          'Account Management',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        Text(
          'Your account (${widget.email}) uses Google Sign-In. We can sign you out from this app, but to fully delete your Google account, you\'ll need to visit your Google account settings.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.largePadding),
        _buildConfirmationCheckbox(),
        const SizedBox(height: AppConstants.defaultPadding),
        if (_error != null) _buildErrorMessage(),
        const SizedBox(height: AppConstants.defaultPadding),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildConfirmationCheckbox() {
    return CheckboxListTile(
      title: const Text('I understand that this will sign me out of the app'),
      value: _isConfirmed,
      onChanged: (value) {
        setState(() {
          _isConfirmed = value ?? false;
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 11),
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Text(
        _error!,
        style: const TextStyle(color: Colors.red),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isDeleting ? null : _deleteUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Sign Out'),
        ),
        const SizedBox(height: AppConstants.smallPadding),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
