import 'package:flutter/material.dart';

class ChatSenderAvatar extends StatelessWidget {
  final String senderName;

  final String? avatarUrl;

  const ChatSenderAvatar({
    super.key,
    required this.senderName,
    required this.avatarUrl,
  });

  String _initials() {
    final safeName = senderName.trim();

    if (safeName.isEmpty) {
      return '?';
    }

    final parts = safeName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final safeAvatar = avatarUrl?.trim();

    final hasAvatar = safeAvatar != null && safeAvatar.isNotEmpty;

    return CircleAvatar(
      radius: 17,

      backgroundImage: hasAvatar ? NetworkImage(safeAvatar) : null,

      child: hasAvatar ? null : Text(_initials()),
    );
  }
}
