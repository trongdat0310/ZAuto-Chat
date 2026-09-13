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


  const AppSettings({

    this.themeMode =
        AppThemeMode.system,


    this.chatFontSize =
    15,


    this.tripDisplaySeconds =
    30,


    this.acceptButtonPosition =
    'bottom',
  });


  AppSettings copyWith({

    AppThemeMode? themeMode,

    double? chatFontSize,

    int? tripDisplaySeconds,

    String? acceptButtonPosition,

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

    );
  }
}