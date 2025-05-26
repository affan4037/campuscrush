import 'package:flutter/material.dart';

/// A utility widget to add spacing between other widgets
class Spacing extends StatelessWidget {
  final double? width;
  final double? height;

  /// Creates spacing with the specified dimensions
  const Spacing({super.key, this.width, this.height});

  /// Creates horizontal spacing with the specified width
  const Spacing.horizontal(this.width, {super.key}) : height = null;

  /// Creates vertical spacing with the specified height
  const Spacing.vertical(this.height, {super.key}) : width = null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height);
  }
}

// These classes are left for backward compatibility. Will be removed in future updates.
/// A widget that adds horizontal spacing between widgets
class HorizontalSpacing extends StatelessWidget {
  final double width;

  /// Creates a horizontal spacing with the specified width
  const HorizontalSpacing(this.width, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width);
  }
}

/// A widget that adds vertical spacing between widgets
class VerticalSpacing extends StatelessWidget {
  final double height;

  /// Creates a vertical spacing with the specified height
  const VerticalSpacing(this.height, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}
