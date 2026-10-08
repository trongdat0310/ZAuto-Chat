import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';


class SettingsController
    extends ChangeNotifier {


  final SettingsService service =
  SettingsService();


  final ValueNotifier<double>
      notificationFontSize =
      ValueNotifier<double>(15);


  AppSettings _settings =
  const AppSettings();


  AppSettings get settings =>
      _settings;



  Future<void> load() async {

    _settings =
    await service.load();


    notificationFontSize.value =
        _settings.chatFontSize;


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



  void previewFontSize(
      double value,
      ) {


    if (
      _settings.chatFontSize ==
      value
    ) {
      return;
    }


    _settings =
        _settings.copyWith(
          chatFontSize:
          value,
        );


    notificationFontSize.value =
        value;
  }



  Future<void> updateFontSize(
      double value,
      ) async {


    _settings =
        _settings.copyWith(
          chatFontSize:
          value,
        );


    notificationFontSize.value =
        value;


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

  Future<void> updateAcceptReplyText(
      String value,
      ) async {

    _settings =
        _settings.copyWith(
          acceptReplyText:
          value,
        );

    notifyListeners();

    await save();
  }

  Future<void> updateQuickTapAccept(bool value) async {
    _settings = _settings.copyWith(quickTapAccept: value);
    notifyListeners();
    await save();
  }
  Future<void> updateSwipeToReply(bool value) async {
    _settings = _settings.copyWith(swipeToReply: value);
    notifyListeners();
    await save();
  }
  Future<void> updatePlayTripSound(
      bool value,
      ) async {

    _settings =
        _settings.copyWith(
          playTripSound:
          value,
        );

    notifyListeners();

    await save();
  }

  Future<void> updateReadTripNotification(
      bool value,
      ) async {

    _settings =
        _settings.copyWith(
          readTripNotification:
          value,
        );

    notifyListeners();

    await save();
  }

  Future<void> updateSpeechRate(
      double value,
      ) async {

    _settings =
        _settings.copyWith(
          speechRate:
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