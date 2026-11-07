import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/settings/settings_tile.dart';
import 'package:zauto_driver/theme/app_typography.dart';

void main() {
  test('settings item title is larger and bolder than description', () {
    final title = AppTypography.settingsItemTitle;
    final description = AppTypography.settingsItemDescription;

    expect(title.fontSize, greaterThan(description.fontSize!));
    expect(title.fontWeight, FontWeight.w700);
    expect(description.fontWeight, FontWeight.w400);
  });

  testWidgets('settings tiles use the distinct title and description styles',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Giao diện và Tương tác',
            subtitle: 'Chủ đề, cỡ chữ, thẻ cuốc',
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Giao diện và Tương tác'));
    final description = tester.widget<Text>(find.text('Chủ đề, cỡ chữ, thẻ cuốc'));

    expect(title.style?.fontSize, AppTypography.settingsItemTitle.fontSize);
    expect(title.style?.fontWeight, FontWeight.w700);
    expect(description.style?.fontSize,
        AppTypography.settingsItemDescription.fontSize);
    expect(description.style?.fontWeight, FontWeight.w400);
  });
}
