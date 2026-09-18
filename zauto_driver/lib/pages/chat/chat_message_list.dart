import 'package:flutter/material.dart';

import 'chat_date_separator.dart';

typedef ChatMessageBuilder = Widget Function(
  Map<String, dynamic> message,
  int index,
);

typedef ChatScrollNotificationHandler = bool Function(
  ScrollNotification notification,
);

class ChatMessageList extends StatelessWidget {
  final bool loading;

  final List<Map<String, dynamic>> messages;

  final ScrollController scrollController;

  final ChatMessageBuilder messageBuilder;

  final ChatScrollNotificationHandler onScrollNotification;

  const ChatMessageList({
    super.key,
    required this.loading,
    required this.messages,
    required this.scrollController,
    required this.messageBuilder,
    required this.onScrollNotification,
  });

  @override
  Widget build(BuildContext context) {
    // ========================================
    // LOADING
    // ========================================

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ========================================
    // EMPTY CHAT
    // ========================================

    if (messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        children: const [
          SizedBox(height: 250),

          Icon(Icons.chat_bubble_outline, size: 64),

          SizedBox(height: 14),

          Text(
            'Chưa có tin nhắn',

            textAlign: TextAlign.center,

            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    // ========================================
    // MESSAGE LIST
    // ========================================

    return NotificationListener<ScrollNotification>(
      onNotification: onScrollNotification,

      child: ListView.separated(
        controller: scrollController,

        // ========================================
        // MESSAGE MOI NHAT NAM O DUOI
        // ========================================
        reverse: true,

        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

        padding: const EdgeInsets.symmetric(vertical: 12),

        physics: const AlwaysScrollableScrollPhysics(),

        itemCount: messages.length,

        // ========================================
        // MESSAGE
        // ========================================
        itemBuilder: (context, displayIndex) {
          final messageIndex = messages.length - 1 - displayIndex;

          return messageBuilder(messages[messageIndex], messageIndex);
        },

        // ========================================
        // DATE SEPARATOR
        // ========================================
        separatorBuilder: (context, displayIndex) {
          final messageIndex = messages.length - 1 - displayIndex;

          // ========================================
          // KHONG CO TIN CU HON
          // ========================================

          if (messageIndex <= 0) {
            return const SizedBox(height: 0);
          }

          final currentMessage = messages[messageIndex];

          final olderMessage = messages[messageIndex - 1];

          // ========================================
          // CUNG NGAY
          // ========================================

          if (isSameCalendarDay(currentMessage, olderMessage)) {
            return const SizedBox(height: 0);
          }

          // ========================================
          // KHAC NGAY
          // ========================================

          return ChatDateSeparator(label: formatDateSeparator(currentMessage));
        },
      ),
    );
  }
}
