import 'package:flutter_tts/flutter_tts.dart';


class SpeechService {

  SpeechService._();


  static final SpeechService instance =
  SpeechService._();


  final FlutterTts tts =
  FlutterTts();


  Future<void> initialize() async {

    await tts.setLanguage(
      'vi-VN',
    );


    await tts.setVolume(
      1.0,
    );


    await tts.setPitch(
      1.0,
    );
  }


  Future<void> speak(
      String text, {
        double rate = 0.45,
      }) async {


    if (text.trim().isEmpty) {
      return;
    }


    await tts.stop();


    await tts.setSpeechRate(
      rate,
    );


    await tts.speak(
      text,
    );
  }
}