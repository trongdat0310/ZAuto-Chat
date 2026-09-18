import 'package:flutter/material.dart';

import 'swipe_reply_wrapper.dart';

class TextMessageRow extends StatelessWidget {
  final Key rowKey;

  final bool isSelf;

  final bool highlighted;

  final bool swipeEnabled;

  final Widget? senderAvatar;

  final Widget bubble;

  final VoidCallback onReply;

  final VoidCallback onLongPress;

  const TextMessageRow({
    super.key,
    required this.rowKey,
    required this.isSelf,
    required this.highlighted,
    required this.swipeEnabled,
    required this.senderAvatar,
    required this.bubble,
    required this.onReply,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final messageRow = Container(
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

          Flexible(child: bubble),
        ],
      ),
    );

    return SwipeReplyWrapper(
      enabled: swipeEnabled,

      onReply: onReply,

      onLongPress: onLongPress,

      child: messageRow,
    );
  }
}
