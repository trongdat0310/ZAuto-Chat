class ChatReplyController {
  Map<String, dynamic>? replyingToMessage;

  bool get hasReply => replyingToMessage != null;

  String? get replyMsgId => replyingToMessage?['msgId']?.toString();

  String? get replyCliMsgId => replyingToMessage?['cliMsgId']?.toString();

  String get composerSender {
    final reply = replyingToMessage;

    if (reply == null) {
      return 'Tin nhắn';
    }

    final isSelf = reply['isSelf'] == true;

    if (isSelf) {
      return 'Bạn';
    }

    return reply['senderName']?.toString() ?? 'Thành viên';
  }

  String get composerContent {
    final reply = replyingToMessage;

    if (reply == null) {
      return '';
    }

    return reply['content']?.toString() ??
        reply['preview']?.toString() ??
        '[Tin nhắn]';
  }

  // ========================================
  // START REPLY
  //
  // null = THANH CONG
  // String = LOI DE UI HIEN THI
  // ========================================

  String? startReply(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'normal';

    if (status != 'normal') {
      return 'Tin nhắn này không còn có thể trả lời.';
    }

    final msgId = message['msgId']?.toString().trim() ?? '';

    final cliMsgId = message['cliMsgId']?.toString().trim() ?? '';

    if (msgId.isEmpty && cliMsgId.isEmpty) {
      return 'Tin nhắn này chưa có ID Zalo để trả lời.';
    }

    replyingToMessage = Map<String, dynamic>.from(message);

    return null;
  }

  void cancelReply() {
    replyingToMessage = null;
  }

  void clearReply() {
    replyingToMessage = null;
  }

  // ========================================
  // EXTRACT QUOTE
  // ========================================

  Map<String, dynamic>? extractQuote(Map<String, dynamic> message) {
    final raw = message['rawData'];

    if (raw is Map) {
      final rawMap = Map<String, dynamic>.from(raw);

      final quote = rawMap['quote'];

      if (quote is Map) {
        return Map<String, dynamic>.from(quote);
      }
    }

    final directQuote = message['quote'];

    if (directQuote is Map) {
      return Map<String, dynamic>.from(directQuote);
    }

    return null;
  }
}
