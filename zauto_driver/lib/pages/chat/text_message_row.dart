import 'package:flutter/material.dart';

import 'swipe_reply_wrapper.dart';
import 'chat_tap_accept.dart';

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
    final accept = ChatAcceptScope.maybeOf(context);
    final Widget content;
    if (isSelf || !swipeEnabled || accept == null) {
      content = bubble;
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Chạm để nhận cuốc',
            enabled: accept.onAccept != null,
            child: GestureDetector(
              onTap: accept.onAccept,
              child: bubble,
            ),
          ),
          if (accept.busy || accept.accepted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                accept.busy ? 'Đang nhận cuốc...' : 'Đã nhận cuốc',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      );
    }
    final messageRow = Container(
      key: rowKey,
      color: highlighted
          ? colorScheme.primary.withValues(alpha: 0.20)
          : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSelf && senderAvatar != null) ...[
            senderAvatar!,
            const SizedBox(width: 8),
          ],
          Flexible(child: content),
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
