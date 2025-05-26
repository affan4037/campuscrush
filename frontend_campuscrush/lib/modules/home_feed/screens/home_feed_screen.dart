import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_router.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../providers/home_feed_provider.dart';
import '../services/home_feed_service.dart';
import '../widgets/feed_list.dart';
import '../../shared/widgets/settings_drawer.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0, end: 80).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    _validateApiBaseUrl(apiService);

    // Check keyboard visibility
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    if (isKeyboardVisible != _isKeyboardVisible) {
      _isKeyboardVisible = isKeyboardVisible;
      if (isKeyboardVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }

    return ChangeNotifierProvider(
      create: (_) => HomeFeedProvider(
        HomeFeedService(apiService, authService),
        authService,
      ),
      child: _buildScaffold(context),
    );
  }

  void _validateApiBaseUrl(ApiService apiService) {
    if (apiService.baseUrl != AppConstants.baseUrl) {
      apiService.updateBaseUrl(AppConstants.baseUrl);
    }
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      drawer: const SettingsDrawer(),
      appBar: AppBar(
        title: const Text('Campus Crush'),
      ),
      body: const FeedList(),
      floatingActionButton: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Padding(
            padding: EdgeInsets.only(bottom: 16.0 + _animation.value),
            child: FloatingActionButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.createPost),
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}
