import 'package:flutter_test/flutter_test.dart';

// Compile the real app graph, not just isolated subscription widgets. This
// catches named-argument mismatches in MainScreen before a release APK build.
import 'package:zauto_driver/app/main_screen.dart';
import 'package:zauto_driver/pages/messages_page.dart';
import 'package:zauto_driver/pages/chat/chat_target_controller.dart';

void main() {
  test('app and message page constructors are available', () {
    // Constructor tear-offs do not mount widgets or start network/platform work.
    expect(MainScreen.new, isNotNull);
    expect(MessagesPage.new, isNotNull);
  });

  const acceptedAtMs = 1000000;

  ChatTargetController fallbackController() {
    final controller = ChatTargetController(
      targetMsgId: null,
      targetCliMsgId: null,
      targetReplyText: 'ok',
      targetAcceptedAtMs: acceptedAtMs,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Map<String, dynamic> messageAt(
    int offsetMs, {
    bool isSelf = true,
    String content = 'ok',
  }) => <String, dynamic>{
    'isSelf': isSelf,
    'content': content,
    'timestamp': acceptedAtMs + offsetMs,
  };

  test('history fallback chooses the nearest own matching reply', () {
    final controller = fallbackController();
    expect(controller.findTargetIndex([
      messageAt(0, isSelf: false),
      messageAt(0, content: 'different'),
      messageAt(5000),
      messageAt(-1000),
    ]), 3);
  });

  test('history fallback includes exactly two minutes in either direction', () {
    final controller = fallbackController();
    for (final offset in [-120000, 120000]) {
      expect(controller.findTargetIndex([messageAt(offset)]), 0);
    }
  });

  test('history fallback rejects more than two minutes in either direction', () {
    final controller = fallbackController();
    for (final offset in [-120001, 120001]) {
      expect(controller.findTargetIndex([messageAt(offset)]), -1);
    }
  });

  test('history fallback ignores missing and invalid timestamps', () {
    final controller = fallbackController();
    expect(controller.findTargetIndex([
      {'isSelf': true, 'content': 'ok'},
      {'isSelf': true, 'content': 'ok', 'timestamp': 'invalid'},
    ]), -1);
  });

  test('an explicit message ID takes precedence over client ID fallback', () {
    final controller = ChatTargetController(
      targetMsgId: 'server-id',
      targetCliMsgId: 'client-id',
      targetSelfOnly: true,
    );
    addTearDown(controller.dispose);
    expect(controller.findTargetIndex([
      {'msgId': 'different', 'cliMsgId': 'client-id', 'isSelf': true},
      {'msgId': 'server-id', 'isSelf': false},
      {'msgId': 'server-id', 'isSelf': true},
    ]), 2);
  });
}
