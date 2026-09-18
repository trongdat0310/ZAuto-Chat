import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String groupName;

  final String? groupAvatar;

  const ChatAppBar({
    super.key,
    required this.groupName,
    required this.groupAvatar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final safeAvatar = groupAvatar?.trim();

    final hasAvatar = safeAvatar != null && safeAvatar.isNotEmpty;

    return AppBar(
      title: Row(
        children: [
          // ========================================
          // AVATAR NHOM
          // ========================================

          CircleAvatar(
            radius: 19,

            backgroundImage: hasAvatar ? NetworkImage(safeAvatar) : null,

            child: hasAvatar ? null : const Icon(Icons.group_rounded, size: 21),
          ),

          const SizedBox(width: 10),

          // ========================================
          // TEN NHOM
          // ========================================
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  groupName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 16,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  'Nhóm Zalo',

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 12,

                    fontWeight: FontWeight.normal,

                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
