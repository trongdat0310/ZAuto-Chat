enum AppThemeMode {
  system,
  light,
  dark,
}


class AppSettings {

  final AppThemeMode themeMode;


  final double chatFontSize;


  final int tripDisplaySeconds;


  final String acceptButtonPosition;

  final String acceptReplyText;


  const AppSettings({

    this.themeMode =
        AppThemeMode.system,


    this.chatFontSize =
    15,


    this.tripDisplaySeconds =
    30,


    this.acceptButtonPosition =
    'bottom',

    this.acceptReplyText =
    'ok',
  });


  AppSettings copyWith({

    AppThemeMode? themeMode,

    double? chatFontSize,

    int? tripDisplaySeconds,

    String? acceptButtonPosition,

    String? acceptReplyText,

  }) {

    return AppSettings(

      themeMode:
      themeMode ??
          this.themeMode,


      chatFontSize:
      chatFontSize ??
          this.chatFontSize,


      tripDisplaySeconds:
      tripDisplaySeconds ??
          this.tripDisplaySeconds,


      acceptButtonPosition:
      acceptButtonPosition ??
          this.acceptButtonPosition,

      acceptReplyText:
      acceptReplyText ??
          this.acceptReplyText,

    );
  }
}