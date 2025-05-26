import 'package:flutter/material.dart';

/// Application color palette
class AppColors {
  const AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF0A66C2);
  static const Color primaryLight = Color(0xFF378FE9);
  static const Color primaryDark = Color(0xFF004182);

  // Accent colors
  static const Color accent = Color(0xFF057642);
  static const Color accentLight = Color(0xFF0A8750);
  static const Color accentDark = Color(0xFF046236);

  // Background colors
  static const Color background = Color(0xFFF3F2EF);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFEEF3F8);

  // Text colors
  static const Color textPrimary = Color(0xFF191919);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFF86888A);

  // Status colors
  static const Color success = Color(0xFF057642);
  static const Color warning = Color(0xFFF5C241);
  static const Color error = Color(0xFFB74700);
  static const Color info = primary;

  // Social interaction colors
  static const Color like = Color(0xFF0A66C2);
  static const Color comment = primary;
  static const Color share = accent;
}
