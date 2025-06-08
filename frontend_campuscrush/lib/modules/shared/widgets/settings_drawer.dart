import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/theme/styling.dart';
import '../../../services/auth_service.dart';
import '../../../modules/user_management/screens/change_password_screen.dart';

class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({Key? key}) : super(key: key);

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  bool _isAccountExpanded = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user == null) {
      return const Center(
        child: Text('No user data available'),
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context, user),
          _buildSettingsItem(
            context,
            Icons.notifications,
            'Notification Settings',
            'Manage your notifications',
            () => Navigator.pushNamed(context, AppRouter.notifications),
          ),
          _buildSettingsItem(
            context,
            Icons.privacy_tip,
            'Privacy & Security',
            'Manage your privacy settings',
            () => _showComingSoonMessage(context),
          ),
          Divider(
            color: Colors.grey.shade200,
            thickness: 1,
            height: 1,
          ),
          _buildSettingsItem(
            context,
            Icons.logout,
            'Logout',
            'Sign out of your account',
            () => _logout(context),
          ),
          Divider(
            color: Colors.grey.shade200,
            thickness: 1,
            height: 1,
          ),
          _buildAccountSettingsItem(context),
          if (_isAccountExpanded) _buildAccountSettingsOptions(context),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, dynamic user) {
    final String fullName = user.fullName;
    final String email = user.email;
    final bool hasValidProfilePicture = user.hasValidProfilePicture;

    return DrawerHeader(
      decoration: const BoxDecoration(
        color: AppStyling.primaryBlue,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppConstants.appName,
            style: AppStyling.headingStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: hasValidProfilePicture
                    ? NetworkImage(user.safeProfilePictureUrl!)
                    : null,
                backgroundColor: Colors.white,
                child: !hasValidProfilePicture
                    ? Text(
                        _getInitial(fullName),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A66C2),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: AppStyling.subheadingStyle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: AppStyling.captionStyle.copyWith(
                        color: Colors.white.withValues(alpha: 191),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettingsItem(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.account_circle,
        color: Colors.grey,
        size: 20,
      ),
      title: Text(
        'Account Settings',
        style: AppStyling.bodyStyle.copyWith(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: Icon(
        _isAccountExpanded ? Icons.expand_less : Icons.expand_more,
        color: Colors.grey,
        size: 20,
      ),
      onTap: () {
        setState(() {
          _isAccountExpanded = !_isAccountExpanded;
        });
      },
      dense: true,
    );
  }

  Widget _buildAccountSettingsOptions(BuildContext context) {
    return Column(
      children: [
        _buildIndentedSettingsItem(
          context,
          Icons.edit,
          'Edit Profile',
          'Update your personal information',
          () => Navigator.pushNamed(context, AppRouter.editProfile),
          textColor: Colors.grey,
          fontSize: 14,
        ),
        _buildIndentedSettingsItem(
          context,
          Icons.password,
          'Change Password',
          'Update your account security',
          () {
            final authService =
                Provider.of<AuthService>(context, listen: false);
            final email = authService.currentUser?.email ?? '';

            if (email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to find user email')),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            );
          },
          textColor: Colors.grey,
          fontSize: 14,
        ),
        _buildIndentedSettingsItem(
          context,
          Icons.delete_forever,
          'Delete Account',
          'Permanently delete your account',
          () => _showDeleteAccountDialog(context),
          textColor: Colors.red,
          iconColor: Colors.red,
          fontSize: 14,
        ),
      ],
    );
  }

  Widget _buildIndentedSettingsItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? iconColor,
    Color? textColor,
    double? fontSize,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? AppStyling.primaryBlue,
          size: 20,
        ),
        title: Text(
          title,
          style: AppStyling.bodyStyle.copyWith(
            color: textColor ?? AppStyling.textPrimary,
            fontWeight: textColor != null ? FontWeight.bold : FontWeight.w500,
            fontSize: fontSize ?? 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppStyling.captionStyle.copyWith(
            fontSize: 12,
          ),
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppStyling.primaryBlue,
        size: 22,
      ),
      title: Text(
        title,
        style: AppStyling.bodyStyle.copyWith(
          color: textColor ?? AppStyling.textPrimary,
          fontWeight: textColor != null ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppStyling.captionStyle,
      ),
      onTap: onTap,
    );
  }

  String _getInitial(String name) {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  Future<void> _logout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRouter.login, (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during logout: $e')),
        );
      }
    }
  }

  void _showComingSoonMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature is coming soon!')),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final email = user?.email ?? '';

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to find user email')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: AppStyling.subheadingStyle),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: AppStyling.bodyStyle,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: AppStyling.linkStyle),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                AppRouter.deleteUser,
                arguments: email,
              );
            },
            child: Text(
              'DELETE',
              style: AppStyling.linkStyle.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
