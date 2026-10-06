import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth_service.dart';

class RealtimeApi {
  final AuthService auth;

  final String webSocketUrl;

  WebSocketChannel? _channel;

  int _realtimeGeneration = 0;

  bool _manualRealtimeDisconnect = false;

  Timer? _reconnectTimer;

  Completer<void>? _reconnectCompleter;

  RealtimeApi({required this.auth, required this.webSocketUrl});

  // ========================================
  // CONNECT REALTIME
  // ========================================

  Stream<Map<String, dynamic>> connectRealtime() async* {
    // ========================================
    // MO MOT PHIEN REALTIME MOI
    //
    // Neu connectRealtime() duoc goi lai,
    // generation cu se tu dung.
    // ========================================

    final generation = ++_realtimeGeneration;

    _manualRealtimeDisconnect = false;

    // ========================================
    // DANH THUC RECONNECT WAIT CUA
    // PHIEN CU NEU DANG CHO.
    // ========================================

    _cancelReconnectWait();

    // ========================================
    // DONG SOCKET CU NHUNG KHONG CHO DOI.
    //
    // Socket loi / mang mat khong duoc
    // chan phien realtime moi.
    // ========================================

    final previousChannel = _channel;

    _channel = null;

    _closeChannel(previousChannel);

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
        // LUON DOC TOKEN MOI KHI CONNECT LAI
        // ========================================

        final token = await auth.getToken();

        // ========================================
        // CO THE disconnect() DA XAY RA
        // TRONG KHI DANG await TOKEN.
        // ========================================

        if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
          return;
        }

        if (token == null || token.isEmpty) {
          yield <String, dynamic>{
            'type': 'auth_error',
            'data': <String, dynamic>{'message': 'Chưa đăng nhập'},
          };

          return;
        }

        debugPrint('REALTIME CONNECTING...');

        channel = WebSocketChannel.connect(Uri.parse(webSocketUrl));

        _channel = channel;

        // ========================================
        // DOI WEBSOCKET HANDSHAKE
        // ========================================

        await channel.ready.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw Exception('WebSocket handshake timeout');
          },
        );

        // ========================================
        // TRONG LUC HANDSHAKE CO THE
        // USER DA DONG CHAT.
        // ========================================

        if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
          _closeChannel(channel);

          return;
        }

        debugPrint('REALTIME CONNECTED');

        reconnectAttempt = 0;

        // ========================================
        // AUTH JWT
        // ========================================

        channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));

        // ========================================
        // DOC EVENT CHO DEN KHI SOCKET DONG
        // ========================================

        await for (final rawEvent in channel.stream) {
          if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
            return;
          }

          try {
            final decoded = jsonDecode(rawEvent.toString());

            if (decoded is! Map) {
              continue;
            }

            final event = Map<String, dynamic>.from(decoded);

            final type = event['type']?.toString().trim();

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

                    'flutterSocketDecodedAtMs':
                        DateTime.now()
                            .millisecondsSinceEpoch,
                  };

                  event['data'] =
                      data;
                }
              }
            }

            // ========================================
            // GUI EVENT VE UI TRUOC.
            // ========================================

            yield event;

            // ========================================
            // AUTH ERROR LA LOI TERMINAL.
            //
            // Backend da xac nhan JWT:
            // - sai
            // - het han
            // - revoked
            // - user khong con ton tai
            //
            // KHONG reconnect bang cung token.
            // ========================================

            if (type == 'auth_error') {
              debugPrint(
                'REALTIME AUTH FAILED '
                '-> stop reconnect',
              );

              await auth.invalidateSession();

              return;
            }
          } catch (error) {
            debugPrint(
              'WebSocket decode error: '
              '$error',
            );
          }
        }

        if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
          return;
        }

        debugPrint('REALTIME DISCONNECTED');

        // ========================================
        // GUI CAN BIET SOCKET DA MAT
        // DE KHONG HIEN "DANG LANG NGHE" SAI.
        // ========================================

        yield <String, dynamic>{
          'type': 'realtime_disconnected',

          'data': <String, dynamic>{'reason': 'socket_closed'},
        };
      } catch (error) {
        if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
          return;
        }

        debugPrint(
          'REALTIME CONNECTION ERROR: '
          '$error',
        );

        // ========================================
        // BAO CHO UI:
        // BACKEND / SOCKET DANG MAT.
        //
        // RealtimeApi VAN TU RECONNECT,
        // DAY KHONG PHAI STREAM ERROR.
        // ========================================

        yield <String, dynamic>{
          'type': 'realtime_disconnected',

          'data': <String, dynamic>{'reason': 'connection_error'},
        };

        debugPrint(
          'REALTIME WILL RETRY '
          '#$reconnectAttempt',
        );
      } finally {
        if (identical(_channel, channel)) {
          _channel = null;
        }

        _closeChannel(channel);
      }

      // ========================================
      // USER DA disconnect()
      // HOAC DA CO PHIEN REALTIME MOI.
      // ========================================

      if (_manualRealtimeDisconnect || generation != _realtimeGeneration) {
        return;
      }

      debugPrint(
        'REALTIME RECONNECT IN 2s... '
        'nextAttempt=${reconnectAttempt + 1}',
      );

      await _waitBeforeReconnect();
    }
  }

  // ========================================
  // DISCONNECT
  // ========================================

  void disconnect() {
    _manualRealtimeDisconnect = true;

    // ========================================
    // INVALIDATE TAT CA PHIEN CU
    // ========================================

    _realtimeGeneration += 1;

    // ========================================
    // NEU DANG CHO RECONNECT:
    //
    // CANCEL TIMER + COMPLETE FUTURE
    // DE async generator KHONG BI TREO.
    // ========================================

    _cancelReconnectWait();

    final channel = _channel;

    _channel = null;

    _closeChannel(channel);
  }

  // ========================================
  // WAIT BEFORE RECONNECT
  // ========================================

  Future<void> _waitBeforeReconnect() {
    // Chi cho phep mot reconnect wait
    // ton tai tai mot thoi diem.
    _cancelReconnectWait();

    final completer = Completer<void>();

    _reconnectCompleter = completer;

    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (identical(_reconnectCompleter, completer)) {
        _reconnectTimer = null;

        _reconnectCompleter = null;
      }

      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    return completer.future;
  }

  // ========================================
  // CANCEL RECONNECT WAIT
  // ========================================

  void _cancelReconnectWait() {
    _reconnectTimer?.cancel();

    _reconnectTimer = null;

    final completer = _reconnectCompleter;

    _reconnectCompleter = null;

    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  // ========================================
  // SAFE CLOSE CHANNEL
  // ========================================

  void _closeChannel(WebSocketChannel? channel) {
    if (channel == null) {
      return;
    }

    try {
      unawaited(channel.sink.close());
    } catch (_) {
      // Socket da dong hoac dang loi.
    }
  }
}
