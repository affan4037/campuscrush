import 'package:flutter/material.dart';
import '../reactions/models/reaction.dart';
import '../reactions/widgets/reaction_emoji.dart';
import '../reactions/widgets/reaction_options.dart';

class ReactionButton extends StatefulWidget {
  final bool isLiked;
  final ReactionType? currentReaction;
  final VoidCallback? onTap;
  final Function(ReactionType)? onReactionSelected;
  final VoidCallback? onReactionRemoved;

  const ReactionButton({
    Key? key,
    this.isLiked = false,
    this.currentReaction,
    this.onTap,
    this.onReactionSelected,
    this.onReactionRemoved,
  }) : super(key: key);

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  bool _showOptions = false;
  ReactionType? _selectedReaction;
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // Reaction text mapping - defined as static const for better performance
  static const Map<ReactionType, String> _reactionTexts = {
    ReactionType.like: 'Like',
    ReactionType.love: 'Love',
    ReactionType.haha: 'Haha',
    ReactionType.wow: 'Wow',
    ReactionType.sad: 'Sad',
    ReactionType.angry: 'Angry',
  };

  // Colors for each reaction type
  static final Map<ReactionType, Color> _reactionColors = {
    ReactionType.like: Colors.blue,
    ReactionType.love: Colors.red,
    ReactionType.haha: Colors.amber.shade700,
    ReactionType.wow: Colors.amber.shade700,
    ReactionType.sad: Colors.amber.shade700,
    ReactionType.angry: Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _selectedReaction = widget.currentReaction;
  }

  @override
  void didUpdateWidget(ReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentReaction != widget.currentReaction) {
      _selectedReaction = widget.currentReaction;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_showOptions) {
      setState(() {
        _showOptions = false;
      });
    }
  }

  void _showReactionOptions() {
    _removeOverlay();

    final RenderBox? renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

 
    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);
    final Size screenSize = MediaQuery.of(context).size;

    // Calculate optimal position for the reactions menu
    // Center it horizontally over the button if possible
    double left = buttonPosition.dx - 60; // Default offset

    // Ensure the popup doesn't overflow horizontally
    const double estimatedPopupWidth = 250; // Approximate width of popup
    if (left < 10) {
      left = 10; // Keep a minimum margin from left edge
    } else if (left + estimatedPopupWidth > screenSize.width - 10) {
      left = screenSize.width -
          estimatedPopupWidth -
          10; // Keep margin from right edge
    }

    // Position it above the button with some spacing
    final double bottom = screenSize.height - buttonPosition.dy + 10;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeOverlay,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            bottom: bottom,
            left: left,
            child: Material(
              color: Colors.transparent,
              child: ReactionOptions(
                onSelected: _handleReactionSelection,
                onDismiss: _removeOverlay,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _showOptions = true;
    });
  }

  void _handleReactionSelection(ReactionType reactionType) {
    _removeOverlay();

    if (_selectedReaction == reactionType) {
      _selectedReaction = null;
      widget.onReactionRemoved?.call();
    } else {
      _selectedReaction = reactionType;
      widget.onReactionSelected?.call(reactionType);
    }
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    final bool hasReaction = widget.currentReaction != null;
    final bool isLegacyLiked = widget.isLiked && !hasReaction;

    if (hasReaction || isLegacyLiked) {
      widget.onReactionRemoved?.call();
      if (hasReaction) {
        setState(() {
          _selectedReaction = null;
        });
      }
    } else {
      _selectedReaction = ReactionType.like;
      widget.onReactionSelected?.call(ReactionType.like);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasReaction = widget.currentReaction != null;
    final bool isLegacyLiked = widget.isLiked && !hasReaction;
    final Color textColor = _getReactionColor(widget.currentReaction);

    return GestureDetector(
      key: _buttonKey,
      onTap: _handleTap,
      onLongPress: _showReactionOptions,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReactionIcon(hasReaction, isLegacyLiked),
            const SizedBox(width: 4),
            Text(
              hasReaction ? _getReactionText(widget.currentReaction!) : 'Like',
              style: TextStyle(
                color:
                    hasReaction || isLegacyLiked ? textColor : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionIcon(bool hasReaction, bool isLegacyLiked) {
    if (hasReaction) {
      return ReactionEmoji(
        reactionType: widget.currentReaction!,
        size: 16,
      );
    } else if (isLegacyLiked) {
      return const Icon(
        Icons.thumb_up,
        size: 16,
        color: Colors.blue,
      );
    } else {
      return Icon(
        Icons.thumb_up_outlined,
        size: 16,
        color: Colors.grey[700],
      );
    }
  }

  Color _getReactionColor(ReactionType? reactionType) {
    if (reactionType == null) return Colors.grey.shade700;
    return _reactionColors[reactionType] ?? Colors.blue;
  }

  String _getReactionText(ReactionType reactionType) {
    return _reactionTexts[reactionType] ?? 'Like';
  }
}
