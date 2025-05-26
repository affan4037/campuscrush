import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../core/routes/app_router.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: LoadingOverlay(
        isLoading: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppConstants.largePadding),
              const Icon(
                Icons.info_outline,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              Text(
                'Password Management',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              const Text(
                'Your account uses Google Sign-In for authentication. To change your password, please visit your Google account settings.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.largePadding),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.smallPadding,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultBorderRadius,
                    ),
                  ),
                ),
                child: const Text('Go Back'),
              ),
              const SizedBox(height: AppConstants.defaultPadding),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRouter.home),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
