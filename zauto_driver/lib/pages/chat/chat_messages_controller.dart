import 'dart:async';

import '../../services/backend_service.dart';

class ChatMessagesPageData {
  final List<Map<String, dynamic>> messages;

  final bool hasBefore;

  final bool hasAfter;

  final bool anchorFound;

  const ChatMessagesPageData({
    required this.messages,
    required this.hasBefore,
    required this.hasAfter,
    required this.anchorFound,
  });
}

class ChatMessagesReloadResult {
  final int latestCount;

  final int totalCount;

  final bool force;

  const ChatMessagesReloadResult({
    required this.latestCount,
    required this.totalCount,
    required this.force,
  });
}

enum ChatMessageUpsertResult { inserted, updated, skipped }

class ChatMessagesController {
  static const int pageSize = 50;

  final BackendService backend;

  final String groupId;

  Timer? _latestReloadTimer;

  bool _reloadInFlight = false;

  bool _scheduledReloadForce = false;

  bool _reloadPending = false;

  bool _reloadPendingForce = false;

  bool _disposed = false;

  ChatMessagesController({required this.backend, required this.groupId});

  // ========================================
  // MESSAGE STATE
  // ========================================

  List<Map<String, dynamic>> messages = [];

  bool loading = true;

  bool loadingOlder = false;

  bool hasMoreOlder = false;

  bool hasMoreNewer = false;

  bool paginationReady = false;

  bool get canLoadOlder {
    return paginationReady &&
        !loadingOlder &&
        hasMoreOlder &&
        messages.isNotEmpty;
  }

  // ========================================
  // RESET
  // ========================================

  void reset() {
    _latestReloadTimer?.cancel();

    _latestReloadTimer = null;

    _scheduledReloadForce = false;

    _reloadPending = false;

    _reloadPendingForce = false;

    messages = [];

    loading = true;

    loadingOlder = false;

    hasMoreOlder = false;

    hasMoreNewer = false;

    paginationReady = false;
  }

  // ========================================
  // FETCH LATEST PAGE
  // ========================================

  Future<ChatMessagesPageData> fetchLatestPage({int limit = pageSize}) async {
    return _fetchPage(limit: limit);
  }

  // ========================================
  // SCHEDULE LATEST RELOAD
  //
  // DUNG CHO:
  // - REALTIME RECONNECT
  // - HISTORY SYNCED
  // - FALLBACK SAU GUI ANH
  // ========================================

