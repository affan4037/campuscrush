import 'package:flutter/material.dart';
import '../models/reaction.dart';
import 'reaction_emoji.dart';

class ReactionOptions extends StatelessWidget {
  final Function(ReactionType) onSelected;
  final VoidCallback onDismiss;

  const ReactionOptions({
    super.key,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size to scale proportionally
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate sizes relative to screen width
    final containerPadding = EdgeInsets.symmetric(
      horizontal: screenWidth * 0.02, // 2% of screen width
      vertical: screenWidth * 0.015, // 1.5% of screen width
    );

    final spaceBetweenItems = screenWidth * 0.01; // 1% of screen width

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(
          screenWidth * 0.06), // 6% of screen width for rounded corners
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 20),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: containerPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _buildReactionOptions(context, spaceBetweenItems),
        ),
      ),
    );
  }

  List<Widget> _buildReactionOptions(
      BuildContext context, double spaceBetweenItems) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Define reaction size relative to screen width
    final itemSize = screenWidth * 0.065; // 6.5% of screen width
    final emojiSize = itemSize * 0.75; // 75% of item size

    final reactions = [
      ReactionType.like,
      ReactionType.love,
      ReactionType.haha,
      ReactionType.wow,
      ReactionType.sad,
      ReactionType.angry,
    ];

    final widgets = <Widget>[];

    for (int i = 0; i < reactions.length; i++) {
      if (i > 0) {
        widgets.add(SizedBox(width: spaceBetweenItems));
      }
      widgets.add(
          _buildReactionOption(context, reactions[i], itemSize, emojiSize));
    }

    return widgets;
  }

  Widget _buildReactionOption(BuildContext context, ReactionType type,
      double itemSize, double emojiSize) {
    final fontSize = itemSize * 0.3; // 30% of item size for font

    return GestureDetector(
      onTap: () => onSelected(type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: itemSize,
            height: itemSize,
            child: ReactionEmoji(
              reactionType: type,
              size: emojiSize,
            ),
          ),
          SizedBox(height: itemSize * 0.12),
          Text(
            _getReactionText(type),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getReactionText(ReactionType type) => switch (type) {
        ReactionType.like => 'Like',
        ReactionType.love => 'Love',
        ReactionType.haha => 'Haha',
        ReactionType.wow => 'Wow',
        ReactionType.sad => 'Sad',
        ReactionType.angry => 'Angry',
      };
}
