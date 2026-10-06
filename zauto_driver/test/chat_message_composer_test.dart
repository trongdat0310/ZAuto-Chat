import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/pages/chat/chat_message_composer.dart';


void main() {
  testWidgets(
    'send action keeps message input focused',
    (tester) async {
      final controller = TextEditingController(
        text: 'hello',
      );

      final focusNode = FocusNode();

      addTearDown(controller.dispose);

      addTearDown(focusNode.dispose);

      var sendCount = 0;


      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageComposer(
              controller: controller,
              focusNode: focusNode,
              disabled: false,
              sendingMessage: false,
              sendingPhoto: false,
              canSendMessage: true,
              hasReply: false,
              replySender: '',
              replyContent: '',
              onCancelReply: () {},
              onPickPhoto: () {},
              onSend: () {
                sendCount += 1;
              },
            ),
          ),
        ),
      );


      await tester.tap(
        find.byType(TextField),
      );

      await tester.pump();


      expect(
        focusNode.hasFocus,
        isTrue,
      );


      await tester.tap(
        find.byIcon(Icons.send_rounded),
      );

      await tester.pump();


      expect(
        sendCount,
        1,
      );

      expect(
        focusNode.hasFocus,
        isTrue,
      );
    },
  );


  testWidgets(
    'photo action also does not steal message input focus',
    (tester) async {
      final controller = TextEditingController(
        text: 'hello',
      );

      final focusNode = FocusNode();

      addTearDown(controller.dispose);

      addTearDown(focusNode.dispose);

      var photoCount = 0;


      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageComposer(
              controller: controller,
              focusNode: focusNode,
              disabled: false,
              sendingMessage: false,
              sendingPhoto: false,
              canSendMessage: true,
              hasReply: false,
              replySender: '',
              replyContent: '',
              onCancelReply: () {},
              onPickPhoto: () {
                photoCount += 1;
              },
              onSend: () {},
            ),
          ),
        ),
      );


      await tester.tap(
        find.byType(TextField),
      );

      await tester.pump();


      await tester.tap(
        find.byIcon(Icons.photo_outlined),
      );

      await tester.pump();


      expect(
        photoCount,
        1,
      );

      expect(
        focusNode.hasFocus,
        isTrue,
      );
    },
  );
}
