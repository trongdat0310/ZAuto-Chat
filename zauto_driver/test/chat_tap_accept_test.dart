import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/pages/chat/chat_tap_accept.dart';
import '../lib/pages/chat/text_message_row.dart';

void main() {
  Widget screen({
    required SubmitChatAccept submit,
    bool isSelf = false,
    String status = 'normal',
    VoidCallback? onReply,
    VoidCallback? onLongPress,
  }) => MaterialApp(home: Scaffold(body: ChatTapAccept(
    message: {'groupId': '111', 'msgId': '222', 'cliMsgId': '333',
      'isSelf': isSelf, 'status': status},
    submit: submit,
    loadReplyText: () async => 'ok',
    child: TextMessageRow(
      rowKey: const ValueKey('row'),
      isSelf: isSelf, highlighted: false, swipeEnabled: status == 'normal',
      senderAvatar: null,
      bubble: const Padding(padding: EdgeInsets.all(24), child: Text('Cuoc moi')),
      onReply: onReply ?? () {}, onLongPress: onLongPress ?? () {},
    ),
  )));
  testWidgets('one tap sends immediately; another tap while pending does not resend', (tester) async {
    var calls = 0;
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(screen(submit: (message, text) { calls++; expect(text, 'ok'); return pending.future; }));
    await tester.tap(find.text('Cuoc moi')); await tester.pump();
    expect(calls, 1);
    await tester.tap(find.text('Cuoc moi')); await tester.pump();
    expect(calls, 1);
    pending.complete({'success': true, 'alreadyAccepted': false});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuoc moi')); await tester.pump();
    expect(calls, 1);
  });
  testWidgets('self and recalled messages do not send', (tester) async {
    var calls = 0;
    Future<Map<String, dynamic>> submit(Map<String, dynamic> message, String text) async { calls++; return {}; }
    await tester.pumpWidget(screen(submit: submit, isSelf: true));
    await tester.tap(find.text('Cuoc moi')); await tester.pump();
    expect(calls, 0);
    await tester.pumpWidget(screen(submit: submit, status: 'recalled'));
    await tester.tap(find.text('Cuoc moi')); await tester.pump();
    expect(calls, 0);
  });
  testWidgets('long press and swipe retain their actions without accepting', (tester) async {
    var calls = 0, longPresses = 0, replies = 0;
    await tester.pumpWidget(screen(
      submit: (message, text) async { calls++; return {}; },
      onLongPress: () { longPresses++; }, onReply: () { replies++; },
    ));
    await tester.longPress(find.text('Cuoc moi')); await tester.pumpAndSettle();
    expect(longPresses, 1); expect(calls, 0);
    await tester.drag(find.text('Cuoc moi'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(replies, 1); expect(calls, 0);
  });
  testWidgets('quota error is shown without marking a message accepted', (tester) async {
    var calls = 0;
    await tester.pumpWidget(screen(submit: (message, text) async { calls++; throw Exception('Het luot'); }));
    await tester.tap(find.text('Cuoc moi')); await tester.pumpAndSettle();
    expect(calls, 1); expect(find.text('Het luot'), findsOneWidget);
  });
}
