import 'package:flutter/material.dart';

class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String text;
  final double loaderSize;
  final Color? loaderColor;
  final EdgeInsetsGeometry? padding;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.text,
    this.loaderSize = 20,
    this.loaderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalLoaderColor = loaderColor ?? theme.colorScheme.onPrimary;

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style:
          padding != null ? ElevatedButton.styleFrom(padding: padding) : null,
      child: isLoading
          ? SizedBox(
              height: loaderSize,
              width: loaderSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(finalLoaderColor),
              ),
            )
          : Text(text),
    );
  }
}
