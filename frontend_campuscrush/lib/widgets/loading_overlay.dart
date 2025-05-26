import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// A customizable loading overlay widget
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? overlayColor;
  final Color? indicatorColor;
  final double opacity;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor = Colors.white,
    this.indicatorColor,
    this.opacity = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return child;
    }

    return Stack(
      children: [
        child,
        _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    const double spacing = 12.0;
    const double fontSize = 14.0;
    const double indicatorSize = 24.0;
    const double indicatorStrokeWidth = 3.0;
    final Color actualIndicatorColor = indicatorColor ?? AppColors.primary;

    return Container(
      color: overlayColor?.withOpacity(opacity),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: indicatorSize,
                height: indicatorSize,
                child: CircularProgressIndicator(
                  strokeWidth: indicatorStrokeWidth,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(actualIndicatorColor),
                ),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: spacing),
                  child: Text(
                    message!,
                    style: const TextStyle(
                      color: Color(0xFF191919),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
