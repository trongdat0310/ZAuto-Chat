import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../controllers/settings_controller.dart';
import '../services/backend_service.dart';
import 'chat/chat_page.dart';
import '../services/app_realtime_service.dart';

import 'dart:async';

class MessagesPage extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final AppRealtimeService realtimeService;
  final SettingsController settingsController;

  const MessagesPage({
    super.key,

    required this.realtimeService,

    required this.settingsController,

    required this.onOpenSettings,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  final TextEditingController searchController = TextEditingController();

  late TabController tabController;

  List<Map<String, dynamic>> conversations = [];

  List<Map<String, dynamic>> acceptedTrips = [];

  Set<String> enabledGroupIds = {};

  bool loading = true;

  bool syncing = false;

  String searchText = '';

  DateTime? lastSyncAt;

  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;

  Timer? realtimeRefreshTimer;

  Timer? realtimeConversationRefreshTimer;

  Timer? realtimeAcceptedRefreshTimer;

  bool realtimeStarted = false;

  bool realtimeDisposed = false;

  bool realtimeAuthFailed = false;

  Future<void>? _loadFuture;

  bool _loadPending = false;

  bool _pendingShowLoading = false;

  bool _pendingShowError = false;

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 3, vsync: this);

    searchController.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        searchText = searchController.text.trim().toLowerCase();
      });
    });

    loadData();
    startRealtime();
  }

  void startRealtime() {
    if (realtimeDisposed || realtimeStarted) {
      return;
    }

    realtimeStarted = true;

    realtimeSubscription = widget.realtimeService.events.listen(
      (event) {
        if (realtimeDisposed) {
          return;
        }

        final type = event['type']?.toString();

        // ========================================
        // AUTH HANDSHAKE
        // ========================================

        if (type == 'auth_required') {
          return;
        }

        if (type == 'authenticated') {
          realtimeAuthFailed = false;

          // ========================================
          // SAU RECONNECT:
          // LAY LAI CONVERSATION STATE
          // DE KHONG BO SOT THAY DOI.
          // ========================================

          scheduleRealtimeRefresh();

          return;
        }

        if (type == 'auth_error') {
          realtimeAuthFailed = true;

          debugPrint('MESSAGES REALTIME AUTH ERROR');

          return;
        }

        // ========================================
        // CUOC VUA DUOC NHAN
        // ========================================

        if (type == 'trip_accepted') {
          scheduleAcceptedTripsRefresh();

          return;
        }

        // ========================================
        // NEW TRIP
        //
        // HomePage da nhan payload realtime truc tiep.
        // MessagesPage khong can reload 3 API.
        //
        // Conversation store se phat rieng
        // "conversation_message" de cap nhat danh sach chat.
        // ========================================

        if (type == 'new_trip') {
          return;
        }

        // ========================================
        // CONVERSATION STATE THAY DOI
        // ========================================

        if (type == 'conversation_message' ||
            type == 'conversation_message_updated' ||
            type == 'conversation_read' ||
            type == 'conversation_pinned' ||
            type == 'conversation_deleted' ||
            type == 'conversation_history_synced') {
          scheduleConversationRefresh();

          return;
        }
      },

      onError: (Object error) {
        if (realtimeDisposed) {
          return;
        }

        debugPrint(
          'MESSAGES REALTIME ERROR: '
          '$error',
        );
      },

      onDone: () {
        if (realtimeDisposed) {
          return;
        }

        realtimeSubscription = null;
        realtimeStarted = false;

        if (realtimeAuthFailed) {
          return;
        }

        debugPrint('MESSAGES REALTIME STREAM DONE');
      },
    );
  }

  void scheduleConversationRefresh() {
    if (realtimeDisposed) {
      return;
    }

    realtimeConversationRefreshTimer?.cancel();

    realtimeConversationRefreshTimer =
        Timer(const Duration(milliseconds: 100), () async {
      realtimeConversationRefreshTimer = null;

      if (realtimeDisposed || !mounted) {
        return;
      }

      try {
        final result =
            await backend.getConversations();

        if (realtimeDisposed || !mounted) {
          return;
        }

        setState(() {
          conversations = result;
        });
      } catch (error) {
        debugPrint(
          'MESSAGES CONVERSATION '
          'REFRESH ERROR: $error',
        );
      }
    });
  }

  void scheduleAcceptedTripsRefresh() {
    if (realtimeDisposed) {
      return;
    }

    realtimeAcceptedRefreshTimer?.cancel();

    realtimeAcceptedRefreshTimer =
        Timer(const Duration(milliseconds: 100), () async {
      realtimeAcceptedRefreshTimer = null;

      if (realtimeDisposed || !mounted) {
        return;
      }

      try {
        final result =
            await backend.getAcceptedTrips();

        if (realtimeDisposed || !mounted) {
          return;
        }

        setState(() {
          acceptedTrips = result;
        });
      } catch (error) {
        debugPrint(
          'MESSAGES ACCEPTED TRIPS '
          'REFRESH ERROR: $error',
        );
      }
    });
  }

  void scheduleRealtimeRefresh() {
    if (realtimeDisposed) {
      return;
    }

    realtimeRefreshTimer?.cancel();
    realtimeRefreshTimer = null;

    realtimeRefreshTimer = Timer(const Duration(milliseconds: 350), () async {
      realtimeRefreshTimer = null;

      if (realtimeDisposed || !mounted) {
        return;
      }

      await loadData(showLoading: false, showError: false);
    });
  }

  // ========================================
  // LOAD
  // ========================================

  Future<void> loadData({bool showLoading = true, bool showError = true}) {
    if (realtimeDisposed || !mounted) {
      return Future.value();
    }

    // ========================================
    // GHI NHAN MOT LAN LOAD CAN CHAY.
    //
    // Neu request dang chay:
    // KHONG mo request moi ngay lap tuc.
    // ========================================

    _loadPending = true;

    _pendingShowLoading = _pendingShowLoading || showLoading;

    _pendingShowError = _pendingShowError || showError;

    // ========================================
    // DA CO LOAD CYCLE DANG CHAY
    //
    // Tat ca caller cung doi cycle nay.
    // ========================================

    final running = _loadFuture;

    if (running != null) {
      return running;
    }

    final future = _drainLoadQueue();

    _loadFuture = future;

    return future;
  }

  Future<void> _drainLoadQueue() async {
    try {
      while (_loadPending && mounted && !realtimeDisposed) {
        final showLoading = _pendingShowLoading;

        final showError = _pendingShowError;

        // ========================================
        // CONSUME REQUEST HIEN TAI.
        //
        // Neu realtime event den trong luc
        // await API, _loadPending se lai = true
        // va loop se chay them MOT lan.
        // ========================================

        _loadPending = false;

        _pendingShowLoading = false;

        _pendingShowError = false;

        await _loadDataOnce(showLoading: showLoading, showError: showError);
      }
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _loadDataOnce({
    required bool showLoading,
    required bool showError,
  }) async {
    if (realtimeDisposed || !mounted) {
      return;
    }

    if (showLoading) {
      setState(() {
        loading = true;
      });
    }

    try {
      // ========================================
      // 3 REQUEST DOC LAP
      //
      // CHAY SONG SONG THAY VI:
      //
      // accepted
      //   ↓ doi
      // conversations + groups
      //
      // Giup MessagesPage load nhanh hon.
      // ========================================

      final results = await Future.wait<List<Map<String, dynamic>>>([
        backend.getAcceptedTrips(),

        backend.getConversations(),

        backend.getGroups(),
      ]);

      if (realtimeDisposed || !mounted) {
        return;
      }

      final acceptedResult = results[0];

      final conversationResult = results[1];

      final groupResult = results[2];

      final enabled = <String>{};

      for (final group in groupResult) {
        if (group['enabled'] != true) {
          continue;
        }

        final id = group['groupId']?.toString().trim();

        if (id == null || id.isEmpty) {
          continue;
        }

        enabled.add(id);
      }

      setState(() {
        acceptedTrips = acceptedResult;

        conversations = conversationResult;

        enabledGroupIds = enabled;

        loading = false;
      });
    } catch (error) {
      if (realtimeDisposed || !mounted) {
        return;
      }

      if (loading) {
        setState(() {
          loading = false;
        });
      }

      // ========================================
      // BACKGROUND REALTIME REFRESH:
      // KHONG SPAM SNACKBAR.
      //
      // Manual load / pull refresh:
      // van hien loi.
      // ========================================

      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể tải tin nhắn: '
              '$error',
            ),
          ),
        );
      } else {
        debugPrint(
          'MESSAGES BACKGROUND '
          'REFRESH ERROR: $error',
        );
      }
    }
  }

  // ========================================
  // SYNC
  // ========================================

  Future<void> syncConversations() async {
    if (syncing) {
      return;
    }

    setState(() {
      syncing = true;
    });

    try {
      await backend.syncConversations();

      await loadData(showLoading: false, showError: false);

      if (!mounted) {
        return;
      }

      setState(() {
        lastSyncAt = DateTime.now();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã đồng bộ nhóm')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đồng bộ thất bại: $error')));
    } finally {
      if (mounted) {
        setState(() {
          syncing = false;
        });
      }
    }
  }

  // ========================================
  // SEARCH
  // ========================================

  bool matchesSearch(Map<String, dynamic> conversation) {
    if (searchText.isEmpty) {
      return true;
    }

    final name = conversation['name']?.toString().toLowerCase() ?? '';

    final content = conversation['lastContent']?.toString().toLowerCase() ?? '';

    return name.contains(searchText) || content.contains(searchText);
  }

  List<Map<String, dynamic>> get allFiltered {
    return conversations.where(matchesSearch).toList();
  }

  List<Map<String, dynamic>> get notifyingFiltered {
    return conversations.where((conversation) {
      final groupId = conversation['groupId']?.toString();

      if (groupId == null || !enabledGroupIds.contains(groupId)) {
        return false;
      }

      return matchesSearch(conversation);
    }).toList();
  }

  // ========================================
  // TIME
  // ========================================

  String formatTime(dynamic timestamp) {
    if (timestamp == null) {
      return '';
    }

    final value = int.tryParse(timestamp.toString());

    if (value == null) {
      return '';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(value);

    final now = DateTime.now();

    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (sameDay) {
      final hour = date.hour.toString().padLeft(2, '0');

      final minute = date.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    return '${date.day}/${date.month}';
  }

  Future<void> toggleConversationPin(Map<String, dynamic> conversation) async {
    final groupId = conversation['groupId']?.toString().trim();

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final currentlyPinned = conversation['pinned'] == true;

    final nextPinned = !currentlyPinned;

    // ========================================
    // OPTIMISTIC UI
    //
    // Bam xong nhay len/xuong ngay.
    // ========================================

    setState(() {
      conversation['pinned'] = nextPinned;

      conversation['pinnedAt'] = nextPinned
          ? DateTime.now().toIso8601String()
          : null;

      _sortLocalConversations();
    });

    try {
      await backend.setConversationPinned(groupId: groupId, pinned: nextPinned);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),

          content: Text(nextPinned ? 'Đã ghim nhóm' : 'Đã bỏ ghim nhóm'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      // Backend fail -> reload lai truth.
      await loadData(showLoading: false, showError: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật ghim: $error')),
      );
    }
  }

  void _sortLocalConversations() {
    conversations.sort((a, b) {
      final aPinned = a['pinned'] == true;

      final bPinned = b['pinned'] == true;

      if (aPinned != bPinned) {
        return aPinned ? -1 : 1;
      }

      if (aPinned && bPinned) {
        final aPinnedAt =
            DateTime.tryParse(a['pinnedAt']?.toString() ?? '')
                ?.millisecondsSinceEpoch ??
            0;

        final bPinnedAt =
            DateTime.tryParse(b['pinnedAt']?.toString() ?? '')
                ?.millisecondsSinceEpoch ??
            0;

        if (aPinnedAt != bPinnedAt) {
          return bPinnedAt.compareTo(aPinnedAt);
        }
      }

      final aTime = int.tryParse(a['lastMessageAt']?.toString() ?? '') ?? 0;

      final bTime = int.tryParse(b['lastMessageAt']?.toString() ?? '') ?? 0;

      return bTime.compareTo(aTime);
    });
  }

  // ========================================
  // OPEN CHAT
  // ========================================

  Future<void> openConversation(Map<String, dynamic> conversation) async {
    final groupId = conversation['groupId']?.toString();

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final groupName = conversation['name']?.toString() ?? 'Nhóm Zalo';

    final groupAvatar = conversation['avatar']?.toString();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          realtimeService: widget.realtimeService,

          settingsController: widget.settingsController,

          groupId: groupId,

          groupName: groupName,

          groupAvatar: groupAvatar,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await loadData(showLoading: false, showError: false);
  }

  String? _getGroupAvatar(String groupId) {
    for (final conversation in conversations) {
      final conversationGroupId = conversation['groupId']?.toString().trim();

      if (conversationGroupId == groupId.trim()) {
        final avatar = conversation['avatar']?.toString().trim();

        if (avatar != null && avatar.isNotEmpty) {
          return avatar;
        }

        return null;
      }
    }

    return null;
  }

  String? firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  Future<void> openAcceptedTrip(Map<String, dynamic> trip) async {
    final groupId = firstNonEmptyString([
      trip['sourceThreadId'],
      trip['groupId'],
      trip['threadId'],
    ]);


    final replyMsgId =
        firstNonEmptyString([
      trip['replyZaloMessageId'],
    ]);


    final replyCliMsgId =
        firstNonEmptyString([
      trip['replyZaloCliMessageId'],
    ]);


    final replyText =
        firstNonEmptyString([
      trip['replyText'],
    ]);


    final acceptedAt =
        DateTime.tryParse(
      trip['acceptedAt']
              ?.toString() ??
          '',
    );


    final acceptedAtMs =
        acceptedAt
            ?.millisecondsSinceEpoch;


    final groupName =
        firstNonEmptyString([
          trip['groupName'],
          trip['sourceGroupName'],
        ]) ??
        'Nhóm Zalo';


    if (
      groupId == null ||
      groupId.isEmpty
    ) {
      await showMessageNotFound(
        'Không còn thông tin nhóm của cuốc này.',
      );

      return;
    }


    // ========================================
    // TARGET LICH SU NHAN
    //
    // Uu tien bat ky ID nao cua tin "Nhan"
    // do chinh user gui.
    //
    // Neu Zalo khong tra reply ID:
    // fallback bang isSelf + replyText + acceptedAt
    // trong ChatTargetController.
    //
    // TUYET DOI KHONG fallback ve sourceMsgId
    // cua tin khach.
    // ========================================

    final hasReplyId =
        replyMsgId != null ||
        replyCliMsgId != null;


    final hasSafeFallback =
        replyText != null &&
        acceptedAtMs != null;


    if (
      !hasReplyId &&
      !hasSafeFallback
    ) {
      await showMessageNotFound(
        'Cuốc này không còn đủ thông tin để xác định tin Nhận của bạn.',
      );

      return;
    }


    final groupAvatar =
        _getGroupAvatar(
      groupId,
    );


    if (!mounted) {
      return;
    }


    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          realtimeService:
              widget.realtimeService,

          settingsController:
              widget.settingsController,

          groupId:
              groupId,

          groupName:
              groupName,

          groupAvatar:
              groupAvatar,

          targetMsgId:
              replyMsgId,

          targetCliMsgId:
              replyCliMsgId,

          targetReplyText:
              replyText,

          targetAcceptedAtMs:
              acceptedAtMs,
        ),
      ),
    );
  }


  Future<void> showMessageNotFound(String detail) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Không tìm thấy tin nhắn'),

          content: Text(detail),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },

              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showConversationActions(
    Map<String, dynamic> conversation,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    final pinned = conversation['pinned'] == true;

    final name = conversation['name']?.toString() ?? 'Nhóm Zalo';

    await showDialog<void>(
      context: context,

      barrierColor: const Color(0x99000000),

      builder: (dialogContext) {
        return Dialog(
          alignment: Alignment.centerLeft,

          insetPadding: const EdgeInsets.symmetric(horizontal: 16),

          backgroundColor: Colors.transparent,

          elevation: 0,

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),

            child: Material(
              color: colorScheme.surface,

              borderRadius: BorderRadius.circular(18),

              clipBehavior: Clip.antiAlias,

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  // ========================================
                  // HEADER
                  // ========================================

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),

                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,

                          child: Icon(Icons.group_rounded),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            name,

                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: 17,

                              fontWeight: FontWeight.w600,

                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ========================================
                  // PIN / UNPIN
                  // ========================================
                  ListTile(
                    minLeadingWidth: 34,

                    leading: Icon(
                      pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,

                      size: 27,

                      color: pinned
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),

                    title: Text(
                      pinned ? 'Bỏ ghim' : 'Ghim',

                      style: TextStyle(
                        fontSize: 18,

                        color: colorScheme.onSurface,
                      ),
                    ),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,

                      vertical: 5,
                    ),

                    onTap: () {
                      Navigator.of(dialogContext).pop();

                      toggleConversationPin(conversation);
                    },
                  ),

                  // ========================================
                  // DELETE
                  // ========================================
                  ListTile(
                    minLeadingWidth: 34,

                    leading: const Icon(
                      Icons.delete_outline_rounded,

                      size: 28,

                      color: Colors.red,
                    ),

                    title: const Text(
                      'Xóa',

                      style: TextStyle(
                        fontSize: 18,

                        color: Colors.red,

                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,

                      vertical: 5,
                    ),

                    onTap: () {
                      Navigator.of(dialogContext).pop();

                      _confirmDeleteConversation(conversation);
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteConversation(
    Map<String, dynamic> conversation,
  ) async {
    final name = conversation['name']?.toString() ?? 'nhóm này';

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xóa cuộc trò chuyện?'),

          content: Text(
            'Bạn có chắc muốn xóa "$name" khỏi danh sách tin nhắn?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },

              child: const Text('Hủy'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),

              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },

              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _deleteConversation(conversation);
  }

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    final groupId = conversation['groupId']?.toString().trim();

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    try {
      await backend.deleteConversation(groupId: groupId);

      if (!mounted) {
        return;
      }

      setState(() {
        conversations.removeWhere(
          (item) => item['groupId']?.toString() == groupId,
        );
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa cuộc trò chuyện')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xóa thất bại: $error')));
    }
  }

  // ========================================
  // CONVERSATION ITEM
  // ========================================

  Widget buildConversationItem(Map<String, dynamic> conversation) {
    final colorScheme = Theme.of(context).colorScheme;

    final name = conversation['name']?.toString() ?? 'Nhóm Zalo';

    final lastContent = conversation['lastContent']?.toString();

    final sender = conversation['lastSenderName']?.toString();

    final lastIsSelf = conversation['lastIsSelf'] == true;

    final avatar = conversation['avatar']?.toString();

    final groupId = conversation['groupId']?.toString() ?? '';

    final notifying = enabledGroupIds.contains(groupId);

    final pinned = conversation['pinned'] == true;

    // ========================================
    // UNREAD
    // ========================================

    final unreadCount =
        int.tryParse(conversation['unreadCount']?.toString() ?? '') ?? 0;

    final safeUnreadCount = unreadCount < 0 ? 0 : unreadCount;

    final hasUnread = safeUnreadCount > 0;

    final unreadText = safeUnreadCount > 99 ? '9+' : safeUnreadCount.toString();

    // ========================================
    // SUBTITLE
    // ========================================

    String subtitle;

    // ========================================
    // CHUA CO MESSAGE
    // ========================================

    if (lastContent == null || lastContent.isEmpty) {
      subtitle = 'Chưa có tin nhắn mới';

      // ========================================
      // MESSAGE DO CHINH MINH GUI
      // ========================================
    } else if (lastIsSelf) {
      subtitle = 'Bạn: $lastContent';

      // ========================================
      // MESSAGE NGUOI KHAC GUI
      // ========================================
    } else if (sender != null && sender.isNotEmpty) {
      subtitle = '$sender: $lastContent';
    } else {
      subtitle = lastContent;
    }

    // ========================================
    // TIME
    // ========================================

    final timeText = formatTime(conversation['lastMessageAt']);

    return InkWell(
      onTap: () => openConversation(conversation),

      onLongPress: () => _showConversationActions(conversation),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),

        child: Row(
          children: [
            // ========================================
            // AVATAR
            // ========================================

            CircleAvatar(
              radius: 27,

              backgroundImage: avatar != null && avatar.isNotEmpty
                  ? NetworkImage(avatar)
                  : null,

              child: avatar == null || avatar.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',

                      style: const TextStyle(fontSize: 20),
                    )
                  : null,
            ),

            const SizedBox(width: 13),

            // ========================================
            // NAME + LAST MESSAGE
            // ========================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            fontSize: 16,

                            // ========================================
                            // UNREAD -> DAM HON
                            // ========================================
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),

                      // ========================================
                      // PIN / UNPIN BUTTON
                      // ========================================
                      SizedBox(
                        width: 34,

                        height: 34,

                        child: IconButton(
                          tooltip: pinned ? 'Bỏ ghim nhóm' : 'Ghim nhóm',

                          padding: EdgeInsets.zero,

                          visualDensity: VisualDensity.compact,

                          onPressed: () {
                            toggleConversationPin(conversation);
                          },

                          icon: Icon(
                            pinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,

                            size: 18,

                            color: pinned
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                      if (notifying)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),

                          child: Icon(
                            Icons.notifications_active_outlined,

                            size: 17,

                            color: hasUnread
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    subtitle,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      color: hasUnread
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,

                      fontWeight: hasUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ========================================
            // TIME + UNREAD BADGE
            // ========================================
            Column(
              mainAxisAlignment: MainAxisAlignment.center,

              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(
                  timeText,

                  style: TextStyle(
                    fontSize: 12,

                    color: hasUnread
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,

                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),

                // ========================================
                // BADGE
                // ========================================
                if (hasUnread) ...[
                  const SizedBox(height: 6),

                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 22,

                      minHeight: 22,
                    ),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,

                      vertical: 2,
                    ),

                    alignment: Alignment.center,

                    decoration: BoxDecoration(
                      color: colorScheme.primary,

                      borderRadius: BorderRadius.circular(999),
                    ),

                    child: Text(
                      unreadText,

                      style: TextStyle(
                        color: colorScheme.onPrimary,

                        fontSize: 11,

                        fontWeight: FontWeight.w700,

                        height: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // CONVERSATION LIST
  // ========================================

  Widget buildConversationList(
    List<Map<String, dynamic>> items, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () {
          return loadData(showLoading: false);
        },

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.42),

            const Icon(Icons.chat_bubble_outline, size: 64),

            const SizedBox(height: 16),

            Text(
              emptyTitle,

              textAlign: TextAlign.center,

              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),

              child: Text(emptySubtitle, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return loadData(showLoading: false);
      },

      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),

        itemCount: items.length,

        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),

        itemBuilder: (context, index) {
          return buildConversationItem(items[index]);
        },
      ),
    );
  }

  // ========================================
  // HISTORY PLACEHOLDER
  // ========================================

  Widget buildAcceptedHistory() {
    if (acceptedTrips.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(Icons.history, size: 68),

            SizedBox(height: 16),

            Text(
              'Chưa có cuốc đã nhận',

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),

            SizedBox(height: 8),

            Text('Các cuốc bạn đã nhận sẽ xuất hiện tại đây.'),
          ],
        ),
      );
    }

    if (acceptedFiltered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(Icons.search_off_outlined, size: 60),

            SizedBox(height: 16),

            Text(
              'Không tìm thấy cuốc',

              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),

            SizedBox(height: 8),

            Text('Thử tìm bằng nội dung, tên nhóm hoặc người gửi.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return loadData(showLoading: false);
      },

      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),

        itemCount: acceptedFiltered.length,

        separatorBuilder: (_, _) => const Divider(height: 1),

        itemBuilder: (context, index) {
          final trip = acceptedFiltered[index];

          final content = trip['content']?.toString() ?? 'Cuốc đã nhận';

          final groupName = trip['groupName']?.toString() ?? 'Nhóm Zalo';

          final senderName =
              trip['senderName']?.toString() ?? 'Không rõ người gửi';

          final acceptedAt = DateTime.tryParse(
            trip['acceptedAt']?.toString() ?? '',
          );

          String timeText = '';

          if (acceptedAt != null) {
            final local = acceptedAt.toLocal();

            final hour = local.hour.toString().padLeft(2, '0');

            final minute = local.minute.toString().padLeft(2, '0');

            timeText = '$hour:$minute';
          }

          return ListTile(
            onTap: () => openAcceptedTrip(trip),

            leading: const CircleAvatar(child: Icon(Icons.local_taxi)),

            title: Text(
              content,

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

            ),

            subtitle: Text(
              '$groupName\n'
              '$senderName',

              maxLines: 2,

              overflow: TextOverflow.ellipsis,
            ),

            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(timeText),

                const SizedBox(height: 4),

                const Icon(Icons.chevron_right),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get acceptedFiltered {
    if (searchText.isEmpty) {
      return acceptedTrips;
    }

    return acceptedTrips.where((trip) {
      final content = trip['content']?.toString().toLowerCase() ?? '';

      final groupName = trip['groupName']?.toString().toLowerCase() ?? '';

      final senderName = trip['senderName']?.toString().toLowerCase() ?? '';

      return content.contains(searchText) ||
          groupName.contains(searchText) ||
          senderName.contains(searchText);
    }).toList();
  }

  @override
  void dispose() {
    realtimeDisposed = true;
    realtimeStarted = false;

    _loadPending = false;

    _pendingShowLoading = false;

    _pendingShowError = false;

    final subscription = realtimeSubscription;

    realtimeSubscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    realtimeRefreshTimer?.cancel();
    realtimeConversationRefreshTimer?.cancel();
    realtimeAcceptedRefreshTimer?.cancel();
    realtimeRefreshTimer = null;

    tabController.dispose();
    searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: Column(
        children: [
          // ========================================
          // TOP TABS
          // ========================================

          TabBar(
            controller: tabController,

            isScrollable: true,

            tabs: const [
              Tab(text: 'Tất cả'),

              Tab(
                icon: Icon(Icons.notifications_none, size: 18),

                text: 'Đang thông báo',
              ),

              Tab(icon: Icon(Icons.history, size: 18), text: 'Lịch sử nhận'),
            ],
          ),

          const SizedBox(height: 12),

          // ========================================
          // SEARCH + SETTINGS
          // ========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,

                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm cuộc trò chuyện...',

                      prefixIcon: const Icon(Icons.search),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: widget.onOpenSettings,

                  icon: const Icon(Icons.settings, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ========================================
          // SYNC LINE
          // ========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lastSyncAt == null
                        ? '${enabledGroupIds.length}/${conversations.length} nhóm đang bật thông báo'
                        : 'Đã đồng bộ nhóm',

                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

                TextButton.icon(
                  onPressed: syncing ? null : syncConversations,

                  icon: syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,

                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),

                  label: const Text('Đồng bộ nhóm'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ========================================
          // TAB CONTENT
          // ========================================
          Expanded(
            child: TabBarView(
              controller: tabController,

              children: [
                buildConversationList(
                  allFiltered,

                  emptyTitle: 'Chưa có hội thoại',

                  emptySubtitle:
                      'Các nhóm Zalo sẽ xuất hiện tại đây sau khi đồng bộ.',
                ),

                buildConversationList(
                  notifyingFiltered,

                  emptyTitle: 'Chưa có nhóm đang thông báo',

                  emptySubtitle: 'Hãy bật nhóm trong phần Nhóm nhận thông báo.',
                ),

                buildAcceptedHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
