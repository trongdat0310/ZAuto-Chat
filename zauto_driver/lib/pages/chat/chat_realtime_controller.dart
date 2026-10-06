import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_realtime_service.dart';

class ChatRealtimeController {
  final AppRealtimeService realtimeService;

  final String groupId;

  // ========================================
  // CALLBACKS VE CHATP PAGE
  // ========================================

  final void Function(bool force) onReloadRequested;

  final VoidCallback onMarkReadRequested;

  final void Function(Map<String, dynamic> message) onMessage;

  final VoidCallback onConnected;

  final VoidCallback onDisconnected;

  final VoidCallback onAuthError;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool _disposed = false;

  bool _started = false;

  ChatRealtimeController({
    required this.realtimeService,
    required this.groupId,
    required this.onReloadRequested,
    required this.onMarkReadRequested,
    required this.onMessage,
    required this.onConnected,
    required this.onDisconnected,
    required this.onAuthError,
  });

  // ========================================
  // START REALTIME
  // ========================================

  void start() {
    if (_disposed || _started) {
      return;
    }

    _started = true;

    _subscription = realtimeService.events.listen(
      _handleEvent,

      onError: (Object error) {
        if (_disposed) {
          return;
        }

        debugPrint('CHAT REALTIME ERROR: $error');
      },

      onDone: () {
        if (_disposed) {
          return;
        }

        _subscription = null;
        _started = false;

        debugPrint('CHAT REALTIME STREAM DONE');
      },
    );
  }

  bool _isCurrentGroup(dynamic value) {
    final eventGroupId = value?.toString().trim() ?? '';

    final currentGroupId = groupId.trim();

    if (eventGroupId.isEmpty || currentGroupId.isEmpty) {
      return false;
    }

    return eventGroupId == currentGroupId;
  }

  // ========================================
  // HANDLE EVENT
  // ========================================

  void _handleEvent(Map<String, dynamic> event) {
    if (_disposed) {
      return;
    }

    final type = event['type']?.toString();

    // ========================================
    // BACKEND YEU CAU AUTH
    // ========================================

    if (type == 'auth_required') {
      return;
    }

    // ========================================
    // AUTHENTICATED / RECONNECTED
    //
    // LAY LAI LATEST MESSAGE
    // DE KHONG BO SOT MESSAGE.
    // ========================================

    if (type == 'authenticated') {
      debugPrint(
        'CHAT REALTIME AUTHENTICATED '
        '-> reload latest messages',
      );

      onConnected();

      onReloadRequested(true);

      onMarkReadRequested();

      return;
    }

    // ========================================
    // BACKEND VUA SYNC HISTORY
    // ========================================

    if (type == 'conversation_history_synced') {
      final rawSyncData = event['data'];

      if (rawSyncData is! Map) {
        return;
      }

      final syncData = Map<String, dynamic>.from(rawSyncData);

      final syncGroupId = syncData['groupId']?.toString().trim();

      // ========================================
      // EVENT HISTORY CUA GROUP KHAC
      //
      // KHONG:
      // - reload group dang mo
      // - mark read group dang mo
      // ========================================

      if (!_isCurrentGroup(syncGroupId)) {
        return;
      }

      debugPrint(
        'CHAT HISTORY SYNCED: '
        'group=$syncGroupId '
        'count=${syncData['count']}',
      );

      // ========================================
      // CHI GROUP DANG MO MOI DUOC RELOAD
      // VA MARK READ.
      // ========================================

      onReloadRequested(true);

      onMarkReadRequested();

      return;
    }

    // ========================================
    // AUTH ERROR
    // ========================================

    if (type == 'auth_error') {
      debugPrint('CHAT REALTIME AUTH ERROR');

      onAuthError();

      return;
    }

    if (type == 'realtime_disconnected') {
      onDisconnected();

      return;
    }

    // ========================================
    // CHI NHAN MESSAGE EVENT
    // ========================================

    if (type != 'conversation_message' &&
        type != 'conversation_message_updated') {
      return;
    }

    final rawData = event['data'];

    if (rawData is! Map) {
      return;
    }

    final data = Map<String, dynamic>.from(rawData);

    final eventGroupId = data['groupId']?.toString().trim();

    if (!_isCurrentGroup(eventGroupId)) {
      return;
    }

    final rawMessage = data['message'];

    // ========================================
    // EVENT KHONG CO MESSAGE DAY DU
    //
    // FALLBACK REST RELOAD NHU CODE CU.
    // ========================================

    if (rawMessage is! Map) {
      // Receiving a valid realtime event proves the shared stream
      // is alive even if a previous disconnected event was stale.
      onConnected();

      onReloadRequested(false);

      return;
    }

    final incoming = Map<String, dynamic>.from(rawMessage);

    // A message delivered by the realtime stream is a stronger health
    // signal than an older disconnected event. Clear stale reconnect UI.
    onConnected();

    // ========================================
    // DAY MESSAGE VE CHATP PAGE
    // ========================================

    onMessage(incoming);

    // ========================================
    // MESSAGE MOI CUA NGUOI KHAC
    // KHI CHAT DANG MO
    // -> MARK READ
    //
    // UPDATED EVENT KHONG CHAY BLOCK NAY,
    // DUNG NHU CODE CU.
    // ========================================

    if (type == 'conversation_message' && incoming['isSelf'] != true) {
      onMarkReadRequested();
    }
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

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
