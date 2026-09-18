import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';
import '../services/theme_service.dart';

import 'auth_gate.dart';

class ZautoDriverApp extends StatelessWidget {
  final SettingsController settingsController;

  const ZautoDriverApp({super.key, required this.settingsController});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,

      builder: (context, themeMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: 'Driver Assistant',

          // ========================================
          // LIGHT THEME
          // ========================================
          theme: ThemeData(
            useMaterial3: true,

            brightness: Brightness.light,

            colorSchemeSeed: Colors.blue,
          ),

          // ========================================
          // DARK THEME
          // ========================================
          darkTheme: ThemeData(
            useMaterial3: true,

            brightness: Brightness.dark,

            colorSchemeSeed: Colors.blue,
          ),

          themeMode: themeMode,

          home: AuthGate(settingsController: settingsController),
        );
      },
    );
  }
}
