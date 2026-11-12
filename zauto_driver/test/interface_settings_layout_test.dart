import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/controllers/settings_controller.dart';
import 'package:zauto_driver/pages/settings/interface_settings_sheet.dart';
import 'package:zauto_driver/services/backend_service.dart';

Future<void> _pumpInterfaceSettings(
  WidgetTester tester, {
  required ValueChanged<String> onThemeChanged,
}) async {
  final controller = SettingsController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: InterfaceSettingsSheet(
          settingsController: controller,
          backend: BackendService(baseUrl: 'http://localhost:3001'),
          initialTheme: 'light',
          initialFontSize: 15,
          initialTripDisplaySeconds: 10,
          initialAcceptButtonPosition: 'right',
          onThemeChanged: (value) async {
            onThemeChanged(value);
          },
          onFontSizeChanged: (_) async {},
          onTripDisplaySecondsChanged: (_) {},
          onAcceptButtonPositionChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('theme label aligns with font label and the picker stays inline',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? changed;

    await _pumpInterfaceSettings(
      tester,
      onThemeChanged: (value) => changed = value,
    );

    final themeLabel = tester.getRect(find.text('Giao diện'));
    final fontLabel = tester.getRect(find.text('Cỡ chữ thông báo'));
    final themePicker =
        tester.getRect(find.byKey(const ValueKey('theme-picker')));

    expect((themeLabel.left - fontLabel.left).abs(), lessThan(1));
    expect(themePicker.left, greaterThan(themeLabel.right));
    expect((themePicker.center.dy - themeLabel.center.dy).abs(), lessThan(3));
    expect(find.text('Sáng'), findsOneWidget);
    expect(find.text('Tối'), findsOneWidget);
    expect(find.text('Hệ thống'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-option-dark')));
    await tester.pump();
    expect(changed, 'dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screens wrap picker without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpInterfaceSettings(tester, onThemeChanged: (_) {});

    final label = tester.getRect(find.text('Giao diện'));
    final picker = tester.getRect(find.byKey(const ValueKey('theme-picker')));
    expect(picker.top, greaterThan(label.bottom));
    expect(tester.takeException(), isNull);
  });
}
