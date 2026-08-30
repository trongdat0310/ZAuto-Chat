import 'package:flutter/material.dart';


class ThemeService {

  ThemeService._();


  // ========================================
  // THEME TOAN APP
  // ========================================

  static final ValueNotifier<ThemeMode>
  themeMode =
  ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );


  // ========================================
  // CURRENT KEY
  //
  // light
  // dark
  // system
  // ========================================

  static String get currentKey {

    switch (
    themeMode.value
    ) {

      case ThemeMode.light:
        return 'light';

      case ThemeMode.dark:
        return 'dark';

      case ThemeMode.system:
        return 'system';
    }
  }


  // ========================================
  // SET THEME
  // ========================================

  static void setFromKey(
      String value,
      ) {

    switch (value) {

      case 'light':

        themeMode.value =
            ThemeMode.light;

        break;


      case 'dark':

        themeMode.value =
            ThemeMode.dark;

        break;


      case 'system':

      default:

        themeMode.value =
            ThemeMode.system;

        break;
    }
  }
}