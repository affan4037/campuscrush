import 'package:flutter/material.dart';

/// Screen breakpoints for responsive layouts
class ScreenBreakpoints {
  static const double small = 400;
  static const double medium = 768;
  static const double large = 1024;
  static const double extraLarge = 1280;
}

/// Screen size categories
enum ScreenSize { small, medium, large, extraLarge }

/// Responsive utilities for the app
class ResponsiveUtils {
  /// Get screen size category based on width
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < ScreenBreakpoints.small) return ScreenSize.small;
    if (width < ScreenBreakpoints.medium) return ScreenSize.medium;
    if (width < ScreenBreakpoints.large) return ScreenSize.large;
    if (width < ScreenBreakpoints.extraLarge) return ScreenSize.extraLarge;
    return ScreenSize.extraLarge;
  }

  /// Get responsive value based on screen size
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T small,
    required T medium,
    required T large,
    T? extraLarge,
  }) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return small;
      case ScreenSize.medium:
        return medium;
      case ScreenSize.large:
        return large;
      case ScreenSize.extraLarge:
        return extraLarge ?? large;
    }
  }

  /// Get responsive text size based on screen size
  static double getTextSize(
    BuildContext context, {
    required double small,
    required double medium,
    required double large,
    double? extraLarge,
  }) {
    return getResponsiveValue<double>(
      context: context,
      small: small,
      medium: medium,
      large: large,
      extraLarge: extraLarge,
    );
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getPadding(
    BuildContext context, {
    required EdgeInsets small,
    required EdgeInsets medium,
    required EdgeInsets large,
    EdgeInsets? extraLarge,
  }) {
    return getResponsiveValue<EdgeInsets>(
      context: context,
      small: small,
      medium: medium,
      large: large,
      extraLarge: extraLarge,
    );
  }

  /// Get responsive icon size based on screen size
  static double getIconSize(
    BuildContext context, {
    required double small,
    required double medium,
    required double large,
    double? extraLarge,
  }) {
    return getResponsiveValue<double>(
      context: context,
      small: small,
      medium: medium,
      large: large,
      extraLarge: extraLarge,
    );
  }

  /// Check if current screen is mobile size
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ScreenBreakpoints.medium;
  }

  /// Check if current screen is tablet size
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ScreenBreakpoints.medium && width < ScreenBreakpoints.large;
  }

  /// Check if current screen is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ScreenBreakpoints.large;
  }
}

/// Predefined responsive text styles
class ResponsiveTextStyles {
  static TextStyle title(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveUtils.getTextSize(
        context,
        small: 16.0,
        medium: 18.0,
        large: 20.0,
      ),
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    );
  }

  static TextStyle body(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveUtils.getTextSize(
        context,
        small: 14.0,
        medium: 14.0,
        large: 16.0,
      ),
      height: 1.4,
      letterSpacing: 0,
    );
  }

  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: ResponsiveUtils.getTextSize(
        context,
        small: 12.0,
        medium: 12.0,
        large: 13.0,
      ),
      color: Colors.grey[600],
      letterSpacing: 0,
    );
  }
}

/// Predefined responsive spacing measurements
class ResponsiveSpacing {
  static EdgeInsets card(BuildContext context) {
    return const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0);
  }

  static EdgeInsets content(BuildContext context) {
    return const EdgeInsets.all(16.0);
  }

  static EdgeInsets screenPadding(BuildContext context) {
    return ResponsiveUtils.getPadding(
      context,
      small: const EdgeInsets.symmetric(horizontal: 16.0),
      medium: const EdgeInsets.symmetric(horizontal: 24.0),
      large: const EdgeInsets.symmetric(horizontal: 0),
      extraLarge: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  static double horizontal(BuildContext context) {
    return ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      small: 8.0,
      medium: 12.0,
      large: 16.0,
      extraLarge: 20.0,
    );
  }

  static double vertical(BuildContext context) {
    return ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      small: 8.0,
      medium: 12.0,
      large: 16.0,
      extraLarge: 20.0,
    );
  }
}