  void scheduleLatestReload({
    bool force = false,
    required void Function(ChatMessagesReloadResult result) onApplied,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    if (_disposed) {
      return;
    }

    // ========================================
    // DANG CO REQUEST CHAY
    //
    // KHONG BO MAT REQUEST MOI.
    // GHI NHO DE CHAY LAI SAU.
    // ========================================

    if (_reloadInFlight) {
      _reloadPending = true;

      _reloadPendingForce = _reloadPendingForce || force;

      return;
    }

    // ========================================
    // NHIEU EVENT DEN TRONG 250ms:
    //
    // force=true CO DO UU TIEN CAO HON.
    // ========================================

    _scheduledReloadForce = _scheduledReloadForce || force;

    _latestReloadTimer?.cancel();

    _latestReloadTimer = Timer(const Duration(milliseconds: 250), () async {
      _latestReloadTimer = null;

      if (_disposed) {
        return;
      }

      // ========================================
      // CO REQUEST KHAC VUA BAT DAU
      // TRUOC TIMER NAY.
      // ========================================

      if (_reloadInFlight) {
        _reloadPending = true;

        _reloadPendingForce = _reloadPendingForce || _scheduledReloadForce;

        _scheduledReloadForce = false;

        return;
      }

      final effectiveForce = _scheduledReloadForce;

      _scheduledReloadForce = false;

      // ========================================
      // DANG O HISTORY CO KHOANG NEWER.
      //
      // NORMAL realtime reload KHONG DUOC
      // TU Y NHAY VE LATEST.
      // ========================================

      if (hasMoreNewer && !effectiveForce) {
        return;
      }

      _reloadInFlight = true;

      try {
        int latestCount;

        // ========================================
        // FORCE:
        // reconnect / history synced /
        // photo fallback
        //
        // -> catch-up bang afterId.
        // ========================================

        if (effectiveForce) {
          latestCount = await catchUpNewerMessages();
        } else {
          final page = await fetchLatestPage();

          if (_disposed) {
            return;
          }

          mergeLatest(page.messages, force: false);

          latestCount = page.messages.length;
        }

        if (_disposed) {
          return;
        }

        onApplied(
          ChatMessagesReloadResult(
            latestCount: latestCount,
            totalCount: messages.length,
            force: effectiveForce,
          ),
        );
      } catch (error, stackTrace) {
        if (_disposed) {
          return;
        }

        onError?.call(error, stackTrace);
      } finally {
        _reloadInFlight = false;

        // ========================================
        // TRONG LUC REQUEST DANG CHAY
        // CO EVENT KHAC DEN.
        //
        // CHAY THEM MOT LAN.
        // ========================================

        if (!_disposed && _reloadPending) {
          final pendingForce = _reloadPendingForce;

          _reloadPending = false;

          _reloadPendingForce = false;

          scheduleLatestReload(
            force: pendingForce,
            onApplied: onApplied,
            onError: onError,
          );
        }
      }
    });
  }

  // ========================================
  // FETCH OLDER PAGE
  // ========================================

  Future<ChatMessagesPageData> fetchOlderPage({
    required String beforeId,
    int limit = pageSize,
  }) async {
    return _fetchPage(limit: limit, beforeId: beforeId);
  }

  Future<ChatMessagesPageData> fetchNewerPage({
    required String afterId,
    int limit = pageSize,
  }) async {
    return _fetchPage(limit: limit, afterId: afterId);
  }

  // ========================================
  // LOAD INITIAL CHAT
  // ========================================

  Future<void> loadInitial() async {
    beginInitialLoad();

    try {
      final page = await fetchLatestPage();

      applyInitialPage(
        loadedMessages: page.messages,
        hasBefore: page.hasBefore,
      );

      if (_disposed) {
        return;
      }
    } catch (_) {
      failInitialLoad();

      rethrow;
    }
  }

  // ========================================
  // LOAD OLDER CHO NORMAL PAGINATION
  //
  // KHONG DUNG CHO TARGET SEEK / QUOTE SEEK.
  // ========================================

  Future<int> loadOlder() async {
    if (!canLoadOlder) {
      return 0;
    }

    final beforeId = messages.first['id']?.toString();

    if (beforeId == null || beforeId.isEmpty) {
      return 0;
    }

    beginOlderLoad();

    try {
      final page = await fetchOlderPage(beforeId: beforeId);

      if (_disposed) {
        return 0;
      }

      final addedCount = prependOlderPage(
        page.messages,
        hasBefore: page.hasBefore,
      );

      return addedCount;
    } finally {
      finishOlderLoad();
    }
  }

  // ========================================
  // REST FETCH NOI BO
  // ========================================

  Future<ChatMessagesPageData> _fetchPage({
    required int limit,
    String? beforeId,
    String? afterId,
  }) async {
    final page = await backend.getConversationMessagesPage(
      groupId: groupId,
      limit: limit,
      beforeId: beforeId,
      afterId: afterId,
    );

    final loadedMessages = extractMessages(page['messages']);

    return ChatMessagesPageData(
      messages: loadedMessages,
      hasBefore: page['hasBefore'] == true,
      hasAfter: page['hasAfter'] == true,
      anchorFound: page['anchorFound'] != false,
    );
  }

  // ========================================
  // INITIAL LOAD
  // ========================================

  void beginInitialLoad() {
    paginationReady = false;

    loading = true;
  }

  void applyInitialPage({
    required List<Map<String, dynamic>> loadedMessages,
    required bool hasBefore,
  }) {
    messages = loadedMessages;

    hasMoreOlder = hasBefore;

    // ========================================
    // INITIAL PAGE LUON BAT DAU TU LATEST
    // ========================================

    hasMoreNewer = false;

    loading = false;
  }

  void failInitialLoad() {
    loading = false;

    paginationReady = true;
  }

  // ========================================
  // PAGINATION READY
  // ========================================

  void setPaginationReady(bool value) {
    paginationReady = value;
  }

  // ========================================
  // LOAD OLDER
  // ========================================

  void beginOlderLoad() {
    loadingOlder = true;

    paginationReady = false;
  }

  int prependOlderPage(
    List<Map<String, dynamic>> older, {
    required bool hasBefore,
  }) {
    final uniqueOlder = uniqueAgainst(messages, older);

    if (uniqueOlder.isNotEmpty) {
      messages = [...uniqueOlder, ...messages];
    }

    hasMoreOlder = hasBefore;

    return uniqueOlder.length;
  }

  void markNoMoreOlder() {
    hasMoreOlder = false;
  }

  void finishOlderLoad() {
    loadingOlder = false;

    paginationReady = true;
  }

  // ========================================
  // REMOVE MESSAGE
  // ========================================

  void removeAt(int index) {
    if (index < 0 || index >= messages.length) {
      return;
    }

    messages.removeAt(index);
  }

  // ========================================
  // REALTIME UPSERT
  // ========================================

  ChatMessageUpsertResult upsertRealtime(Map<String, dynamic> incoming) {
    final existingIndex = indexOfSame(messages, incoming);

    // ========================================
    // DANG XEM HISTORY CU
    //
    // NEU MESSAGE NAY CHUA TON TAI,
    // KHONG APPEND MESSAGE MOI VAO GIUA
    // HISTORY.
    // ========================================

    if (existingIndex < 0 && hasMoreNewer) {
      return ChatMessageUpsertResult.skipped;
    }

    // ========================================
    // UPDATE MESSAGE DA CO
    // ========================================

    if (existingIndex >= 0) {
      messages[existingIndex] = incoming;

      return ChatMessageUpsertResult.updated;
    }

    // ========================================
    // MESSAGE MOI
    // ========================================

    messages.add(incoming);

    return ChatMessageUpsertResult.inserted;
  }

  // ========================================
  // RECONNECT CATCH-UP
  //
  // Lay TAT CA message moi hon message
  // cuoi cung Flutter dang co.
  //
  // Khong bi gioi han o latest 50.
  // ========================================

  Future<int> catchUpNewerMessages() async {
    if (_disposed) {
      return 0;
    }

    // ========================================
    // CHUA CO MESSAGE
    // -> FALLBACK LATEST PAGE
    // ========================================

    if (messages.isEmpty) {
      final page = await fetchLatestPage();

      if (_disposed) {
        return 0;
      }

      messages = page.messages;

      hasMoreOlder = page.hasBefore;

      hasMoreNewer = false;

      loading = false;

      return page.messages.length;
    }

    var afterId = messages.last['id']?.toString().trim() ?? '';

    // ========================================
    // BACKEND CURSOR DUNG internal id.
    //
    // Neu message cuoi khong co id
    // thi fallback latest page.
    // ========================================

    if (afterId.isEmpty) {
      return _fallbackLatestPage();
    }

    var fetchedCount = 0;

    // ========================================
    // FAILSAFE:
    // 100 page x 50 = toi da 5000 message
    // cho mot lan catch-up.
    // ========================================

    for (var pageNumber = 0; pageNumber < 100; pageNumber += 1) {
      if (_disposed) {
        return fetchedCount;
      }

      final page = await fetchNewerPage(afterId: afterId);

      if (_disposed) {
        return fetchedCount;
      }

      // ========================================
      // CURSOR CU KHONG CON TON TAI
      // -> FALLBACK LATEST.
      // ========================================

      if (!page.anchorFound) {
        return _fallbackLatestPage();
      }

      final newer = page.messages;

      // ========================================
      // KHONG CON MESSAGE MOI
      // ========================================

      if (newer.isEmpty) {
        if (page.hasAfter) {
          return _fallbackLatestPage();
        }

        hasMoreNewer = false;

        return fetchedCount;
      }

      mergeLatest(newer, force: false);

      fetchedCount += newer.length;

      hasMoreNewer = page.hasAfter;

      if (!page.hasAfter) {
        hasMoreNewer = false;

        return fetchedCount;
      }

      final nextAfterId = newer.last['id']?.toString().trim() ?? '';

      // ========================================
      // CURSOR KHONG TIEN LEN
      // -> KHONG LOOP VO HAN.
      // ========================================

      if (nextAfterId.isEmpty || nextAfterId == afterId) {
        return _fallbackLatestPage();
      }

      afterId = nextAfterId;
    }

    // ========================================
    // FAILSAFE DAT GIOI HAN PAGE.
    //
    // GIU hasMoreNewer=true DE KHONG COI
    // DATA HIEN TAI LA DA BAT KIP HOAN TOAN.
    // ========================================

    hasMoreNewer = true;

    return fetchedCount;
  }

  Future<int> _fallbackLatestPage() async {
    final page = await fetchLatestPage();

    if (_disposed) {
      return 0;
    }

    if (messages.isEmpty) {
      messages = page.messages;

      hasMoreOlder = page.hasBefore;

      hasMoreNewer = false;

      loading = false;
    } else {
      mergeLatest(page.messages, force: true);
    }

    return page.messages.length;
  }

  // ========================================
  // MERGE LATEST PAGE
  //
  // DUNG KHI:
  // - REALTIME RECONNECT
  // - HISTORY SYNCED
  // - FALLBACK SAU GUI ANH
  // ========================================

  void mergeLatest(List<Map<String, dynamic>> latest, {required bool force}) {
    for (final incoming in latest) {
      final existingIndex = indexOfSame(messages, incoming);

      if (existingIndex >= 0) {
        messages[existingIndex] = incoming;
      } else {
        messages.add(incoming);
      }
    }

    // ========================================
    // CU NHAT -> MOI NHAT
    // ========================================

    messages.sort((a, b) {
      final aTime = int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;

      final bTime = int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;

      return aTime.compareTo(bTime);
    });

    if (force) {
      hasMoreNewer = false;
    }
  }

  // ========================================
  // SO SANH 2 MESSAGE
  // ========================================

  bool isSameMessage(Map<String, dynamic> a, Map<String, dynamic> b) {
    const keys = <String>['msgId', 'cliMsgId', 'id'];

    for (final key in keys) {
      final aValue = a[key]?.toString();

      final bValue = b[key]?.toString();

      if (aValue != null &&
          aValue.isNotEmpty &&
          bValue != null &&
          bValue.isNotEmpty &&
          aValue == bValue) {
        return true;
      }
    }

    return false;
  }

  // ========================================
  // MESSAGE CO DUOC HIEN THI KHONG
  // ========================================

  bool shouldDisplayMessage(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'normal';

    // ========================================
    // MESSAGE DA XOA LOCAL
    // ========================================

    if (status == 'deleted_local') {
      return false;
    }

    // ========================================
    // MESSAGE DA THU HOI
    // VAN PHAI HIEN BUBBLE THU HOI
    // ========================================

    if (status == 'recalled') {
      return true;
    }

    // ========================================
    // TEXT MESSAGE
    // ========================================

    final content = message['content']?.toString().trim() ?? '';

    if (content.isNotEmpty) {
      return true;
    }

    // ========================================
    // MEDIA MESSAGE
    // ========================================

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    const stringAttachmentTypes = <String>{
      'chat.photo',

      'chat.sticker',

      'chat.video',
      'chat.video.msg',

      'share.file',
      'chat.file',
      'chat.file.msg',

      'chat.gif',

      'chat.voice',
      'chat.voice.msg',
      'chat.audio',
    };

    if (stringAttachmentTypes.contains(msgType)) {
      return true;
    }

    final numericType = int.tryParse(msgType);

    const numericAttachmentTypes = <int>{31, 32, 44, 46, 49};

    return numericType != null && numericAttachmentTypes.contains(numericType);
  }

  // ========================================
  // CONVERT RAW API MESSAGE LIST
  // ========================================

  List<Map<String, dynamic>> extractMessages(dynamic raw) {
    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(shouldDisplayMessage)
        .toList();
  }

  // ========================================
  // LOC MESSAGE CHUA TON TAI
  // ========================================

  List<Map<String, dynamic>> uniqueAgainst(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    return incoming.where((item) {
      return !existing.any((current) => isSameMessage(current, item));
    }).toList();
  }

  // ========================================
  // TIM MESSAGE TRUNG
  // ========================================

  int indexOfSame(
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> message,
  ) {
    return messages.indexWhere((item) => isSameMessage(item, message));
  }

  // ========================================
  // DISPOSE
  // ========================================

  void dispose() {
    _disposed = true;

    _latestReloadTimer?.cancel();

    _latestReloadTimer = null;
  }
}
