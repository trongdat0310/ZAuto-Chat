import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/chat/chat_message_presentation.dart';

void main() {
  test('recall is allowed before one hour, expired at exactly one hour', () {
    final now = DateTime.utc(2026, 11, 17, 12);
    final nowMs = now.millisecondsSinceEpoch;
    expect(ChatMessagePresentation.isRecallExpired(
      {'timestamp': nowMs - const Duration(hours: 1).inMilliseconds + 1},
      now: now,
    ), isFalse);
    expect(ChatMessagePresentation.isRecallExpired(
      {'timestamp': nowMs - const Duration(hours: 1).inMilliseconds},
      now: now,
    ), isTrue);
    expect(ChatMessagePresentation.isRecallExpired(
      {'timestamp': nowMs + 4000},
      now: now,
    ), isFalse);
    expect(ChatMessagePresentation.isRecallExpired(
      {'timestamp': 'unknown'},
      now: now,
    ), isFalse);
    expect(ChatMessagePresentation.isRecallExpired({}, now: now), isFalse);
  });

  test('recall expiration supports unix seconds and milliseconds', () {
    final now = DateTime.utc(2026, 11, 17, 12);
    final old = now.subtract(const Duration(hours: 2));
    expect(ChatMessagePresentation.isRecallExpired(
      {'timestamp': old.millisecondsSinceEpoch ~/ 1000},
      now: now,
    ), isTrue);
    expect(ChatMessagePresentation.isRecallExpired(
      {'timestamp': old.millisecondsSinceEpoch},
      now: now,
    ), isTrue);
  });

  test('mentions preserve priority and parse Zalo propertyExt JSON', () {
    final direct = ChatMessagePresentation.mentions({
      'rawData': {
        'mentions': [{'uid': 'driver-1', 'pos': 3}],
        'propertyExt': '{"mentions":[{"uid":"not-selected"}]}',
      },
    });
    expect(direct.single['uid'], 'driver-1');

    final encoded = ChatMessagePresentation.mentions({
      'rawData': {
        'propertyExt': jsonEncode({
          'mention': [{'uid': 'u-1'}, {'uid': 'u-2'}],
        }),
      },
    });
    expect(encoded.map((item) => item['uid']), ['u-1', 'u-2']);
    expect(ChatMessagePresentation.mentions({
      'rawData': {'propertyExt': '{"bad"'},
    }), isEmpty);
    expect(ChatMessagePresentation.mentions({'rawData': null}), isEmpty);
    expect(ChatMessagePresentation.mentions({
      'rawData': {'mentions': 'not-a-list'},
    }), isEmpty);
  });

  test('message time is local and accepts seconds, milliseconds and invalid', () {
    final date = DateTime(2026, 10, 7, 9, 5);
    final ms = date.millisecondsSinceEpoch;
    expect(ChatMessagePresentation.formatTime(ms), '09:05');
    // Epoch seconds round down sub-second components.
    expect(ChatMessagePresentation.formatTime(ms ~/ 1000), '09:05');
    expect(ChatMessagePresentation.formatTime(''), '');
    expect(ChatMessagePresentation.formatTime(null), '');
    expect(ChatMessagePresentation.formatTime(-1), '');
  });

  test('recalled and photo messages override ordinary text, keep fallbacks', () {
    expect(ChatMessagePresentation.textContent(
      {'status': 'recalled', 'content': 'hidden'}, isPhoto: false,
    ), 'Tin nhắn đã được thu hồi');
    expect(ChatMessagePresentation.textContent(
      {'status': 'normal', 'content': 'caption'}, isPhoto: true,
    ), '[Hình ảnh]');
    expect(ChatMessagePresentation.textContent(
      {'preview': 'Cuốc lúc 7 giờ'}, isPhoto: false,
    ), 'Cuốc lúc 7 giờ');
    expect(ChatMessagePresentation.textContent({}, isPhoto: false),
        '[Tin nhắn]');
    expect(ChatMessagePresentation.textContent(
      {'content': ''}, isPhoto: false,
    ), '');
  });

  test('stable IDs prefer internal ID, then Zalo IDs, then index', () {
    expect(ChatMessagePresentation.stableId({
      'id': 'internal', 'msgId': 'm1', 'cliMsgId': 'c1',
    }, 3), 'internal');
    expect(ChatMessagePresentation.stableId({
      'msgId': 'm1', 'cliMsgId': 'c1',
    }, 3), 'm1');
    expect(ChatMessagePresentation.stableId({
      'cliMsgId': 'c1',
    }, 3), 'c1');
    expect(ChatMessagePresentation.stableId({}, 3), '3');
  });
}
