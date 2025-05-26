import 'package:flutter/material.dart';

/// A widget for displaying error messages with optional retry functionality
class ErrorDisplay extends StatelessWidget {
  final String? message;
  final String? error;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool showErrorTechnicalDetails;

  const ErrorDisplay({
    super.key,
    this.message,
    this.error,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.showErrorTechnicalDetails = false,
  });

  /// Factory constructor for backward compatibility
  factory ErrorDisplay.fromErrorMessage({
    Key? key,
    required String errorMessage,
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
  }) {
    return ErrorDisplay(
      key: key,
      message: errorMessage,
      onRetry: onRetry,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage = message ?? error ?? 'An error occurred';

    const double iconSize = 64;
    const double defaultPadding = 24.0;
    const double defaultSpacing = 16.0;
    const double mediumSpacing = 12.0;
    const double smallSpacing = 8.0;
    const double borderRadius = 8.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: theme.colorScheme.error.withOpacity(0.8),
            ),
            const SizedBox(height: defaultSpacing),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: mediumSpacing),
              Text(
                details!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (showErrorTechnicalDetails &&
                error != null &&
                error != message) ...[
              const SizedBox(height: smallSpacing),
              Container(
                padding: const EdgeInsets.all(smallSpacing),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: defaultPadding),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding,
                    vertical: smallSpacing + 4,
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

/// A widget for displaying form field error messages
class FormFieldError extends StatelessWidget {
  final String? errorText;

  const FormFieldError({
    super.key,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    if (errorText == null || errorText!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
      child: Text(
        errorText!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
