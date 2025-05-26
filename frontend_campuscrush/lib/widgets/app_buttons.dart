import 'package:flutter/material.dart';

/// Base class for app buttons that handles common functionality
abstract class BaseAppButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool useCompactLayout;

  const BaseAppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.useCompactLayout = false,
  });

  Widget buildButton(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return isFullWidth
        ? SizedBox(width: double.infinity, child: buildButton(context))
        : buildButton(context);
  }

  Widget buildButtonContent(BuildContext context) {
    final bool isPrimary = this is PrimaryButton;
    final double iconSize = useCompactLayout ? 16 : 24;
    final double fontSize = useCompactLayout ? 12 : 14;
    final double spacing = useCompactLayout ? 4 : 8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: useCompactLayout ? 16 : 20,
            height: useCompactLayout ? 16 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary ? Colors.white : Theme.of(context).primaryColor,
              ),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: iconSize),
          SizedBox(width: spacing),
        ],
        Text(
          label,
          style: TextStyle(fontSize: fontSize),
        ),
      ],
    );
  }

  EdgeInsetsGeometry get buttonPadding => EdgeInsets.symmetric(
        horizontal: useCompactLayout ? 8 : 16,
        vertical: useCompactLayout ? 8 : 12,
      );
}

class PrimaryButton extends BaseAppButton {
  const PrimaryButton({
    super.key,
    required super.onPressed,
    required super.label,
    super.icon,
    super.isLoading,
    super.isFullWidth,
    super.useCompactLayout,
  });

  @override
  Widget buildButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(padding: buttonPadding),
      child: buildButtonContent(context),
    );
  }
}

class SecondaryButton extends BaseAppButton {
  const SecondaryButton({
    super.key,
    required super.onPressed,
    required super.label,
    super.icon,
    super.isLoading,
    super.isFullWidth,
    super.useCompactLayout,
  });

  @override
  Widget buildButton(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(padding: buttonPadding),
      child: buildButtonContent(context),
    );
  }
}
