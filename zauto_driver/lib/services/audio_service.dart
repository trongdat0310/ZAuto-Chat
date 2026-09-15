import 'package:audioplayers/audioplayers.dart';


class AudioService {

  AudioService._();


  static final AudioService instance =
  AudioService._();


  final AudioPlayer player =
  AudioPlayer();



  Future<void> playTripSound() async {

    await player.stop();


    await player.play(

      AssetSource(
        'sounds/trip_alert.mp3',
      ),

    );

  }


  Future<void> dispose() async {

    await player.dispose();

  }
}