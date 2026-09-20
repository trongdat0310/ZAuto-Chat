import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../services/backend_service.dart';

class ChatMarkReadController with WidgetsBindingObserver {
  final BackendService backend;

  final String groupId;

  Timer? _markReadTimer;

  bool _markReadInFlight = false;

  bool _markReadPending = false;

  bool _appIsActive = true;

  bool _started = false;

  bool _disposed = false;

  ChatMarkReadController({required this.backend, required this.groupId});

  // ========================================
  // START
  // ========================================

  void start() {
    if (_started || _disposed) {
      return;
    }

    _started = true;

    WidgetsBinding.instance.addObserver(this);

    final lifecycleState = WidgetsBinding.instance.lifecycleState;

    // ========================================
    // GIU NGUYEN HANH VI CU
    //
    // lifecycleState == null
    // -> coi app dang active.
    // ========================================

    _appIsActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  // ========================================
  // SCHEDULE MARK READ
  //
  // Debounce de album / realtime lien tuc
  // khong tao qua nhieu request.
  // ========================================

  void schedule({bool immediate = false}) {
    if (_disposed || !_appIsActive) {
      return;
    }

    _markReadTimer?.cancel();

    if (immediate) {
      unawaited(_markNow());

      return;
    }

    _markReadTimer = Timer(const Duration(milliseconds: 250), () {
      if (_disposed || !_appIsActive) {
        return;
      }

      unawaited(_markNow());
    });
  }

  // ========================================
  // MARK READ NOW
  // ========================================

  Future<void> _markNow() async {
    if (_disposed || !_appIsActive) {
      return;
    }

    // ========================================
    // REQUEST CU DANG CHAY
    //
    // GHI NHO DE CHAY THEM MOT LAN.
    // ========================================

    if (_markReadInFlight) {
      _markReadPending = true;

      return;
    }

    _markReadInFlight = true;

    try {
      await backend.markConversationRead(groupId: groupId);

      if (_disposed) {
        return;
      }

      debugPrint('CHAT MARK READ: $groupId');
    } catch (error) {
      if (_disposed) {
        return;
      }

      // ========================================
      // MARK READ LOI KHONG DUOC
      // LAM HONG CHAT.
      // ========================================

      debugPrint('CHAT MARK READ ERROR: $error');
    } finally {
      _markReadInFlight = false;

      // ========================================
      // TRONG LUC REQUEST DANG CHAY
      // CO YEU CAU MARK READ KHAC.
      //
      // KHONG DUNG return TRONG finally.
      // ========================================

      if (!_disposed && _markReadPending) {
        _markReadPending = false;

        schedule();
      }
    }
  }

  // ========================================
  // APP LIFECYCLE
  // ========================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }

    final wasActive = _appIsActive;

    _appIsActive = state == AppLifecycleState.resumed;

    // ========================================
    // APP RA BACKGROUND
    //
    // KHONG COI MESSAGE LA DA DOC.
    // ========================================

    if (!_appIsActive) {
      _markReadTimer?.cancel();

      return;
    }

    // ========================================
    // USER QUAY LAI APP
    //
    // CONVERSATION DANG MO
    // -> MARK READ NGAY.
    // ========================================

    if (!wasActive) {
      schedule(immediate: true);
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

    _markReadTimer?.cancel();

    _markReadTimer = null;

    _markReadPending = false;

    if (_started) {
      WidgetsBinding.instance.removeObserver(this);

      _started = false;
    }
  }
}
