import 'package:flutter/material.dart';

class SwipeReplyWrapper extends StatefulWidget {
  final Widget child;

  final VoidCallback onReply;

  final VoidCallback onLongPress;

  final bool enabled;

  const SwipeReplyWrapper({
    super.key,
    required this.child,
    required this.onReply,
    required this.onLongPress,
    this.enabled = true,
  });

  @override
  State<SwipeReplyWrapper> createState() => _SwipeReplyWrapperState();
}

class _SwipeReplyWrapperState extends State<SwipeReplyWrapper> {
  double offsetX = 0;

  bool dragging = false;

  static const double maxDrag = 76;

  static const double triggerDistance = 46;

  void _reset() {
    if (!mounted) {
      return;
    }

    setState(() {
      dragging = false;

      offsetX = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final progress = (-offsetX / triggerDistance).clamp(0.0, 1.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,

      // ========================================
      // NHAN GIU
      // ========================================
      onLongPress: widget.onLongPress,

      // ========================================
      // VUOT TRAI DE REPLY
      // ========================================
      onHorizontalDragStart: widget.enabled
          ? (_) {
              setState(() {
                dragging = true;
              });
            }
          : null,

      onHorizontalDragUpdate: widget.enabled
          ? (details) {
              final next = (offsetX + details.delta.dx)
                  .clamp(-maxDrag, 0.0)
                  .toDouble();

              if (next == offsetX) {
                return;
              }

              setState(() {
                offsetX = next;
              });
            }
          : null,

      onHorizontalDragEnd: widget.enabled
          ? (details) {
              final velocity = details.primaryVelocity ?? 0;

              final shouldReply =
                  offsetX <= -triggerDistance || velocity < -650;

              _reset();

              if (shouldReply) {
                Future.microtask(widget.onReply);
              }
            }
          : null,

      onHorizontalDragCancel: widget.enabled ? _reset : null,

      child: Stack(
        alignment: Alignment.centerRight,

        children: [
          // ========================================
          // ICON REPLY
          // ========================================

          Positioned(
            right: 18,

            child: Opacity(
              opacity: progress,

              child: Transform.scale(
                scale: 0.75 + (0.25 * progress),

                child: Container(
                  width: 36,

                  height: 36,

                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    Icons.reply_rounded,

                    size: 22,

                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),

          // ========================================
          // BUBBLE DI CHUYEN THEO NGON TAY
          // ========================================
          AnimatedContainer(
            duration: dragging
                ? Duration.zero
                : const Duration(milliseconds: 160),

            curve: Curves.easeOutCubic,

            transform: Matrix4.translationValues(offsetX, 0, 0),

            child: widget.child,
          ),
        ],
      ),
    );
  }
}
