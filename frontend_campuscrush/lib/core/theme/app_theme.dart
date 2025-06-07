import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Manages application theme configuration
class AppTheme {
  const AppTheme._();

  // UI Constants
  static const double _borderRadius = 4.0;
  static const double _smallBorderRadius = 2.0;
  static const EdgeInsets _buttonPadding =
      EdgeInsets.symmetric(vertical: 12, horizontal: 24);
  static const EdgeInsets _textButtonPadding =
      EdgeInsets.symmetric(vertical: 8, horizontal: 16);
  static const EdgeInsets _inputPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  // Typography constants
  static const FontWeight _boldWeight = FontWeight.w700;
  static const FontWeight _semiBoldWeight = FontWeight.w600;
  static const FontWeight _mediumWeight = FontWeight.w500;
  static const FontWeight _regularWeight = FontWeight.w400;
  static const TextStyle _buttonTextStyle =
      TextStyle(fontSize: 16, fontWeight: _mediumWeight, letterSpacing: 0);

  // Direct color references
  static const Color primaryColor = AppColors.primary;
  static const Color accentColor = AppColors.accent;
  static const Color errorColor = AppColors.error;
  static const Color textColor = AppColors.textPrimary;
  static const Color secondaryTextColor = AppColors.textSecondary;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;

  /// Light theme configuration
  static final ThemeData lightTheme = _createLightTheme();

  /// Dark theme configuration
  static final ThemeData darkTheme = _createDarkTheme();

  /// Creates the light theme
  static ThemeData _createLightTheme() {
    final borderRadius = BorderRadius.circular(_borderRadius);
    final smallBorderRadius = BorderRadius.circular(_smallBorderRadius);

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        shadowColor: Colors.black12,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      elevatedButtonTheme: _createElevatedButtonTheme(borderRadius),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          textStyle: _buttonTextStyle,
          padding: _buttonPadding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: _buttonTextStyle,
          padding: _textButtonPadding,
        ),
      ),
      textTheme: _createTextTheme(textColor, secondaryTextColor),
      inputDecorationTheme:
          _createInputDecorationTheme(borderRadius, Colors.white),
      cardTheme: _createCardTheme(borderRadius, Colors.white),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: _createSnackBarTheme(borderRadius, Colors.grey.shade800),
      checkboxTheme: _createCheckboxTheme(smallBorderRadius),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
    );
  }

  /// Creates the dark theme
  static ThemeData _createDarkTheme() {
    const darkBackground = Color(0xFF1D2226);
    const darkSurface = Color(0xFF283339);
    final borderRadius = BorderRadius.circular(_borderRadius);
    final smallBorderRadius = BorderRadius.circular(_smallBorderRadius);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: darkSurface,
        error: errorColor,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: primaryColor,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      elevatedButtonTheme: _createElevatedButtonTheme(borderRadius),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
          textStyle: _buttonTextStyle,
          padding: _buttonPadding,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: _buttonTextStyle,
          padding: _textButtonPadding,
        ),
      ),
      textTheme: _createTextTheme(Colors.white, Colors.white70),
      cardTheme:
          _createCardTheme(borderRadius, darkSurface, shadowOpacity: 0.1),
      inputDecorationTheme:
          _createInputDecorationTheme(borderRadius, darkSurface),
      snackBarTheme: _createSnackBarTheme(borderRadius, Colors.grey.shade900),
      checkboxTheme: _createCheckboxTheme(smallBorderRadius),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
    );
  }

  /// Creates standard text theme with given colors
  static TextTheme _createTextTheme(
      Color primaryTextColor, Color secondaryTextColor) {
    return TextTheme(
      displayLarge: TextStyle(
        color: primaryTextColor,
        fontWeight: _boldWeight,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        color: primaryTextColor,
        fontWeight: _boldWeight,
        fontSize: 28,
        letterSpacing: -0.5,
      ),
      displaySmall: TextStyle(
        color: primaryTextColor,
        fontWeight: _boldWeight,
        fontSize: 24,
        letterSpacing: 0,
      ),
      headlineLarge: TextStyle(
        color: primaryTextColor,
        fontWeight: _semiBoldWeight,
        fontSize: 20,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: primaryTextColor,
        fontWeight: _semiBoldWeight,
        fontSize: 18,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: primaryTextColor,
        fontWeight: _semiBoldWeight,
        fontSize: 16,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: primaryTextColor,
        fontWeight: _semiBoldWeight,
        fontSize: 16,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: primaryTextColor,
        fontWeight: _mediumWeight,
        fontSize: 14,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        color: primaryTextColor,
        fontWeight: _mediumWeight,
        fontSize: 13,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: primaryTextColor,
        fontWeight: _regularWeight,
        fontSize: 16,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: primaryTextColor,
        fontWeight: _regularWeight,
        fontSize: 14,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        color: secondaryTextColor,
        fontWeight: _regularWeight,
        fontSize: 12,
        letterSpacing: 0,
      ),
    );
  }

  /// Creates elevated button theme
  static ElevatedButtonThemeData _createElevatedButtonTheme(
      BorderRadius borderRadius) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: _buttonTextStyle,
        padding: _buttonPadding,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        elevation: 0,
      ),
    );
  }

  /// Creates card theme
  static CardTheme _createCardTheme(BorderRadius borderRadius, Color cardColor,
      {double shadowOpacity = 0.05}) {
    return CardTheme(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      shadowColor: Colors.black
          .withValues(alpha: (shadowOpacity * 255).round().toDouble()),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    );
  }

  /// Creates snackbar theme
  static SnackBarThemeData _createSnackBarTheme(
      BorderRadius borderRadius, Color backgroundColor) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    );
  }

  /// Creates checkbox theme
  static CheckboxThemeData _createCheckboxTheme(BorderRadius borderRadius) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? primaryColor : null;
      }),
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
    );
  }

  /// Creates input decoration theme
  static InputDecorationTheme _createInputDecorationTheme(
      BorderRadius borderRadius, Color fillColor) {
    return InputDecorationTheme(
      fillColor: fillColor,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: _inputPadding,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      errorStyle: const TextStyle(color: errorColor, fontSize: 12),
    );
  }
}
