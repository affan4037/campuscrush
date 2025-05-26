import 'package:flutter/material.dart';

/// A reusable error display widget that shows an error message with optional retry and dismiss actions
class ErrorDisplay extends StatelessWidget {
  final String error;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;
  final String? details;

  const ErrorDisplay({
    super.key,
    required this.error,
    this.onDismiss,
    this.onRetry,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: errorColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(color: errorColor),
                ),
              ),
              _buildActionButton(
                visible: onRetry != null,
                icon: Icons.refresh,
                onPressed: onRetry,
                tooltip: 'Retry',
                color: errorColor,
              ),
              _buildActionButton(
                visible: onDismiss != null,
                icon: Icons.close,
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                color: errorColor,
              ),
            ],
          ),
          if (details != null) ...[
            const SizedBox(height: 8),
            Text(
              details!,
              style: TextStyle(
                color: errorColor.withAlpha((0.7 * 255).round()),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required bool visible,
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required Color color,
  }) {
    if (!visible) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(icon),
      color: color,
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      splashRadius: 24,
    );
  }
}
