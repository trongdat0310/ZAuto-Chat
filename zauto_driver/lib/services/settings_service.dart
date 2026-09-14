import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';


class SettingsService {


  static const _themeKey =
      'theme_mode';


  static const _fontSizeKey =
      'chat_font_size';


  static const _tripTimeKey =
      'trip_display_seconds';


  static const _buttonPositionKey =
      'accept_button_position';

  static const _acceptReplyTextKey =
      'accept_reply_text';

  Future<AppSettings>
  load() async {


    final prefs =
    await SharedPreferences
        .getInstance();



    return AppSettings(

      themeMode:
      _parseTheme(
        prefs.getString(
          _themeKey,
        ),
      ),


      chatFontSize:
      prefs.getDouble(
        _fontSizeKey,
      ) ??
          15,


      tripDisplaySeconds:
      prefs.getInt(
        _tripTimeKey,
      ) ??
          30,


      acceptButtonPosition:
      prefs.getString(
        _buttonPositionKey,
      ) ??
          'bottom',

      acceptReplyText:
      prefs.getString(
        _acceptReplyTextKey,
      ) ??
          'ok',

    );
  }



  Future<void>
  save(
      AppSettings settings,
      ) async {


    final prefs =
    await SharedPreferences
        .getInstance();



    await prefs.setString(

      _themeKey,

      settings.themeMode.name,

    );


    await prefs.setDouble(

      _fontSizeKey,

      settings.chatFontSize,

    );


    await prefs.setInt(

      _tripTimeKey,

      settings.tripDisplaySeconds,

    );



    await prefs.setString(

      _buttonPositionKey,

      settings.acceptButtonPosition,

    );


    await prefs.setString(

      _acceptReplyTextKey,

      settings.acceptReplyText,

    );

  }



  AppThemeMode
  _parseTheme(
      String? value,
      ) {


    switch(value) {


      case 'light':

        return AppThemeMode.light;


      case 'dark':

        return AppThemeMode.dark;


      default:

        return AppThemeMode.system;

    }
  }
}