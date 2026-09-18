import 'package:flutter/material.dart';

// ========================================
// MESSAGE TIMESTAMP
// ========================================

int? messageTimestampMs(Map<String, dynamic> message) {
  final raw = int.tryParse(message['timestamp']?.toString() ?? '');

  if (raw == null || raw <= 0) {
    return null;
  }

  // ========================================
  // HO TRO UNIX SECOND
  // ========================================

  if (raw < 100000000000) {
    return raw * 1000;
  }

  return raw;
}

// ========================================
// CUNG NGAY HAY KHONG
// ========================================

bool isSameCalendarDay(
  Map<String, dynamic> first,
  Map<String, dynamic> second,
) {
  final firstMs = messageTimestampMs(first);

  final secondMs = messageTimestampMs(second);

  if (firstMs == null || secondMs == null) {
    return false;
  }

  final firstDate = DateTime.fromMillisecondsSinceEpoch(firstMs, isUtc: false);

  final secondDate = DateTime.fromMillisecondsSinceEpoch(
    secondMs,
    isUtc: false,
  );

  return firstDate.year == secondDate.year &&
      firstDate.month == secondDate.month &&
      firstDate.day == secondDate.day;
}

// ========================================
// LABEL NGAY
// ========================================

String formatDateSeparator(Map<String, dynamic> message) {
  final timestampMs = messageTimestampMs(message);

  if (timestampMs == null) {
    return '';
  }

  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();

  final now = DateTime.now();

  // ========================================
  // HOM NAY
  // ========================================

  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;

  if (isToday) {
    return 'Hôm nay';
  }

  // ========================================
  // HOM QUA
  // ========================================

  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1));

  final isYesterday =
      date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day;

  if (isYesterday) {
    return 'Hôm qua';
  }

  // ========================================
  // NGAY CU
  // ========================================

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

// ========================================
// DATE SEPARATOR UI
// ========================================

class ChatDateSeparator extends StatelessWidget {
  final String label;

  const ChatDateSeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      child: Center(
        child: Text(
          label,

          style: TextStyle(
            fontSize: 12,

            fontWeight: FontWeight.w500,

            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
