import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/chat/chat_target_controller.dart';
import 'package:zauto_driver/pages/home/trip_message_target.dart';

void main() {
  test('uses source Zalo IDs to reach the exact message, never trip ID', () {
    final target = TripMessageTarget.fromTrip({
      'id': 'internal-trip-record-42',
      'sourceThreadId': 'group-1',
      'groupId': 'fallback-group',
      'groupName': 'Nhóm xe',
      'sourceMsgId': 'zalo-msg-42',
      'sourceCliMsgId': 'zalo-cli-42',
      'content': 'Có cuốc Hà Nội đi Nội Bài',
    });
    expect(target, isNotNull);
    expect(target!.groupId, 'group-1');
    expect(target.groupName, 'Nhóm xe');
    expect(target.msgId, 'zalo-msg-42');
    expect(target.cliMsgId, 'zalo-cli-42');

    final finder = ChatTargetController(
      targetMsgId: target.msgId,
      targetCliMsgId: target.cliMsgId,
    );
    addTearDown(finder.dispose);
    expect(finder.findTargetIndex([
      {'msgId': 'other', 'cliMsgId': 'other-cli'},
      {'msgId': 'zalo-msg-42', 'cliMsgId': 'zalo-cli-42'},
    ]), 1);
  });

  test('legacy trip messages can use their Zalo and client ID aliases', () {
    final target = TripMessageTarget.fromTrip({
      'groupId': 'legacy-group',
      'zaloMessageId': 'old-zalo-id',
      'clientMessageId': 'old-client-id',
    });
    expect(target!.groupId, 'legacy-group');
    expect(target.groupName, 'Nhóm Zalo');
    expect(target.msgId, 'old-zalo-id');
    expect(target.cliMsgId, 'old-client-id');
  });

  test('falls back to cliMsgId when source msgId was not recorded', () {
    final target = TripMessageTarget.fromTrip({
      'groupId': 'group-2',
      'sourceCliMsgId': 'cli-only',
    });
    expect(target!.msgId, isNull);
    expect(target.cliMsgId, 'cli-only');
    final finder = ChatTargetController(
      targetMsgId: target.msgId,
      targetCliMsgId: target.cliMsgId,
    );
    addTearDown(finder.dispose);
    expect(finder.findTargetIndex([
      {'msgId': 'another', 'cliMsgId': 'not-this-one'},
      {'msgId': 'second', 'cliMsgId': 'cli-only'},
    ]), 1);
  });

  test('refuses to guess a source message from internal trip ID or content', () {
    expect(TripMessageTarget.fromTrip({
      'id': 'internal-only',
      'groupId': 'group',
      'content': 'Có cuốc',
    }), isNull);
    expect(TripMessageTarget.fromTrip({
      'id': 'internal-only',
      'sourceMsgId': 'zalo-message',
    }), isNull);
    expect(TripMessageTarget.fromTrip({
      'sourceThreadId': '   ',
      'groupId': ' ',
      'msgId': 'zalo-message',
    }), isNull);
  });

  test('trims blank fields and uses valid fallbacks', () {
    final target = TripMessageTarget.fromTrip({
      'sourceThreadId': ' ',
      'groupId': ' group ',
      'sourceMsgId': ' ',
      'zaloMessageId': ' zalo-msg ',
      'sourceCliMsgId': '  ',
      'cliMsgId': ' cli-msg ',
      'groupName': ' ',
      'sourceGroupName': ' Nhóm dự phòng ',
    });
    expect(target!.groupId, 'group');
    expect(target.msgId, 'zalo-msg');
    expect(target.cliMsgId, 'cli-msg');
    expect(target.groupName, 'Nhóm dự phòng');
  });
}
