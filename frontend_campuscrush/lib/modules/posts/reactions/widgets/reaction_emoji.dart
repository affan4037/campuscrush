import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/reaction.dart';

class ReactionEmoji extends StatelessWidget {
  final ReactionType reactionType;
  final double size;

  const ReactionEmoji({
    super.key,
    required this.reactionType,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getReactionConfig(reactionType);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: config.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 15),
            blurRadius: 2,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Center(
        child: config.isEmoji
            ? Text(
                config.emoji!,
                style: TextStyle(fontSize: size * 0.625),
              )
            : Icon(
                config.icon!,
                size: size * (config.iconSizeRatio ?? 0.625),
                color: Colors.white,
              ),
      ),
    );
  }

  _ReactionConfig _getReactionConfig(ReactionType type) {
    switch (type) {
      case ReactionType.like:
        return const _ReactionConfig(
          color: Colors.blue,
          icon: Icons.thumb_up,
        );
      case ReactionType.love:
        return const _ReactionConfig(
          color: Colors.red,
          icon: FontAwesomeIcons.heart,
          iconSizeRatio: 0.5,
        );
      case ReactionType.haha:
        return const _ReactionConfig(
          color: Colors.amber,
          emoji: '😂',
          isEmoji: true,
        );
      case ReactionType.wow:
        return const _ReactionConfig(
          color: Colors.amber,
          emoji: '😮',
          isEmoji: true,
        );
      case ReactionType.sad:
        return const _ReactionConfig(
          color: Colors.amber,
          emoji: '😢',
          isEmoji: true,
        );
      case ReactionType.angry:
        return const _ReactionConfig(
          color: Colors.orange,
          emoji: '😡',
          isEmoji: true,
        );
    }
  }
}

class _ReactionConfig {
  final Color color;
  final IconData? icon;
  final String? emoji;
  final bool isEmoji;
  final double? iconSizeRatio;

  const _ReactionConfig({
    required this.color,
    this.icon,
    this.emoji,
    this.isEmoji = false,
    this.iconSizeRatio,
  }) : assert((isEmoji && emoji != null) || (!isEmoji && icon != null),
            'Must provide either emoji or icon based on isEmoji flag');
}
