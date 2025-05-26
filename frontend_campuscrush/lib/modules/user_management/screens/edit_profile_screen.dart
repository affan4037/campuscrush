import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/error_display.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _universityController = TextEditingController();
  final _departmentController = TextEditingController();
  final _graduationYearController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeFormValues();
  }

  void _initializeFormValues() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userData = authService.userData;

    if (userData != null) {
      _fullNameController.text = userData['full_name'] as String? ?? '';
      _usernameController.text = userData['username'] as String? ?? '';
      _bioController.text = userData['bio'] as String? ?? '';
      _universityController.text = userData['university'] as String? ?? '';
      _departmentController.text = userData['department'] as String? ?? '';
      _graduationYearController.text =
          userData['graduation_year'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _graduationYearController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoadingState(true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      _showSnackBar('Updating profile...', duration: 1);

      final success = await authService.updateProfile(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        university: _universityController.text.trim(),
        department: _departmentController.text.trim(),
        graduationYear: _graduationYearController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Profile updated successfully',
            backgroundColor: Colors.green, duration: 2);
        Navigator.pop(context, true);
      } else {
        _error = authService.error ?? 'Failed to update profile';
        _showSnackBar('Error: $_error',
            backgroundColor: Colors.red, duration: 3);
      }
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();
      _showSnackBar('Error: $_error', backgroundColor: Colors.red, duration: 3);
    } finally {
      if (mounted) {
        _setLoadingState(false);
      }
    }
  }

  void _setLoadingState(bool loading) {
    setState(() {
      _isLoading = loading;
      if (loading) _error = null;
    });
  }

  void _showSnackBar(String message,
      {Color? backgroundColor, int duration = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool multiline = false,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        alignLabelWithHint: multiline,
      ),
      maxLines: multiline ? 3 : 1,
      textCapitalization: capitalization,
      validator: validator,
      keyboardType: keyboardType,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _updateProfile,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                ErrorDisplay.fromErrorMessage(
                  errorMessage: _error!,
                  onRetry: () => setState(() => _error = null),
                ),
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Icon(
                      Icons.edit_note,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Update Your Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fill in the details below to update your profile',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Personal Information',
                      children: [
                        _buildInputField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          icon: Icons.person,
                          validator: Validators.validateFullName,
                          capitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildInputField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Enter your username',
                          icon: Icons.alternate_email,
                          validator: Validators.validateUsername,
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildInputField(
                          controller: _bioController,
                          label: 'Bio',
                          hint: 'Tell us about yourself',
                          icon: Icons.info,
                          multiline: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Education',
                      children: [
                        _buildInputField(
                          controller: _universityController,
                          label: 'University',
                          hint: 'Enter your university name',
                          icon: Icons.school,
                          validator: Validators.validateUniversity,
                          capitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildInputField(
                          controller: _departmentController,
                          label: 'Department',
                          hint: 'Enter your department name',
                          icon: Icons.business,
                          capitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppConstants.defaultPadding),
                        _buildInputField(
                          controller: _graduationYearController,
                          label: 'Graduation Year',
                          hint: 'Enter your graduation year',
                          icon: Icons.calendar_today,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Save Changes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
