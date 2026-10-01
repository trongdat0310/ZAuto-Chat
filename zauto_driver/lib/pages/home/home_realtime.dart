import 'dart:async';

import '../../services/app_realtime_service.dart';

class HomeRealtimeHandler {
  final AppRealtimeService realtimeService;

  final void Function() onAuthenticated;

  final void Function() onAuthError;

  final void Function(Map<String, dynamic> data) onNewTrip;

  final void Function() onConnectionError;

  final void Function() onConnectionDone;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool _started = false;

  bool _disposed = false;

  bool _authFailed = false;

  HomeRealtimeHandler({
    required this.realtimeService,
    required this.onAuthenticated,
    required this.onAuthError,
    required this.onNewTrip,
    required this.onConnectionError,
    required this.onConnectionDone,
  });

  void start() {
    if (_disposed || _started) {
      return;
    }

    _started = true;

    _subscription = realtimeService.events.listen(
      (event) {
        if (_disposed) {
          return;
        }

        final type = event['type']?.toString();

        // ========================================
        // SOCKET MAT NHUNG SERVICE VAN
        // DANG TU RECONNECT.
        // ========================================

        if (type == 'realtime_disconnected') {
          onConnectionError();

          return;
        }

        // ========================================
        // BACKEND YEU CAU AUTH
        // ========================================

        if (type == 'auth_required') {
          return;
        }

        // ========================================
        // DA XAC THUC
        // ========================================

        if (type == 'authenticated') {
          _authFailed = false;

          onAuthenticated();

          return;
        }

        // ========================================
        // AUTH THAT BAI
        // ========================================

        if (type == 'auth_error') {
          _authFailed = true;

          onAuthError();

          return;
        }

        // ========================================
        // CHI NHAN NEW TRIP
        // ========================================

        if (type != 'new_trip') {
          return;
        }

        final rawData = event['data'];

        if (rawData is! Map) {
          return;
        }

        final data = Map<String, dynamic>.from(rawData);

        onNewTrip(data);
      },

      onError: (Object error) {
        if (_disposed) {
          return;
        }

        onConnectionError();
      },

      onDone: () {
        if (_disposed) {
          return;
        }

        _subscription = null;
        _started = false;

        // ========================================
        // AUTH ERROR DA DUOC BAO RIENG.
        //
        // KHONG GHI DE:
        // "Xac thuc realtime that bai"
        // BANG:
        // "Backend da ngat ket noi".
        // ========================================

        if (_authFailed) {
          return;
        }

        onConnectionDone();
      },
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _started = false;

    final subscription = _subscription;

    _subscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
