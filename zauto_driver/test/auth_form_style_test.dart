import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/widgets/auth_form_style.dart';

void main() {
  testWidgets('authentication and account forms share rounded input decoration',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextFormField(
              decoration: AuthFormStyle.field(
                context,
                hint: 'Email mới',
                icon: Icons.email_rounded,
                errorText: 'Email không hợp lệ',
              ),
            ),
          ),
        ),
      ),
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    final decoration = field.decoration!;
    expect(decoration.hintText, 'Email mới');
    expect(decoration.errorText, 'Email không hợp lệ');
    expect(decoration.filled, true);
    expect(decoration.prefixIcon, isA<Icon>());
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(18),
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(18),
    );
    expect(
      (decoration.errorBorder! as OutlineInputBorder).borderRadius,
      BorderRadius.circular(18),
    );
  });

  testWidgets('security action buttons submit or cancel when enabled',
      (tester) async {
    var cancelCount = 0;
    var submitCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AuthFormStyle.dialogActions(
              context,
              loading: false,
              onCancel: () => cancelCount++,
              onSubmit: () => submitCount++,
              submitLabel: 'LƯU EMAIL',
              loadingLabel: 'ĐANG LƯU...',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('LƯU EMAIL'));
    await tester.pump();
    await tester.tap(find.text('HỦY'));
    expect(submitCount, 1);
    expect(cancelCount, 1);
  });

  testWidgets('security form actions cannot submit while saving',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AuthFormStyle.dialogActions(
              context,
              loading: true,
              onCancel: () => fail('Cancel should be disabled'),
              onSubmit: () => fail('Submit should be disabled'),
              submitLabel: 'ĐỔI MẬT KHẨU',
              loadingLabel: 'ĐANG ĐỔI...',
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.text('ĐANG ĐỔI...'), findsOneWidget);
  });
}
