import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend_service.dart';

class AppRealtimeService {
  final BackendService _backend;

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool _started = false;

  bool _disposed = false;

  AppRealtimeService({required String baseUrl})
    : _backend = BackendService(baseUrl: baseUrl);

  // ========================================
  // PUBLIC EVENT STREAM
  //
  // HOME / MESSAGES / CHAT deu subscribe
  // vao cung stream nay.
  // ========================================

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  bool get isStarted => _started && !_disposed;

  // ========================================
  // START
  // ========================================

  void start() {
    if (_disposed || _started) {
      return;
    }

    _started = true;

    debugPrint('APP REALTIME START');

    _subscription = _backend.connectRealtime().listen(
      (event) {
        if (_disposed) {
          return;
        }

        _eventController.add(event);
      },

      onError: (Object error, StackTrace stackTrace) {
        if (_disposed) {
          return;
        }

        debugPrint(
          'APP REALTIME ERROR: '
          '$error',
        );

        _eventController.addError(error, stackTrace);
      },

      onDone: () {
        if (_disposed) {
          return;
        }

        _subscription = null;

        _started = false;

        debugPrint('APP REALTIME SOURCE DONE');
      },
    );
  }

  // ========================================
  // STOP
  //
  // Dung khi user unlink Zalo.
  // Service van co the start lai.
  // ========================================

  void stop() {
    if (_disposed) {
      return;
    }

    _started = false;

    final subscription = _subscription;

    _subscription = null;

    _backend.disconnect();

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    debugPrint('APP REALTIME STOP');
  }

  // ========================================
  // DISPOSE
  // ========================================

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _started = false;

    final subscription = _subscription;

    _subscription = null;

    _backend.disconnect();

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    unawaited(_eventController.close());
  }
}
