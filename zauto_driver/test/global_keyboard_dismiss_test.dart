import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/app/app.dart';


void main() {
  testWidgets(
    'tapping an action button does not dismiss the focused text field',
    (tester) async {
      final focusNode = FocusNode();

      addTearDown(focusNode.dispose);

      var taps = 0;


      await tester.pumpWidget(
        MaterialApp(
          home: GlobalKeyboardDismissRegion(
            child: Scaffold(
              body: Column(
                children: [
                  TextField(
                    focusNode: focusNode,
                  ),
                  FilledButton(
                    onPressed: () {
                      taps += 1;
                    },
                    child: const Text('Send'),
                  ),
                ],
              ),
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
        find.text('Send'),
      );

      await tester.pump();


      expect(
        taps,
        1,
      );

      expect(
        focusNode.hasFocus,
        isTrue,
      );
    },
  );


  testWidgets(
    'tapping empty space dismisses the focused text field',
    (tester) async {
      final focusNode = FocusNode();

      addTearDown(focusNode.dispose);


      await tester.pumpWidget(
        MaterialApp(
          home: GlobalKeyboardDismissRegion(
            child: Scaffold(
              body: Stack(
                children: [
                  const SizedBox.expand(),
                  Align(
                    alignment: Alignment.topCenter,
                    child: TextField(
                      focusNode: focusNode,
                    ),
                  ),
                ],
              ),
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


      await tester.tapAt(
        const Offset(20, 500),
      );

      await tester.pump();


      expect(
        focusNode.hasFocus,
        isFalse,
      );
    },
  );
}
