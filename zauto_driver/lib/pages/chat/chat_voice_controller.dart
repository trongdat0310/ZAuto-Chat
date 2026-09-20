import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class ChatVoiceController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  String? _playingUrl;

  Duration _position = Duration.zero;

  Duration _duration = Duration.zero;

  StreamSubscription<Duration>? _positionSubscription;

  StreamSubscription<Duration>? _durationSubscription;

  StreamSubscription<void>? _completeSubscription;

  bool _disposed = false;

  ChatVoiceController() {
    _setupPlayer();
  }

  // ========================================
  // STATE
  // ========================================

  String? get playingUrl => _playingUrl;

  Duration get position => _position;

  Duration get duration => _duration;

  bool get isPlaying => _player.state == PlayerState.playing;

  // ========================================
  // SETUP PLAYER
  // ========================================

  void _setupPlayer() {
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (_disposed) {
        return;
      }

      _position = position;

      notifyListeners();
    });

    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (_disposed) {
        return;
      }

      _duration = duration;

      notifyListeners();
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (_disposed) {
        return;
      }

      _playingUrl = null;

      _position = Duration.zero;

      notifyListeners();
    });
  }

  // ========================================
  // TOGGLE VOICE
  // ========================================

  Future<void> toggle(String url) async {
    final trimmedUrl = url.trim();

    if (trimmedUrl.isEmpty) {
      return;
    }

    // ========================================
    // DANG CHON CHINH VOICE NAY
    // ========================================

    if (_playingUrl == trimmedUrl) {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }

      if (_disposed) {
        return;
      }

      notifyListeners();

      return;
    }

    // ========================================
    // CHUYEN SANG VOICE KHAC
    // ========================================

    await _player.stop();

    if (_disposed) {
      return;
    }

    _playingUrl = trimmedUrl;

    _position = Duration.zero;

    _duration = Duration.zero;

    notifyListeners();

    await _player.play(UrlSource(trimmedUrl));

    if (_disposed) {
      return;
    }

    notifyListeners();
  }

  // ========================================
  // HELPERS
  // ========================================

  bool isCurrent(String url) {
    return _playingUrl == url.trim();
  }

  bool isVoicePlaying(String url) {
    return isCurrent(url) && _player.state == PlayerState.playing;
  }

  // ========================================
  // DISPOSE
  // ========================================

  @override
  void dispose() {
    _disposed = true;

    final positionSubscription = _positionSubscription;

    final durationSubscription = _durationSubscription;

    final completeSubscription = _completeSubscription;

    _positionSubscription = null;

    _durationSubscription = null;

    _completeSubscription = null;

    if (positionSubscription != null) {
      unawaited(positionSubscription.cancel());
    }

    if (durationSubscription != null) {
      unawaited(durationSubscription.cancel());
    }

    if (completeSubscription != null) {
      unawaited(completeSubscription.cancel());
    }

    unawaited(_player.dispose());

    super.dispose();
  }
}
