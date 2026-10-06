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

  int _sourceGeneration = 0;

  bool _connected = false;

  bool _authFailed = false;

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

  bool get isConnected => _connected && !_disposed;

  bool get hasAuthFailed => _authFailed && !_disposed;

  // ========================================
  // START
  // ========================================

  void start() {
    if (_disposed || _started) {
      return;
    }

    _started = true;

    final generation = ++_sourceGeneration;

    debugPrint('APP REALTIME START');

    _subscription = _backend.connectRealtime().listen(
      (event) {
        if (_disposed || generation != _sourceGeneration) {
          return;
        }

        final type =
            event['type']?.toString();

        if (type == 'authenticated') {
          _connected = true;

          _authFailed = false;
        } else if (type == 'realtime_disconnected') {
          _connected = false;
        } else if (type == 'auth_error') {
          _connected = false;

          _authFailed = true;
        }

        if (
          type == 'new_trip'
        ) {
          final rawData =
              event['data'];

          if (rawData is Map) {
            final data =
                Map<String, dynamic>.from(
              rawData,
            );

            final rawTrace =
                data['_latencyTrace'];

            if (rawTrace is Map) {
              data['_latencyTrace'] =
                  <String, dynamic>{
                ...Map<String, dynamic>.from(
                  rawTrace,
                ),

                'flutterAppRealtimeAtMs':
                    DateTime.now()
                        .millisecondsSinceEpoch,
              };

              event['data'] =
                  data;
            }
          }
        }

        _eventController.add(event);
      },

      onError: (Object error, StackTrace stackTrace) {
        if (_disposed || generation != _sourceGeneration) {
          return;
        }

        debugPrint(
          'APP REALTIME ERROR: '
          '$error',
        );

        _eventController.addError(error, stackTrace);
      },

      onDone: () {
        if (_disposed || generation != _sourceGeneration) {
          return;
        }

        _subscription = null;

        _started = false;

        _connected = false;

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

    _connected = false;

    _authFailed = false;

    _sourceGeneration += 1;

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

    _connected = false;

    _authFailed = false;

    _sourceGeneration += 1;

    final subscription = _subscription;

    _subscription = null;

    _backend.disconnect();

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    unawaited(_eventController.close());
  }
}
