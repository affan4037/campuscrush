import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool showText;
  final double spacing;
  final TextStyle? textStyle;

  const LoadingWidget({
    super.key,
    this.message,
    this.size = 40,
    this.strokeWidth = 4,
    this.color,
    this.showText = false,
    this.spacing = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = TextStyle(
      fontSize: 16,
      color: Colors.grey[700],
    );

    final bool hasValidMessage = message?.isNotEmpty ?? false;
    final Color indicatorColor = color ?? AppColors.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
          if (showText && hasValidMessage) ...[
            SizedBox(height: spacing),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: textStyle ?? defaultTextStyle,
            ),
          ],
        ],
      ),
    );
  }
}
