import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../modules/home_feed/screens/home_feed_screen.dart';
import '../modules/user_management/screens/profile_screen.dart';
import '../modules/user_management/screens/user_search_screen.dart';
import '../modules/notifications/screens/notifications_screen.dart';
import '../modules/notifications/providers/notification_provider.dart';

/// Main navigation screen that handles bottom navigation between primary app sections
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController(initialPage: 0);
  late final List<Widget> _screens;
  static const _refreshInterval = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();

    _screens = [
      const HomeFeedScreen(),
      const UserSearchScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNotificationPolling();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startNotificationPolling() {
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;

    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.getNotifications();

      Future.delayed(_refreshInterval, _fetchNotifications);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      Future.delayed(const Duration(seconds: 30), _fetchNotifications);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const ClampingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: _buildNotificationIcon(),
          label: 'Notifications',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final unreadCount = provider.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications),
            if (unreadCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: _buildNotificationBadge(unreadCount),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 16,
        minHeight: 16,
      ),
      child: Text(
        count > 9 ? '9+' : count.toString(),
        style: const TextStyle(
          color: Color.fromARGB(255, 163, 147, 147),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
