import 'dart:convert';

import 'chat_date_separator.dart';

/// Deterministic display-only rules for messages in ChatPage.
/// This does not mutate a Zalo message or affect acceptance/reply APIs.
abstract final class ChatMessagePresentation {
  static bool isRecallExpired(
    Map<String, dynamic> message, {
    DateTime? now,
  }) {
    final timestampMs = messageTimestampMs(message);
    // Missing or future timestamp: let the backend decide.
    if (timestampMs == null) return false;

    final ageMs = (now ?? DateTime.now()).millisecondsSinceEpoch - timestampMs;
    return ageMs >= const Duration(hours: 1).inMilliseconds;
  }

  static List<Map<String, dynamic>> mentions(
    Map<String, dynamic> message,
  ) {
    final raw = message['rawData'];
    if (raw is! Map) return const [];
    dynamic value = raw['mentions'] ?? raw['mention'];
    if (value == null && raw['propertyExt'] is String) {
      try {
        final decoded = jsonDecode(raw['propertyExt'] as String);
        if (decoded is Map) {
          value = decoded['mentions'] ?? decoded['mention'];
        }
      } catch (_) {
        // Malformed Zalo propertyExt should not break chat rendering.
      }
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static String formatTime(dynamic timestamp) {
    final raw = int.tryParse(timestamp?.toString() ?? '');
    if (raw == null || raw <= 0) return '';

    final timestampMs = raw < 100000000000 ? raw * 1000 : raw;
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String textContent(
    Map<String, dynamic> message, {
    required bool isPhoto,
  }) {
    final status = message['status']?.toString() ?? 'normal';
    if (status == 'recalled') return 'Tin nhắn đã được thu hồi';
    if (isPhoto) return '[Hình ảnh]';
    return message['content']?.toString() ??
        message['preview']?.toString() ??
        '[Tin nhắn]';
  }

  static String stableId(Map<String, dynamic> message, int index) {
    return message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        index.toString();
  }
}
