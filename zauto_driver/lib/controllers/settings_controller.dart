import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';


class SettingsController
    extends ChangeNotifier {


  final SettingsService service =
  SettingsService();


  AppSettings _settings =
  const AppSettings();


  AppSettings get settings =>
      _settings;



  Future<void> load() async {

    _settings =
    await service.load();


    ThemeService
        .setFromKey(
      _settings
          .themeMode
          .name,
    );


    notifyListeners();
  }



  Future<void> updateTheme(
      String value,
      ) async {


    final mode =
    switch(value) {

      'light' =>
      AppThemeMode.light,

      'dark' =>
      AppThemeMode.dark,

      _ =>
      AppThemeMode.system,
    };


    _settings =
        _settings.copyWith(
          themeMode:
          mode,
        );

    notifyListeners();

    ThemeService
        .setFromKey(
      value,
    );


    await save();
  }



  Future<void> updateFontSize(
      double value,
      ) async {


    _settings =
        _settings.copyWith(
          chatFontSize:
          value,
        );


    notifyListeners();


    await save();
  }



  Future<void> updateTripDisplaySeconds(
      int value,
      ) async {


    _settings =
        _settings.copyWith(
          tripDisplaySeconds:
          value,
        );


    notifyListeners();


    await save();
  }



  Future<void> updateAcceptButtonPosition(
      String value,
      ) async {


    _settings =
        _settings.copyWith(
          acceptButtonPosition:
          value,
        );


    notifyListeners();


    await save();
  }



  Future<void> save() async {

    await service.save(
      _settings,
    );
  }
}