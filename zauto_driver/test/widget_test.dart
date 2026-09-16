import 'package:flutter_test/flutter_test.dart';

import 'package:zauto_driver/app/app.dart';
import 'package:zauto_driver/controllers/settings_controller.dart';


void main() {

  testWidgets(
    'ZautoDriverApp builds',
        (
        WidgetTester tester,
        ) async {

      final settingsController =
      SettingsController();


      await tester.pumpWidget(
        ZautoDriverApp(
          settingsController:
          settingsController,
        ),
      );


      await tester.pump();
    },
  );
}