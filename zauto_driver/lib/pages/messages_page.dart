import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/backend_service.dart';
import 'chat/chat_page.dart';
import '../services/app_realtime_service.dart';

import 'dart:async';

class MessagesPage extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final AppRealtimeService realtimeService;

  const MessagesPage({
    super.key,

    required this.realtimeService,

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

  String historyDatePreset = 'today';

  DateTime historyFromDate = DateTime.now();

  DateTime historyToDate = DateTime.now();

  Set<String> historySelectedGroupIds = <String>{};

  Set<String> enabledGroupIds = {};

  bool loading = true;

  bool syncing = false;

  String searchText = '';

  String notificationFilter = 'all';

  String pinFilter = 'all';

  DateTime? lastSyncAt;

  StreamSubscription<Map<String, dynamic>>? realtimeSubscription;

  Timer? realtimeRefreshTimer;

  bool realtimeStarted = false;

  bool realtimeDisposed = false;

  bool realtimeAuthFailed = false;

  bool realtimeConnected = false;

  String? loadError;

  Future<void>? _loadFuture;

  bool _loadPending = false;

  bool _pendingShowLoading = false;

  bool _pendingShowError = false;

  final Set<String> _pinningGroupIds = <String>{};

  final Map<String, bool> _pendingPinValues = <String, bool>{};

  final Set<String> _deletingGroupIds = <String>{};

  final Map<String, bool> _pendingNotificationValues = <String, bool>{};

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 3, vsync: this);

    tabController.addListener(_handleTabChanged);

    realtimeConnected = widget.realtimeService.isConnected;

    realtimeAuthFailed = widget.realtimeService.hasAuthFailed;

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

  void _handleTabChanged() {
    if (!mounted || tabController.indexIsChanging) {
      return;
    }

    setState(() {});
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

          if (mounted) {
            setState(() {
              realtimeConnected = true;
            });
          }

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

          if (mounted) {
            setState(() {
              realtimeConnected = false;
            });
          }

          debugPrint('MESSAGES REALTIME AUTH ERROR');

          return;
        }

        if (type == 'realtime_disconnected') {
          if (mounted) {
            setState(() {
              realtimeConnected = false;
            });
          }

          return;
        }

        // ========================================
        // CUOC VUA DUOC NHAN
        // ========================================

        if (type == 'trip_accepted') {
          scheduleRealtimeRefresh();

          return;
        }

        if (type == 'group_notification_toggled') {
          final groupId =
              event['groupId']
                  ?.toString()
                  .trim();

          final enabled =
              event['enabled'] == true;

          if (
            groupId != null &&
            groupId.isNotEmpty &&
            mounted
          ) {
            setState(() {
              if (enabled) {
                enabledGroupIds.add(groupId);
              } else {
                enabledGroupIds.remove(groupId);

                historySelectedGroupIds.remove(groupId);
              }
            });
          }

          scheduleRealtimeRefresh();

          return;
        }

        // ========================================
        // CONVERSATION STATE THAY DOI
        //
        // CAC STATE DON GIAN DUOC APPLY NGAY
        // DE THIET BI THU HAI KHONG PHAI DOI
        // 350ms + REST ROUND TRIP.
        //
        // VAN REFRESH NEN SAU DO DE RECONCILE.
        // ========================================

        if (type == 'conversation_read') {
          _applyRealtimeConversationRead(event);

          scheduleRealtimeRefresh();

          return;
        }

        if (type == 'conversation_pinned') {
          _applyRealtimeConversationPinned(event);

          scheduleRealtimeRefresh();

          return;
        }

        if (type == 'conversation_deleted') {
          _applyRealtimeConversationDeleted(event);

          scheduleRealtimeRefresh();

          return;
        }

        if (type != 'conversation_message' &&
            type != 'conversation_message_updated' &&
            type != 'new_trip' &&
            type != 'conversation_history_synced') {
          return;
        }

        scheduleRealtimeRefresh();
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

  Map<String, dynamic>? _eventDataMap(Map<String, dynamic> event) {
    final rawData = event['data'];

    if (rawData is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(rawData);
  }

  Map<String, dynamic>? _findLocalConversation(String groupId) {
    for (final conversation in conversations) {
      if (conversation['groupId']?.toString().trim() == groupId.trim()) {
        return conversation;
      }
    }

    return null;
  }

  void _applyRealtimeConversationRead(Map<String, dynamic> event) {
    final data = _eventDataMap(event);

    if (data == null || !mounted) {
      return;
    }

    final groupId = data['groupId']?.toString().trim();

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final index = conversations.indexWhere(
      (item) => item['groupId']?.toString().trim() == groupId,
    );

    if (index < 0) {
      return;
    }

    setState(() {
      conversations[index]['unreadCount'] = 0;

      final lastReadAt = data['lastReadAt'];

      if (lastReadAt != null) {
        conversations[index]['lastReadAt'] = lastReadAt;
      }
    });
  }

  void _applyRealtimeConversationPinned(Map<String, dynamic> event) {
    final data = _eventDataMap(event);

    if (data == null || !mounted) {
      return;
    }

    final groupId = data['groupId']?.toString().trim();

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    // Local request dang pending thi giu optimistic state.
    // Refresh sau khi request ket thuc se lay backend truth.
    if (_pinningGroupIds.contains(groupId)) {
      return;
    }

    final index = conversations.indexWhere(
      (item) => item['groupId']?.toString().trim() == groupId,
    );

    if (index < 0) {
      return;
    }

    setState(() {
      conversations[index]['pinned'] = data['pinned'] == true;

      conversations[index]['pinnedAt'] = data['pinnedAt'];

      _sortLocalConversations();
    });
  }

  void _applyRealtimeConversationDeleted(Map<String, dynamic> event) {
    final data = _eventDataMap(event);

    if (data == null || !mounted) {
      return;
    }

    final groupId = data['groupId']?.toString().trim();

    if (groupId == null || groupId.isEmpty) {
      return;
    }

    setState(() {
      conversations.removeWhere(
        (item) => item['groupId']?.toString().trim() == groupId,
      );
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

        loadError = null;
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

      // ========================================
      // BAO VE LOCAL ACTION DANG PENDING
      //
      // Mot REST response cu khong duoc:
      // - lam pin optimistic nhay nguoc lai
      // - lam conversation dang xoa hien lai
      // ========================================

      final reconciledConversations = conversationResult
          .where((item) {
            final groupId = item['groupId']?.toString().trim();

            if (groupId == null || groupId.isEmpty) {
              return true;
            }

            return !_deletingGroupIds.contains(groupId);
          })
          .map((item) {
            final copy = Map<String, dynamic>.from(item);

            final groupId = copy['groupId']?.toString().trim();

            if (groupId == null || groupId.isEmpty) {
              return copy;
            }

            final pendingPin = _pendingPinValues[groupId];

            if (pendingPin != null) {
              copy['pinned'] = pendingPin;

              final local = _findLocalConversation(groupId);

              copy['pinnedAt'] = pendingPin
                  ? (local == null ? null : local['pinnedAt'])
                  : null;
            }

            return copy;
          })
          .toList();

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

      for (final entry in _pendingNotificationValues.entries) {
        if (entry.value) {
          enabled.add(entry.key);
        } else {
          enabled.remove(entry.key);
        }
      }

      setState(() {
        loadError = null;

        acceptedTrips = acceptedResult;

        conversations = reconciledConversations;

        _sortLocalConversations();

        enabledGroupIds = enabled;

        historySelectedGroupIds.removeWhere((id) => !enabled.contains(id));

        loading = false;
      });
    } catch (error) {
      if (realtimeDisposed || !mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '').trim();

      if (loading) {
        setState(() {
          loading = false;

          if (conversations.isEmpty && acceptedTrips.isEmpty) {
            loadError = message.isEmpty
                ? 'Không thể tải dữ liệu tin nhắn.'
                : message;
          }
        });
      } else if (conversations.isEmpty && acceptedTrips.isEmpty) {
        setState(() {
          loadError = message.isEmpty
              ? 'Không thể tải dữ liệu tin nhắn.'
              : message;
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

  bool matchesConversationFilters(Map<String, dynamic> conversation) {
    final groupId = conversation['groupId']?.toString() ?? '';
    final enabled = enabledGroupIds.contains(groupId);
    final pinned = conversation['pinned'] == true;
    final isPrivate = conversation['type'] == 'user';
    if (!isPrivate && notificationFilter == 'enabled' && !enabled) return false;
    if (!isPrivate && notificationFilter == 'disabled' && enabled) return false;
    if (isPrivate && notificationFilter != 'all') return false;
    if (pinFilter == 'pinned' && !pinned) return false;
    if (pinFilter == 'unpinned' && pinned) return false;
    return true;
  }

  Future<void> openConversationFilters() async {
    var selectedNotification = notificationFilter;
    var selectedPin = pinFilter;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          Widget choices(String title, String value, void Function(String) change,
              List<(String, String)> options) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(sheetContext).textTheme.labelLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) => ChoiceChip(
                    label: Text(option.$2),
                    selected: value == option.$1,
                    onSelected: (_) => updateSheet(() => change(option.$1)),
                  )).toList(),
                ),
              ],
            );
          }
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lọc nhóm', style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 28),
                  choices('NHẬN THÔNG BÁO', selectedNotification,
                    (value) => selectedNotification = value,
                    [('all', 'Tất cả'), ('enabled', 'Đang bật'), ('disabled', 'Đang tắt')]),
                  const SizedBox(height: 24),
                  choices('GHIM', selectedPin,
                    (value) => selectedPin = value,
                    [('all', 'Tất cả'), ('pinned', 'Đã ghim'), ('unpinned', 'Chưa ghim')]),
                  const SizedBox(height: 30),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: selectedNotification == 'all' && selectedPin == 'all'
                          ? null
                          : () => updateSheet(() {
                              selectedNotification = 'all';
                              selectedPin = 'all';
                            }),
                      child: const Text('Xóa lọc'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      onPressed: () {
                        setState(() {
                          notificationFilter = selectedNotification;
                          pinFilter = selectedPin;
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Áp dụng'),
                    )),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> openHistoryFilters() async {
    var from = historyFromDate;
    var to = historyToDate;
    final selectedGroups = <String>{...historySelectedGroupIds};
    var preset = historyDatePreset;
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final groups = historyGroupOptions;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          void selectPreset(String value) {
            updateSheet(() {
              preset = value;
              final now = DateTime.now();
              final current = day(now);
              final weekStart = current.subtract(Duration(days: current.weekday - 1));
              switch (value) {
                case 'today':
                  from = current; to = current;
                case 'yesterday':
                  from = current.subtract(const Duration(days: 1)); to = from;
                case 'week':
                  from = weekStart; to = current;
                case 'lastWeek':
                  from = weekStart.subtract(const Duration(days: 7));
                  to = weekStart.subtract(const Duration(days: 1));
                case 'month':
                  from = DateTime(now.year, now.month); to = current;
                case 'lastMonth':
                  from = DateTime(now.year, now.month - 1);
                  to = DateTime(now.year, now.month, 0);
                case 'custom':
                  break;
              }
            });
          }

          Future<void> pickDate(bool isFrom) async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: isFrom ? from : to,
              firstDate: isFrom ? DateTime(2020) : from,
              lastDate: isFrom ? to : DateTime.now(),
            );
            if (picked != null) {
              updateSheet(() {
                preset = 'custom';
                if (isFrom) { from = picked; } else { to = picked; }
              });
            }
          }

          Widget dateField(String label, DateTime date, bool isFrom) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => pickDate(isFrom),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_formatHistoryDate(date)),
                ),
              ],
            );
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bộ lọc', style: Theme.of(sheetContext).textTheme.headlineSmall),
                    const SizedBox(height: 28),
                    Text('NGÀY NHẬN', style: Theme.of(sheetContext).textTheme.labelLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        ('today', 'Hôm nay'),
                        ('yesterday', 'Hôm qua'),
                        ('week', 'Tuần này'),
                        ('lastWeek', 'Tuần trước'),
                        ('month', 'Tháng này'),
                        ('lastMonth', 'Tháng trước'),
                        ('custom', 'Chọn khoảng thời gian'),
                      ].map((item) => ChoiceChip(
                        label: Text(item.$2),
                        selected: preset == item.$1,
                        onSelected: (_) => selectPreset(item.$1),
                      )).toList(),
                    ),
                    if (preset == 'custom') ...[
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: dateField('Từ ngày', from, true)),
                        const SizedBox(width: 12),
                        Expanded(child: dateField('Đến ngày', to, false)),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    Text('NHÓM', style: Theme.of(sheetContext).textTheme.labelLarge),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await showDialog<void>(
                          context: sheetContext,
                          builder: (dialogContext) => StatefulBuilder(
                            builder: (dialogContext, updateDialog) => AlertDialog(
                              title: const Text('Chọn nhóm'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: groups.isEmpty
                                    ? const Text('Chưa có nhóm đang bật thông báo')
                                    : ListView(
                                        shrinkWrap: true,
                                        children: [
                                          CheckboxListTile(
                                            title: const Text('Tất cả nhóm'),
                                            value: selectedGroups.isEmpty,
                                            onChanged: (_) => updateDialog(() => selectedGroups.clear()),
                                          ),
                                          ...groups.map((item) {
                                            final id = item['id']!;
                                            return CheckboxListTile(
                                              title: Text(item['name'] ?? 'Nhóm Zalo'),
                                              value: selectedGroups.contains(id),
                                              onChanged: (checked) => updateDialog(() {
                                                if (checked == true) {
                                                  selectedGroups.add(id);
                                                } else {
                                                  selectedGroups.remove(id);
                                                }
                                              }),
                                            );
                                          }),
                                        ],
                                      ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Xong'),
                                ),
                              ],
                            ),
                          ),
                        );
                        updateSheet(() {});
                      },
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(selectedGroups.isEmpty
                          ? 'Tất cả nhóm'
                          : 'Đã chọn ${selectedGroups.length} nhóm'),
                    ),
                    const SizedBox(height: 28),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => updateSheet(() {
                          preset = 'today';
                          from = day(DateTime.now());
                          to = from;
                          selectedGroups.clear();
                        }),
                        child: const Text('Xóa lọc'),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton(
                        onPressed: () {
                          setState(() {
                            historyDatePreset = preset;
                            historyFromDate = from;
                            historyToDate = to;
                            historySelectedGroupIds = <String>{...selectedGroups}..removeWhere((id) => !enabledGroupIds.contains(id));
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Áp dụng'),
                      )),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> get allFiltered {
    return conversations.where((conversation) => matchesSearch(conversation) && matchesConversationFilters(conversation)).toList();
  }

  List<Map<String, dynamic>> get notifyingFiltered {
    return conversations.where((conversation) {
      final groupId = conversation['groupId']?.toString();

      if (groupId == null || !enabledGroupIds.contains(groupId)) {
        return false;
      }

      return matchesSearch(conversation) && matchesConversationFilters(conversation);
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

    if (_pinningGroupIds.contains(groupId) ||
        _deletingGroupIds.contains(groupId) ||
        _pendingNotificationValues.containsKey(groupId)) {
      return;
    }

    final currentlyPinned = conversation['pinned'] == true;

    final nextPinned = !currentlyPinned;

    _pinningGroupIds.add(groupId);

    _pendingPinValues[groupId] = nextPinned;

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
      final updated = await backend.setConversationPinned(
        groupId: groupId,
        pinned: nextPinned,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final index = conversations.indexWhere(
          (item) => item['groupId']?.toString().trim() == groupId,
        );

        if (index >= 0) {
          conversations[index]['pinned'] = updated['pinned'] == true;

          conversations[index]['pinnedAt'] = updated['pinnedAt'];

          _sortLocalConversations();
        }
      });

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
    } finally {
      _pinningGroupIds.remove(groupId);

      _pendingPinValues.remove(groupId);

      if (mounted) {
        setState(() {});

        await loadData(showLoading: false, showError: false);
      }
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

    final groupName = conversation['name']?.toString() ??
        (conversation['type'] == 'user' ? 'Tin nhắn riêng' : 'Nhóm Zalo');

    final groupAvatar = conversation['avatar']?.toString();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          realtimeService: widget.realtimeService,

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
    // Ho tro ca record moi va record cu.
    final groupId = firstNonEmptyString([
      trip['sourceThreadId'],
      trip['groupId'],
      trip['threadId'],
    ]); // ========================================
    // TARGET CUA LICH SU NHAN
    //
    // Neu co replyZaloMessageId:
    // -> day la tin "Nhan" cua chinh minh.
    // -> TUYET DOI KHONG dung cliMsgId cua tin goc.
    //
    // Chi fallback ve source message
    // neu cuoc cu KHONG co replyZaloMessageId.
    // ========================================

    final replyMsgId = firstNonEmptyString([trip['replyZaloMessageId']]);

    final replyCliMsgId = firstNonEmptyString([trip['replyZaloCliMessageId']]);

    final String? msgId;

    final String? cliMsgId;

    if (replyMsgId != null && replyMsgId.isNotEmpty) {
      // ========================================
      // CUOC MOI:
      // NHAY DEN TIN "NHAN"
      // ========================================

      msgId = replyMsgId;

      // Co thi dung.
      // Khong co thi de null.
      //
      // KHONG fallback sang sourceCliMsgId.
      cliMsgId = replyCliMsgId;
    } else {
      // ========================================
      // CUOC CU:
      // CHUA LUU replyZaloMessageId
      // -> fallback ve tin nguoi gui.
      // ========================================

      msgId = firstNonEmptyString([
        trip['sourceMsgId'],
        trip['zaloMessageId'],
        trip['msgId'],
      ]);

      cliMsgId = firstNonEmptyString([
        trip['sourceCliMsgId'],
        trip['clientMessageId'],
        trip['cliMsgId'],
      ]);
    }

    final groupName =
        firstNonEmptyString([trip['groupName'], trip['sourceGroupName']]) ??
        'Nhóm Zalo';

    if (groupId == null || groupId.isEmpty) {
      await showMessageNotFound('Không còn thông tin nhóm của cuốc này.');

      return;
    }

    final groupAvatar = _getGroupAvatar(groupId);

    if ((msgId == null || msgId.isEmpty) &&
        (cliMsgId == null || cliMsgId.isEmpty)) {
      await showMessageNotFound(
        'Cuốc này không còn thông tin liên kết tới tin nhắn Zalo gốc.',
      );

      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          realtimeService: widget.realtimeService,

          groupId: groupId,

          groupName: groupName,

          groupAvatar: groupAvatar,

          targetMsgId: msgId,

          targetCliMsgId: cliMsgId,
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

  Future<void> _toggleConversationNotifications(
    Map<String, dynamic> conversation,
  ) async {
    final groupId = conversation['groupId']?.toString().trim() ?? '';
    if (conversation['type'] != 'group' || groupId.isEmpty || !mounted) {
      return;
    }
    if (_pendingNotificationValues.containsKey(groupId) ||
        _pinningGroupIds.contains(groupId) ||
        _deletingGroupIds.contains(groupId)) {
      return;
    }

    final wasEnabled = enabledGroupIds.contains(groupId);
    final nextEnabled = !wasEnabled;
    setState(() {
      _pendingNotificationValues[groupId] = nextEnabled;
      if (nextEnabled) {
        enabledGroupIds.add(groupId);
      } else {
        enabledGroupIds.remove(groupId);
      }
    });

    try {
      final enabled = await backend.toggleGroup(groupId, nextEnabled);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingNotificationValues[groupId] = enabled;
        if (enabled) {
          enabledGroupIds.add(groupId);
        } else {
          enabledGroupIds.remove(groupId);
          historySelectedGroupIds.remove(groupId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Đã thêm nhóm vào thông báo' : 'Đã bỏ nhóm khỏi thông báo',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (wasEnabled) {
          enabledGroupIds.add(groupId);
        } else {
          enabledGroupIds.remove(groupId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật thông báo nhóm: $error')),
      );
    } finally {
      _pendingNotificationValues.remove(groupId);
      if (mounted) {
        setState(() {});
        await loadData(showLoading: false, showError: false);
      }
    }
  }

  Future<void> _showConversationActions(
    Map<String, dynamic> conversation,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    final pinned = conversation['pinned'] == true;

    final isGroup = conversation['type'] == 'group';

    final notifying = enabledGroupIds.contains(
      conversation['groupId']?.toString().trim() ?? '',
    );

    final name = conversation['name']?.toString() ?? 'Nhóm Zalo';

    final groupId = conversation['groupId']?.toString().trim() ?? '';

    final actionBusy =
        groupId.isNotEmpty &&
        (_pinningGroupIds.contains(groupId) ||
            _deletingGroupIds.contains(groupId) ||
            _pendingNotificationValues.containsKey(groupId));

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

                    enabled: !actionBusy,

                    onTap: actionBusy
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();

                            toggleConversationPin(conversation);
                          },
                  ),

                  if (isGroup)
                    ListTile(
                      minLeadingWidth: 34,
                      leading: Icon(
                        notifying
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_active_outlined,
                        size: 27,
                        color: colorScheme.primary,
                      ),
                      title: Text(
                        notifying
                            ? 'Bỏ nhóm khỏi thông báo'
                            : 'Thêm nhóm vào thông báo',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 5,
                      ),
                      enabled: !actionBusy,
                      onTap: actionBusy
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop();
                              _toggleConversationNotifications(conversation);
                            },
                    ),

                  // ========================================
                  // DELETE
                  // ========================================
                  ListTile(
                    minLeadingWidth: 34,

                    leading: Icon(
                      Icons.delete_outline_rounded,

                      size: 28,

                      color: colorScheme.error,
                    ),

                    title: Text(
                      'Xóa',

                      style: TextStyle(
                        fontSize: 18,

                        color: colorScheme.error,

                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,

                      vertical: 5,
                    ),

                    enabled: !actionBusy,

                    onTap: actionBusy
                        ? null
                        : () {
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

    final colorScheme = Theme.of(context).colorScheme;

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
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),

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

    if (_deletingGroupIds.contains(groupId) ||
        _pinningGroupIds.contains(groupId) ||
        _pendingNotificationValues.containsKey(groupId)) {
      return;
    }

    _deletingGroupIds.add(groupId);

    if (mounted) {
      setState(() {});
    }

    try {
      await backend.deleteConversation(groupId: groupId);

      if (!mounted) {
        return;
      }

      setState(() {
        conversations.removeWhere(
          (item) => item['groupId']?.toString().trim() == groupId,
        );
      });

      // ========================================
      // RECONCILE SAU DELETE
      //
      // Neu mot message moi den DUNG LUC delete
      // vua ket thuc, backend co the da unhide
      // conversation lai. Reload nay dam bao UI
      // khong vo tinh xoa mat state moi hon.
      // ========================================

      await loadData(showLoading: false, showError: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa cuộc trò chuyện')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Xóa thất bại: $error')));
    } finally {
      _deletingGroupIds.remove(groupId);

      if (mounted) {
        setState(() {});
      }
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

    final actionBusy =
        groupId.isNotEmpty &&
        (_pinningGroupIds.contains(groupId) ||
            _deletingGroupIds.contains(groupId) ||
            _pendingNotificationValues.containsKey(groupId));

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
    } else if (conversation['type'] != 'user' &&
        sender != null &&
        sender.isNotEmpty) {
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
                  ? ResizeImage.resizeIfNeeded(
                      128,
                      128,
                      NetworkImage(avatar),
                    )
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

                          onPressed: actionBusy
                              ? null
                              : () {
                                  toggleConversationPin(conversation);
                                },

                          icon: actionBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
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

  DateTime? _acceptedTripTime(
    Map<String, dynamic> trip,
  ) {
    final acceptedAt =
        DateTime.tryParse(
          trip['acceptedAt']
                  ?.toString() ??
              '',
        )?.toLocal();

    if (acceptedAt != null) {
      return acceptedAt;
    }

    return DateTime.tryParse(
      trip['receivedAt']
              ?.toString() ??
          '',
    )?.toLocal();
  }


  String _formatHistoryDate(
    DateTime date,
  ) {
    String twoDigits(int value) =>
        value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year}';
  }


  String _formatHistoryDateTime(
    DateTime? date,
  ) {
    if (date == null) {
      return '—';
    }

    String twoDigits(int value) =>
        value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year}  '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }


  List<Map<String, String>> get historyGroupOptions {
    final byId =
        <String, String>{};

    for (final conversation in conversations) {
      final id =
          conversation['groupId']
              ?.toString()
              .trim();

      if (
        id == null ||
        id.isEmpty ||
        !enabledGroupIds.contains(id)
      ) {
        continue;
      }

      byId[id] =
          firstNonEmptyString([
            conversation['name'],
            conversation['groupName'],
          ]) ??
          'Nhóm Zalo';
    }

    for (final trip in acceptedTrips) {
      final id =
          firstNonEmptyString([
        trip['sourceThreadId'],
        trip['groupId'],
        trip['threadId'],
      ]);

      if (
        id == null ||
        id.isEmpty ||
        !enabledGroupIds.contains(id)
      ) {
        continue;
      }

      byId.putIfAbsent(
        id,
        () =>
            firstNonEmptyString([
              trip['groupName'],
              trip['sourceGroupName'],
            ]) ??
            'Nhóm Zalo',
      );
    }

    final result =
        byId.entries
            .map(
              (entry) =>
                  <String, String>{
                'id': entry.key,
                'name': entry.value,
              },
            )
            .toList();

    result.sort(
      (a, b) =>
          (a['name'] ?? '')
              .toLowerCase()
              .compareTo(
                (b['name'] ?? '')
                    .toLowerCase(),
              ),
    );

    return result;
  }


  Widget _historyDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
          ),

          const SizedBox(width: 7),

          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value.isEmpty
                  ? '—'
                  : value,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAcceptedTripCard(
    Map<String, dynamic> trip,
  ) {
    final content =
        trip['content']
                ?.toString() ??
            'Cuốc đã nhận';

    final groupName =
        firstNonEmptyString([
          trip['groupName'],
          trip['sourceGroupName'],
        ]) ??
        'Nhóm Zalo';

    final senderName =
        firstNonEmptyString([
          trip['senderName'],
          trip['senderId'],
        ]) ??
        'Không rõ người gửi';

    final acceptedAt =
        _acceptedTripTime(trip);

    return Card(
      margin:
          const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        12,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () {
          unawaited(
            openAcceptedTrip(trip),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 20,
                  ),

                  const SizedBox(width: 7),

                  const Text(
                    'Đã nhận',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),

                  const Spacer(),

                  Text(
                    _formatHistoryDateTime(
                      acceptedAt,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),

                  const SizedBox(width: 3),

                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              _historyDetailRow(
                icon:
                    Icons.schedule_outlined,
                label: 'Nhận lúc',
                value:
                    _formatHistoryDateTime(
                  acceptedAt,
                ),
              ),

              _historyDetailRow(
                icon:
                    Icons.groups_outlined,
                label: 'Nhóm',
                value: groupName,
              ),

              _historyDetailRow(
                icon:
                    Icons.person_outline,
                label: 'Người gửi',
                value: senderName,
              ),

              _historyDetailRow(
                icon:
                    Icons.flag_outlined,
                label: 'Trạng thái',
                value: 'Đã nhận',
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget buildAcceptedHistory() {
    final items =
        acceptedFiltered;

    return RefreshIndicator(
      onRefresh: () {
        return loadData(
          showLoading: false,
        );
      },
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.only(
          top: 4,
          bottom: 20,
        ),
        children: [
          if (items.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 100,
                left: 32,
                right: 32,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 68,
                  ),

                  SizedBox(height: 16),

                  Text(
                    'Không có cuốc đã nhận',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Thử chọn ngày, nhóm khác hoặc thay đổi nội dung tìm kiếm.',
                    textAlign:
                        TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...items.map(
              _buildAcceptedTripCard,
            ),
        ],
      ),
    );
  }


  List<Map<String, dynamic>> get acceptedFiltered {
    final selectedGroups = historySelectedGroupIds;

    return acceptedTrips.where((trip) {
      final acceptedAt =
          _acceptedTripTime(trip);

      if (acceptedAt == null) {
        return false;
      }

      final from =
          DateTime(
        historyFromDate.year,
        historyFromDate.month,
        historyFromDate.day,
      );

      final toExclusive =
          DateTime(
        historyToDate.year,
        historyToDate.month,
        historyToDate.day,
      ).add(
        const Duration(days: 1),
      );

      if (
        acceptedAt.isBefore(from) ||
        !acceptedAt.isBefore(toExclusive)
      ) {
        return false;
      }

      if (selectedGroups.isNotEmpty) {
        final groupId =
            firstNonEmptyString([
          trip['sourceThreadId'],
          trip['groupId'],
          trip['threadId'],
        ]);

        if (!selectedGroups.contains(groupId)) {
          return false;
        }
      }

      if (searchText.isNotEmpty) {
        final content =
            trip['content']
                    ?.toString()
                    .toLowerCase() ??
                '';

        if (!content.contains(searchText)) {
          return false;
        }
      }

      return true;
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
    realtimeRefreshTimer = null;

    tabController.removeListener(
      _handleTabChanged,
    );

    tabController.dispose();
    searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (loadError != null &&
        conversations.isEmpty &&
        acceptedTrips.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 58),
                const SizedBox(height: 14),
                const Text(
                  'Không thể tải tin nhắn',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    loadData();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          if (!realtimeConnected)
            Material(
              color: realtimeAuthFailed
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (!realtimeAuthFailed)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        realtimeAuthFailed
                            ? 'Phiên realtime không hợp lệ.'
                            : 'Đang kết nối lại realtime...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                      hintText: tabController.index == 2
                          ? 'Tìm theo nội dung cuốc...'
                          : 'Tìm kiếm cuộc trò chuyện...',

                      prefixIcon: const Icon(Icons.search),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed: () => tabController.index == 2
                      ? openHistoryFilters()
                      : openConversationFilters(),

                  tooltip: 'Lọc nhóm',

                  icon: const Icon(Icons.filter_alt, size: 28),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          if (tabController.index != 2) ...[
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

          ],

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
