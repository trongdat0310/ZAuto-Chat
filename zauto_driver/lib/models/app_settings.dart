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

  final bool playTripSound;

  final bool readTripNotification;

  final double speechRate;

  final bool transcribeVoiceMessages;


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

    this.playTripSound =
    true,

    this.readTripNotification =
    false,

    this.speechRate =
    0.45,

    this.transcribeVoiceMessages =
    false,
  });


  AppSettings copyWith({

    AppThemeMode? themeMode,

    double? chatFontSize,

    int? tripDisplaySeconds,

    String? acceptButtonPosition,

    String? acceptReplyText,

    bool? playTripSound,

    bool? readTripNotification,

    double? speechRate,

    bool? transcribeVoiceMessages,

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

      playTripSound:
      playTripSound ??
          this.playTripSound,

      readTripNotification:
      readTripNotification ??
          this.readTripNotification,

      speechRate:
      speechRate ??
          this.speechRate,

      transcribeVoiceMessages:
      transcribeVoiceMessages ??
          this.transcribeVoiceMessages,

    );
  }
}