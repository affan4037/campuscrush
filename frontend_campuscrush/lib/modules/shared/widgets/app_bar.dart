import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom AppBar with LinkedIn styling
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final double? elevation;
  final bool centerTitle;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final double? titleSpacing;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const CustomAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.elevation = 0, // LinkedIn uses flat app bars
    this.centerTitle = false, // LinkedIn left-aligns titles
    this.backgroundColor = Colors.white, // LinkedIn uses white app bars
    this.bottom,
    this.titleSpacing,
    this.systemOverlayStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle ?? SystemUiOverlayStyle.dark,
      child: AppBar(
        title: title,
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        elevation: elevation,
        centerTitle: centerTitle,
        backgroundColor: backgroundColor,
        bottom: bottom,
        titleSpacing: titleSpacing,
        iconTheme: const IconThemeData(
          color: Color(0xFF0A66C2), // LinkedIn blue for icons
          size: 24,
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF191919), // LinkedIn primary text color
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
