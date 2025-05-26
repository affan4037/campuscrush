import 'package:flutter/material.dart';

/// App-wide styling utilities
class AppStyling {
  const AppStyling._();

  // Color constants
  static const Color primaryBlue = Color(0xFF0A66C2);
  static const Color lightBlue = Color(0xFF378FE9);
  static const Color darkBlue = Color(0xFF004182);
  static const Color green = Color(0xFF057642);
  static const Color background = Color(0xFFF3F2EF);
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF191919);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFF86888A);

  // Common values
  static const double _defaultBorderRadius = 8.0;
  static const double _buttonBorderRadius = 24.0;
  static const FontWeight _semiboldWeight = FontWeight.w600;
  static const FontWeight _regularWeight = FontWeight.w400;
  static const double _defaultLetterSpacing = 0;

  // Common padding
  static const EdgeInsets _buttonPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 12);
  static const EdgeInsets sectionPadding = EdgeInsets.all(16);
  static const EdgeInsets cardMargin = EdgeInsets.only(bottom: 8);

  /// Card decoration
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: white,
    borderRadius: BorderRadius.circular(_defaultBorderRadius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 1,
        offset: const Offset(0, 1),
      ),
    ],
  );

  /// Primary button style
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: white,
    elevation: 0,
    padding: _buttonPadding,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: _semiboldWeight,
      letterSpacing: _defaultLetterSpacing,
    ),
  );

  /// Secondary button style
  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    backgroundColor: white,
    foregroundColor: primaryBlue,
    elevation: 0,
    side: const BorderSide(color: primaryBlue),
    padding: _buttonPadding,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonBorderRadius),
    ),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: _semiboldWeight,
      letterSpacing: _defaultLetterSpacing,
    ),
  );

  /// Heading text style
  static const TextStyle headingStyle = TextStyle(
    fontSize: 20,
    fontWeight: _semiboldWeight,
    color: textPrimary,
    letterSpacing: _defaultLetterSpacing,
    height: 1.3,
  );

  /// Subheading text style
  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 16,
    fontWeight: _semiboldWeight,
    color: textPrimary,
    letterSpacing: _defaultLetterSpacing,
    height: 1.3,
  );

  /// Body text style
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: _regularWeight,
    color: textPrimary,
    letterSpacing: _defaultLetterSpacing,
    height: 1.4,
  );

  /// Caption text style
  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: _regularWeight,
    color: textSecondary,
    letterSpacing: _defaultLetterSpacing,
  );

  /// Link text style
  static const TextStyle linkStyle = TextStyle(
    fontSize: 14,
    fontWeight: _semiboldWeight,
    color: primaryBlue,
    letterSpacing: _defaultLetterSpacing,
  );

  /// Standard divider
  static final Divider divider = Divider(
    color: Colors.grey.shade200,
    thickness: 1,
    height: 1,
  );
}
