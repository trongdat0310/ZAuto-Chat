import 'dart:async';

import '../../services/backend_service.dart';

class ChatMessagesPageData {
  final List<Map<String, dynamic>> messages;

  final bool hasBefore;

  const ChatMessagesPageData({required this.messages, required this.hasBefore});
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

    _latestReloadTimer?.cancel();

    _latestReloadTimer = Timer(const Duration(milliseconds: 250), () async {
      if (_disposed) {
        return;
      }

      // ========================================
      // DANG XEM HISTORY CU
      //
      // REALTIME BINH THUONG KHONG DUOC
      // NHAY VE LATEST.
      //
      // force=true DUOC PHEP LAY LATEST.
      // ========================================

      if (hasMoreNewer && !force) {
        return;
      }

      try {
        final page = await fetchLatestPage();

        if (_disposed) {
          return;
        }

        final latest = page.messages;

        mergeLatest(latest, force: force);

        if (_disposed) {
          return;
        }

        onApplied(
          ChatMessagesReloadResult(
            latestCount: latest.length,

            totalCount: messages.length,

            force: force,
          ),
        );
      } catch (error, stackTrace) {
        if (_disposed) {
          return;
        }

        onError?.call(error, stackTrace);
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
  }) async {
    final page = await backend.getConversationMessagesPage(
      groupId: groupId,
      limit: limit,
      beforeId: beforeId,
    );

    final loadedMessages = extractMessages(page['messages']);

    return ChatMessagesPageData(
      messages: loadedMessages,
      hasBefore: page['hasBefore'] == true,
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
