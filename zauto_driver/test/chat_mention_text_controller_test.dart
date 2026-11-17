import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/chat/chat_mention_text_controller.dart';

void main() {
  testWidgets('highlights only a mention prefix without altering text',
      (tester) async {
    final controller = ChatMentionTextController();
    addTearDown(controller.dispose);
    controller.mentionPrefix = '@Tài xế ';
    controller.text = '@Tài xế Tôi nhận cuốc';

    TextSpan? span;
    Color? primary;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          primary = Theme.of(context).colorScheme.primary;
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          );
          return const SizedBox.shrink();
        }),
      ),
    ));

    expect(span!.toPlainText(), '@Tài xế Tôi nhận cuốc');
    expect(span!.children, hasLength(2));
    final prefix = span!.children!.first as TextSpan;
    final rest = span!.children!.last as TextSpan;
    expect(prefix.text, '@Tài xế ');
    expect(prefix.style!.color, primary);
    expect(prefix.style!.fontWeight, FontWeight.w600);
    expect(rest.text, 'Tôi nhận cuốc');
  });

  testWidgets('does not highlight when the prefix is absent or misplaced',
      (tester) async {
    final controller = ChatMentionTextController();
    addTearDown(controller.dispose);
    controller.mentionPrefix = '@Minh ';
    controller.text = 'Xin chào @Minh';

    TextSpan? span;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(color: Colors.white),
            withComposing: false,
          );
          return const SizedBox.shrink();
        }),
      ),
    ));
    expect(span!.text, 'Xin chào @Minh');
    expect(span!.children, isNull);

    controller.mentionPrefix = null;
    expect(span!.toPlainText(), 'Xin chào @Minh');
  });
}
