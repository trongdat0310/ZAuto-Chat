import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/backend_service.dart';

class ChatRealtimeController {
  final BackendService backend;

  final String groupId;

  // ========================================
  // CALLBACKS VE CHATP PAGE
  // ========================================

  final void Function(bool force) onReloadRequested;

  final VoidCallback onMarkReadRequested;

  final void Function(Map<String, dynamic> message) onMessage;

  StreamSubscription<Map<String, dynamic>>? _subscription;

  ChatRealtimeController({
    required this.backend,
    required this.groupId,
    required this.onReloadRequested,
    required this.onMarkReadRequested,
    required this.onMessage,
  });

  // ========================================
  // START REALTIME
  // ========================================

  void start() {
    final previous = _subscription;

    _subscription = null;

    if (previous != null) {
      unawaited(previous.cancel());
    }

    _subscription = backend.connectRealtime().listen(
      _handleEvent,

      onError: (Object error) {
        debugPrint('CHAT REALTIME ERROR: $error');
      },
    );
  }

  // ========================================
  // HANDLE EVENT
  // ========================================

  void _handleEvent(Map<String, dynamic> event) {
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

      onReloadRequested(true);

      onMarkReadRequested();

      return;
    }

    // ========================================
    // BACKEND VUA SYNC HISTORY
    // ========================================

    if (type == 'conversation_history_synced') {
      final rawSyncData = event['data'];

      if (rawSyncData is Map) {
        final syncData = Map<String, dynamic>.from(rawSyncData);

        final syncGroupId = syncData['groupId']?.toString();

        // ========================================
        // CHI RELOAD NEU LA GROUP DANG MO
        // ========================================

        if (syncGroupId == groupId) {
          debugPrint(
            'CHAT HISTORY SYNCED: '
            'group=$syncGroupId '
            'count=${syncData['count']}',
          );

          onReloadRequested(true);
        }
      }

      // ========================================
      // GIU NGUYEN HANH VI CU CUA CHATP PAGE:
      // history synced -> schedule mark read.
      // ========================================

      onMarkReadRequested();

      return;
    }

    // ========================================
    // AUTH ERROR
    // ========================================

    if (type == 'auth_error') {
      debugPrint('CHAT REALTIME AUTH ERROR');

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

    final eventGroupId = data['groupId']?.toString();

    // ========================================
    // CHI MESSAGE CUA GROUP DANG MO
    // ========================================

    if (eventGroupId != groupId) {
      return;
    }

    final rawMessage = data['message'];

    // ========================================
    // EVENT KHONG CO MESSAGE DAY DU
    //
    // FALLBACK REST RELOAD NHU CODE CU.
    // ========================================

    if (rawMessage is! Map) {
      onReloadRequested(false);

      return;
    }

    final incoming = Map<String, dynamic>.from(rawMessage);

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
    final subscription = _subscription;

    _subscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
