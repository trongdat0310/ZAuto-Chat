import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

import '../auth_service.dart';

class RealtimeApi {
  final AuthService auth;

  final String webSocketUrl;

  WebSocketChannel? _channel;

  int _realtimeGeneration = 0;

  bool _manualRealtimeDisconnect = false;

  Timer? _reconnectTimer;

  RealtimeApi({required this.auth, required this.webSocketUrl});

  Stream<Map<String, dynamic>> connectRealtime() async* {
    // ========================================
    // MO MOT PHIEN REALTIME MOI
    //
    // Neu connectRealtime() duoc goi lai,
    // loop cu se tu dung.
    // ========================================

    final generation = ++_realtimeGeneration;

    _manualRealtimeDisconnect = false;

    // Dong socket cu neu co.
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Khong can lam gi.
    }

    int reconnectAttempt = 0;

    while (!_manualRealtimeDisconnect && generation == _realtimeGeneration) {
      WebSocketChannel? channel;

      try {
        reconnectAttempt += 1;

        debugPrint(
          'REALTIME CONNECT ATTEMPT '
          '#$reconnectAttempt',
        );

        // ========================================
        // DOC TOKEN MOI MOI LAN RECONNECT
        // ========================================

        final token = await auth.getToken();

        if (token == null || token.isEmpty) {
          throw Exception('Chưa đăng nhập');
        }

        debugPrint('REALTIME CONNECTING...');

        channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));

        _channel = channel;

        // ========================================
        // DOI HANDSHAKE
        // ========================================

        await channel.ready.timeout(
          const Duration(seconds: 5),

          onTimeout: () {
            throw Exception('WebSocket handshake timeout');
          },
        );

        if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
          try {
            channel.sink.close();
          } catch (_) {
            // Ignore.
          }

          return;
        }

        debugPrint('REALTIME CONNECTED');

        reconnectAttempt = 0;

        // ========================================
        // AUTH JWT
        // ========================================

        channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));

        // ========================================
        // DOC EVENT CHO DEN KHI SOCKET BI DONG
        // ========================================

        await for (final rawEvent in channel.stream) {
          if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
            return;
          }

          try {
            final decoded = jsonDecode(rawEvent.toString());

            if (decoded is Map) {
              yield Map<String, dynamic>.from(decoded);
            }
          } catch (error) {
            debugPrint(
              'WebSocket decode error: '
              '$error',
            );
          }
        }

        // ========================================
        // STREAM KET THUC
        //
        // VD:
        // - npm start bi tat
        // - backend restart
        // - mang bi mat
        //
        // KHONG RETURN.
        // XUONG DUOI DE RECONNECT.
        // ========================================

        debugPrint('REALTIME DISCONNECTED');
      } catch (error) {
        debugPrint(
          'REALTIME CONNECTION ERROR: '
          '$error',
        );

        debugPrint(
          'REALTIME WILL RETRY '
          '#$reconnectAttempt',
        );
      } finally {
        if (identical(_channel, channel)) {
          _channel = null;
        }

        // ========================================
        // KHONG await close O DAY.
        //
        // Neu handshake dang timeout,
        // await sink.close() co the lai bi treo
        // va chan vong reconnect.
        // ========================================

        try {
          channel?.sink.close();
        } catch (_) {
          // Ignore.
        }
      }

      // ========================================
      // NEU USER TU DONG disconnect()
      // THI KHONG RECONNECT.
      // ========================================

      if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
        return;
      }

      // ========================================
      // DOI 2 GIAY ROI KET NOI LAI
      //
      // Backend dang tat:
      // 2s sau thu lai.
      // ========================================

      debugPrint(
        'REALTIME RECONNECT IN 2s... '
        'nextAttempt=${reconnectAttempt + 1}',
      );

      await _waitBeforeReconnect();
    }
  }

  void disconnect() {
    _manualRealtimeDisconnect = true;

    _realtimeGeneration += 1;

    _reconnectTimer?.cancel();

    _reconnectTimer = null;

    final channel = _channel;

    _channel = null;

    try {
      channel?.sink.close();
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> _waitBeforeReconnect() async {
    final completer = Completer<void>();

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
  }
}
