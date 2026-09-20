import 'package:flutter/material.dart';

class ChatMessageActionsSheet extends StatelessWidget {
  final bool canReply;

  final bool canCopy;

  final bool canUndo;

  final VoidCallback onReply;

  final Future<void> Function() onCopy;

  final VoidCallback onUndo;

  final VoidCallback onDelete;

  const ChatMessageActionsSheet({
    super.key,
    required this.canReply,
    required this.canCopy,
    required this.canUndo,
    required this.onReply,
    required this.onCopy,
    required this.onUndo,
    required this.onDelete,
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

          if (canCopy)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Sao chép'),
              onTap: () async {
                Navigator.of(context).pop();

                await onCopy();
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
