import 'package:flutter/material.dart';

class ChatMessageActionsSheet extends StatelessWidget {
  final bool canReply;

  final bool canCopy;
  final bool canPrivateMessage;
  final VoidCallback onPrivateMessage;

  final bool canUndo;

  final VoidCallback onReply;

  final Future<void> Function() onCopy;

  final VoidCallback onUndo;

  final VoidCallback onDelete;

  final bool canDownload;

  final Future<void> Function()? onDownload;

  const ChatMessageActionsSheet({
    super.key,
    required this.canReply,
    required this.canCopy,
    required this.canPrivateMessage,
    required this.onPrivateMessage,
    required this.canUndo,
    required this.onReply,
    required this.onCopy,
    required this.onUndo,
    required this.onDelete,
    this.canDownload = false,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canReply)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Trả lời'),
              onTap: () {
                Navigator.of(context).pop();

                onReply();
              },
            ),

          if (canPrivateMessage)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Nhắn tin riêng'),
              onTap: () {
                Navigator.of(context).pop();
                onPrivateMessage();
              },
            ),

          if (canCopy)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Sao chép'),
              onTap: () async {
                Navigator.of(context).pop();

                await onCopy();
              },
            ),

          if (canDownload && onDownload != null)
            ListTile(
              leading: const Icon(Icons.download_rounded),

              title: const Text('Tải xuống'),

              onTap: () async {
                Navigator.of(context).pop();

                await onDownload!();
              },
            ),

          if (canUndo)
            ListTile(
              leading: Icon(Icons.undo_rounded, color: errorColor),
              title: Text('Thu hồi', style: TextStyle(color: errorColor)),
              onTap: () {
                Navigator.of(context).pop();

                onUndo();
              },
            ),

          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: errorColor),
            title: Text('Xóa', style: TextStyle(color: errorColor)),
            onTap: () {
              Navigator.of(context).pop();

              onDelete();
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
