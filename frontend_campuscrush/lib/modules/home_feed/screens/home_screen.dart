import 'package:flutter/material.dart';
import 'home_feed_screen.dart';

/// Redirects to HomeFeedScreen
///
/// This class exists for backward compatibility.
/// The main app now uses screens/home_screen.dart which
/// contains a bottom navigation bar and includes HomeFeedScreen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Just render the HomeFeedScreen directly
    return const HomeFeedScreen();
  }
}
