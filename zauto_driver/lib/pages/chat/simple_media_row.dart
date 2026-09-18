import 'package:flutter/material.dart';

import 'swipe_reply_wrapper.dart';

class SimpleMediaRow extends StatelessWidget {
  final Key rowKey;

  final bool isSelf;

  final bool highlighted;

  final String senderName;

  final Widget? senderAvatar;

  final Widget media;

  final String timeText;

  final VoidCallback onReply;

  final VoidCallback onLongPress;

  const SimpleMediaRow({
    super.key,
    required this.rowKey,
    required this.isSelf,
    required this.highlighted,
    required this.senderName,
    required this.senderAvatar,
    required this.media,
    required this.timeText,
    required this.onReply,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Container(
      key: rowKey,

      color: highlighted
          ? colorScheme.primary.withValues(alpha: 0.20)
          : Colors.transparent,

      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),

      child: Row(
        mainAxisAlignment: isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ========================================
          // AVATAR NGUOI KHAC
          // ========================================

          if (!isSelf && senderAvatar != null) ...[
            senderAvatar!,

            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isSelf
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,

              children: [
                // ========================================
                // TEN NGUOI GUI
                // ========================================

                if (!isSelf) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),

                    child: Text(
                      senderName,

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: FontWeight.w600,

                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],

                // ========================================
                // MEDIA
                // ========================================
                media,

                const SizedBox(height: 3),

                // ========================================
                // TIME
                // ========================================
                Text(
                  timeText,

                  style: TextStyle(
                    fontSize: 10,

                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SwipeReplyWrapper(
      enabled: true,

      onReply: onReply,

      onLongPress: onLongPress,

      child: content,
    );
  }
}
