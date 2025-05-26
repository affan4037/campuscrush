import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final double iconSize;
  final double fontSize;
  final double padding;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.showRetryButton = true,
    this.iconSize = 64,
    this.fontSize = 16,
    this.padding = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const double defaultSpacing = 16;
    const double largeSpacing = 24;
    const double buttonBorderRadius = 30;
    const double buttonHorizontalPadding = 24;
    const double buttonVerticalPadding = 12;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: iconSize,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: defaultSpacing),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: fontSize,
                color: theme.colorScheme.error,
              ),
            ),
            if (showRetryButton && onRetry != null) ...[
              const SizedBox(height: largeSpacing),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onPrimary,
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: buttonHorizontalPadding,
                    vertical: buttonVerticalPadding,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(buttonBorderRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
