import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';

import '../../controllers/settings_controller.dart';

import '../../services/backend_service.dart';
import '../../services/speech_service.dart';
import '../../services/audio_service.dart';
import '../../services/app_realtime_service.dart';
import '../../services/backend/subscription_api.dart';
import '../../widgets/quota_exhausted_dialog.dart';

import '../chat/chat_page.dart';
import 'trip_card.dart';
import 'trip_message_target.dart';
import 'home_timer_controller.dart';
import 'home_trip_countdown.dart';
import 'home_trip_reconciler.dart';
import 'home_notification.dart';
import 'home_realtime.dart';

class HomePage extends StatefulWidget {
  final SettingsController settingsController;

  final bool isActive;

  final Future<void> Function() onOpenGroups;

  final VoidCallback onOpenNotificationFilter;

  final VoidCallback onOpenAutoAcceptFilter;


  final AppRealtimeService realtimeService;

  const HomePage({
    super.key,
    this.isActive = true,

    required this.realtimeService,
    required this.onOpenGroups,
    required this.onOpenNotificationFilter,
    required this.onOpenAutoAcceptFilter,
    required this.settingsController,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver {
  // THAY IP NAY BANG IP MAY TINH CUA BAN
  final BackendService backend = BackendService(baseUrl: AppConfig.backendUrl);

  late final HomeNotificationHandler notificationHandler;

  late final HomeRealtimeHandler realtimeHandler;

  final SpeechService speechService = SpeechService.instance;

  final AudioService audioService = AudioService.instance;

  final List<Map<String, dynamic>> activeTrips = [];

  final HomeTimerController _timers = HomeTimerController();
  // The ticking display is separate from the Home page and quota counters.
  final ValueNotifier<int> _countdownVersion = ValueNotifier<int>(0);
  final SubscriptionGateway subscriptionApi = createSubscriptionApi();
  Map<String, dynamic>? quotaOverview;
  bool quotaLoading = false;
  bool _openingTripMessage = false;

  Future<void> loadQuota() async {
    if (quotaLoading || !mounted) return;
    quotaLoading = true;
    try {
      final result = await subscriptionApi.overview();
      if (mounted) setState(() => quotaOverview = result);
    } catch (error) {
      debugPrint('HOME QUOTA ERROR: $error');
    } finally {
      quotaLoading = false;
    }
  }

  String quotaLabel(String feature) {
    final sub = subscriptionMap(quotaOverview?['subscription']);
    for (final row in subscriptionRows(sub['features'])) {
      if (row['feature'] != feature) continue;
      if (row['limit'] == null && row['allowed'] == true) return '∞';
      final limit = (row['limit'] as num?)?.toInt() ?? 0;
      final remaining = (row['remaining'] as num?)?.toInt() ?? 0;
      return '${remaining.clamp(0, limit)}/$limit';
    }
    return '0';
  }


  int enabledGroupCount = 0;
  int totalGroupCount = 0;

  int notificationFilterCount = 0;

  String connectionStatus = 'Đang kết nối backend...';

  String? messageId;

  String? senderId;
  String? senderName;

  String? groupId;
  String? groupName;

  String? message;

  bool accepting = false;
  bool accepted = false;

  bool notificationInitialized = false;

  Future<void>? _reconcileFuture;

  bool _reconcilePending = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    speechService.initialize();

    loadHomeSummary();
    unawaited(loadQuota());
    _syncVisibleHomeTimers();

    notificationHandler = HomeNotificationHandler(
      settingsController: widget.settingsController,

      backend: backend,

      audioService: audioService,

      speechService: speechService,
    );

    realtimeHandler = HomeRealtimeHandler(
      realtimeService: widget.realtimeService,

      onAuthenticated: () {
        if (!mounted) {
          return;
        }

        setState(() {
          connectionStatus = 'Đã kết nối realtime';
        });

        unawaited(
          _reconcileActiveTrips(),
        );
      },

      onAuthError: () {
        if (!mounted) {
          return;
        }

        setState(() {
          connectionStatus = 'Xác thực realtime thất bại';
        });
      },

      onNewTrip: (data) {
        if (!mounted) {
          return;
        }

        final added =
            addTrip(data);

        if (!added) {
          return;
        }

        // Uu tien ve TripCard truoc.
        // AudioPlayer/TTS dung platform channel va co the
        // khoi tao MediaPlayer; neu chay ngay sau setState
        // no se chen vao critical path truoc frame moi.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          unawaited(
            notificationHandler
                .handleTripNotificationSpeech(
              data,
            ),
          );
        });
      },

      onTripAccepted: (messageId) {
        _applyRealtimeTripStatus(
          messageId,
          'accepted',
          const Duration(milliseconds: 1500),
        );
      },

      onTripIgnored: (messageId) {
        _applyRealtimeTripStatus(
          messageId,
          'ignored',
          const Duration(milliseconds: 1000),
        );
      },

      onConnectionError: () {
        if (!mounted) {
          return;
        }

        setState(() {
          connectionStatus = 'Đang kết nối lại...';
        });
      },

      onConnectionDone: () {
        if (!mounted) {
          return;
        }

        setState(() {
          connectionStatus = 'Kết nối realtime đã dừng';
        });
      },
    );

    realtimeHandler.start();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    super.didChangeAppLifecycleState(
      state,
    );

    if (state != AppLifecycleState.resumed) {
      // Keep realtime listeners installed, but stop periodic UI work while
      // Android pauses or hides this app.
      _syncVisibleHomeTimers();
      return;
    }

    _syncVisibleHomeTimers();
    if (_canRunVisibleHomeTimers) {
      unawaited(loadQuota());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canRunVisibleHomeTimers) _tickTripCountdowns();
      });
    }

    // Neu stream tung dung vi lifecycle/he thong,
    // start() la idempotent.
    widget.realtimeService.start();

    unawaited(
      _reconcileActiveTrips(),
    );
  }


  Future<void> _reconcileActiveTrips() {
    _reconcilePending = true;

    final running =
        _reconcileFuture;

    if (running != null) {
      return running;
    }

    final future =
        _drainTripReconcile();

    _reconcileFuture =
        future;

    return future;
  }


  Future<void> _drainTripReconcile() async {
    try {
      while (
        _reconcilePending &&
        mounted
      ) {
        _reconcilePending =
            false;

        await _reconcileActiveTripsOnce();
      }
    } finally {
      _reconcileFuture =
          null;
    }
  }


  Future<void> _reconcileActiveTripsOnce() async {
    final displaySeconds =
        widget.settingsController.settings.tripDisplaySeconds;
    final reconcileStartedAtMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final pending = await backend.getRecentPendingTrips(
        displaySeconds: displaySeconds,
      );
      if (!mounted) return;

      setState(() {
        HomeTripReconciler.apply(
          activeTrips: activeTrips,
          pending: pending,
          displaySeconds: displaySeconds,
          reconcileStartedAtMs: reconcileStartedAtMs,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        );
      });

      // Reconciliation restores visible cards only; it never replays sounds
      // or notification side effects for messages fetched from the server.
      _ensureTripCountdownTimer();
      _stopTripCountdownTimerIfIdle();
    } catch (error) {
      debugPrint('HOME TRIP RECONCILE ERROR: $error');
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (notificationInitialized) {
      return;
    }

    notificationInitialized = true;

    unawaited(
      notificationHandler.initialize(context).catchError((Object error) {
        debugPrint(
          'HOME NOTIFICATION INIT ERROR: '
          '$error',
        );
      }),
    );
  }

  bool get _hasCountdownTrips =>
      HomeTripCountdown.hasCountdownTrips(activeTrips);

  bool get _canRunVisibleHomeTimers {
    final state = WidgetsBinding.instance.lifecycleState;
    return widget.isActive &&
        (state == null || state == AppLifecycleState.resumed);
  }

  void _syncVisibleHomeTimers() {
    _timers.setVisibleWork(
      visible: mounted && _canRunVisibleHomeTimers,
      hasCountdownTrips: _hasCountdownTrips,
      onQuotaRefresh: () => unawaited(loadQuota()),
      onCountdownTick: _tickTripCountdowns,
    );
  }

  void _ensureTripCountdownTimer() {
    if (mounted) _syncVisibleHomeTimers();
  }

  void _stopTripCountdownTimerIfIdle() {
    if (mounted) _syncVisibleHomeTimers();
  }

  void _pauseTripCountdown(Map<String, dynamic> trip) {
    HomeTripCountdown.pause(
      trip,
      displaySeconds: widget.settingsController.settings.tripDisplaySeconds,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _resumeTripCountdown(Map<String, dynamic> trip) {
    HomeTripCountdown.resume(
      trip,
      displaySeconds: widget.settingsController.settings.tripDisplaySeconds,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _tickTripCountdowns() {
    if (!mounted || !_canRunVisibleHomeTimers) {
      _timers.stopCountdown();
      return;
    }

    if (!_hasCountdownTrips) {
      _stopTripCountdownTimerIfIdle();
      return;
    }

    final tick = HomeTripCountdown.tick(
      activeTrips,
      displaySeconds: widget.settingsController.settings.tripDisplaySeconds,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );

    // Updating only the badge avoids rebuilding Home every second.
    // A changed list still needs setState to remove expired trip cards.
    if (tick.hasExpired) {
      setState(() => activeTrips.removeWhere(tick.expiredTrips.contains));
    } else if (tick.countdownChanged) {
      _countdownVersion.value += 1;
    }

    _stopTripCountdownTimerIfIdle();
  }

  void _applyRealtimeTripStatus(
    String messageId,
    String status,
    Duration visibleDuration,
  ) {
    if (!mounted) {
      return;
    }

    final index =
        activeTrips.indexWhere(
      (trip) =>
          trip['id']
              ?.toString() ==
          messageId,
    );


    if (index < 0) {
      return;
    }


    setState(() {
      activeTrips[index]['_uiStatus'] =
          status;

      activeTrips[index]['_expiresAtMs'] =
          null;

      activeTrips[index]['_pausedRemainingMs'] =
          null;
    });


    _stopTripCountdownTimerIfIdle();


    Future<void>.delayed(
      visibleDuration,
      () {
        if (!mounted) {
          return;
        }

        removeTrip(
          messageId,
        );
      },
    );
  }


  Future<void> acceptTrip(Map<String, dynamic> trip) async {
    final tripId = trip['id']?.toString();

    if (tripId == null || tripId.isEmpty) {
      return;
    }

    final currentStatus = trip['_uiStatus']?.toString();

    if (currentStatus == 'accepting' ||
        currentStatus == 'ignoring' ||
        currentStatus == 'accepted') {
      return;
    }

    setState(() {
      _pauseTripCountdown(
        trip,
      );

      trip['_uiStatus'] = 'accepting';
    });

    _stopTripCountdownTimerIfIdle();

    try {
      final response = await backend.acceptMessage(
        tripId,

        replyText: widget.settingsController.settings.acceptReplyText,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        trip['_uiStatus'] = 'accepted';
      });

      unawaited(loadQuota());
      removeTrip(tripId);
      await _openAcceptedMessage(trip, response);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        trip['_uiStatus'] = 'new';

        _resumeTripCountdown(
          trip,
        );
      });

      _ensureTripCountdownTimer();

      if (isQuotaExhausted(error)) {
        unawaited(loadQuota());
        await showQuotaExhaustedDialog(context);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không thể nhận cuốc: $error')));
      }
    }
  }

  void startTripReply(Map<String, dynamic> trip) {
    if (trip['_uiStatus'] != 'new' || trip['_replying'] == true) return;
    setState(() {
      for (final other in activeTrips) {
        if (other['_replying'] == true) {
          other['_replying'] = false;
          _resumeTripCountdown(other);
        }
      }
      _pauseTripCountdown(trip);
      trip['_replying'] = true;
    });
  }

  void cancelTripReply(Map<String, dynamic> trip) {
    if (trip['_replying'] != true) return;
    setState(() {
      trip['_replying'] = false;
      _resumeTripCountdown(trip);
    });
    _ensureTripCountdownTimer();
  }

  /// Open the original Zalo message without accepting the trip or using quota.
  Future<void> openTripMessage(Map<String, dynamic> trip) async {
    if (!mounted || _openingTripMessage) {
      return;
    }

    final target = TripMessageTarget.fromTrip(trip);
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy tin nhắn gốc của cuốc này.'),
        ),
      );
      return;
    }

    _openingTripMessage = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            realtimeService: widget.realtimeService,
            groupId: target.groupId,
            groupName: target.groupName,
            groupAvatar: null,
            targetMsgId: target.msgId,
            targetCliMsgId: target.cliMsgId,
          ),
        ),
      );
    } finally {
      _openingTripMessage = false;
    }
  }

  Future<void> _openAcceptedMessage(
    Map<String, dynamic> trip,
    Map<String, dynamic> response,
  ) async {
    if (!mounted) return;
    final accepted = response['message'] is Map
        ? Map<String, dynamic>.from(response['message'] as Map)
        : response;
    final targetMsgId = (accepted['replyZaloMessageId'] ?? '').toString().trim();
    final targetCliMsgId =
        (accepted['replyZaloCliMessageId'] ?? '').toString().trim();
    final groupId = (accepted['sourceThreadId'] ??
            accepted['groupId'] ??
            trip['groupId'] ??
            '').toString().trim();
    if (groupId.isEmpty || (targetMsgId.isEmpty && targetCliMsgId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã nhận cuốc nhưng chưa xác định được tin nhắn trả lời')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          realtimeService: widget.realtimeService,
          groupId: groupId,
          groupName: (trip['groupName'] ?? 'Nhóm Zalo').toString(),
          groupAvatar: null,
          targetMsgId: targetMsgId.isEmpty ? null : targetMsgId,
          targetCliMsgId: targetCliMsgId.isEmpty ? null : targetCliMsgId,
        ),
      ),
    );
  }

  Future<bool> sendTripReply(Map<String, dynamic> trip, String text) async {
    final tripId = trip['id']?.toString().trim() ?? '';
    if (tripId.isEmpty) return false;
    try {
      // Use the accept endpoint so the reply is recorded in accepted history.
      final response = await backend.acceptMessage(tripId, replyText: text);
      if (!mounted) return true;
      setState(() {
        trip['_replying'] = false;
        trip['_uiStatus'] = 'replied';
      });
      _stopTripCountdownTimerIfIdle();
      removeTrip(tripId);
      await _openAcceptedMessage(trip, response);
      return true;
    } catch (error) {
      if (mounted) {
        if (isQuotaExhausted(error)) {
          unawaited(loadQuota());
          await showQuotaExhaustedDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể nhận cuốc: $error')),
          );
        }
      }
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;

    // IndexedStack keeps Home mounted. Stop only timers, not realtime,
    // so trips and their notifications are still received on other tabs.
    _syncVisibleHomeTimers();

    if (_canRunVisibleHomeTimers) {
      unawaited(loadHomeSummary());
      unawaited(loadQuota());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canRunVisibleHomeTimers) _tickTripCountdowns();
      });
    }
  }

  Future<void> loadHomeSummary() async {
    try {
      final groups = await backend.getGroups();

      final filters = await backend.getNotificationFilters();

      if (!mounted) {
        return;
      }

      setState(() {
        totalGroupCount = groups.length;

        enabledGroupCount = groups
            .where((group) => group['enabled'] == true)
            .length;

        notificationFilterCount = filters
            .where((filter) => filter['enabled'] != false)
            .length;
      });
    } catch (error) {
      debugPrint('HOME SUMMARY ERROR: $error');
    }
  }

  Future<void> openGroups() async {
    await widget.onOpenGroups();

    if (!mounted) {
      return;
    }

    await loadHomeSummary();
  }

  Future<void> ignoreTrip(Map<String, dynamic> trip) async {
    final tripId = trip['id']?.toString();

    if (tripId == null || tripId.isEmpty) {
      return;
    }

    final currentStatus = trip['_uiStatus']?.toString();

    if (currentStatus == 'accepting' || currentStatus == 'ignoring') {
      return;
    }

    setState(() {
      _pauseTripCountdown(
        trip,
      );

      trip['_uiStatus'] = 'ignoring';
    });

    _stopTripCountdownTimerIfIdle();

    try {
      await backend.ignoreMessage(tripId);

      if (!mounted) {
        return;
      }

      setState(() {
        trip['_uiStatus'] = 'ignored';
      });

      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) {
        return;
      }

      removeTrip(tripId);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        trip['_uiStatus'] = 'new';

        _resumeTripCountdown(
          trip,
        );
      });

      _ensureTripCountdownTimer();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể bỏ qua cuốc: $error')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    _reconcilePending =
        false;

    realtimeHandler.dispose();

    notificationHandler.dispose();

    _timers.dispose();
    _countdownVersion.dispose();

    super.dispose();
  }

  int? _traceInt(
    Map<String, dynamic> trace,
    String key,
  ) {
    final value = trace[key];

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    );
  }
  double? _traceDouble(
    Map<String, dynamic> trace,
    String key,
  ) {
    final value = trace[key];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  void _logTripLatencyAfterRender(
    Map<String, dynamic> trip,
  ) {
    final rawTrace =
        trip['_latencyTrace'];

    if (rawTrace is! Map) {
      return;
    }

    final trace =
        Map<String, dynamic>.from(
      rawTrace,
    );

    final traceId =
        trace['traceId']?.toString() ?? '';

    final listener =
        _traceInt(
      trace,
      'listenerReceivedAtMs',
    );

    final wsBroadcast =
        _traceInt(
      trace,
      'wsBroadcastAtMs',
    );

    final listenerPerf =
        _traceDouble(
      trace,
      'listenerPerfMs',
    );

    final filterPerf =
        _traceDouble(
      trace,
      'filterPerfMs',
    );

    final dedupePerf =
        _traceDouble(
      trace,
      'dedupePerfMs',
    );

    final tripPerf =
        _traceDouble(
      trace,
      'tripPerfMs',
    );

    final wsPerf =
        _traceDouble(
      trace,
      'wsBroadcastPerfMs',
    );

    final socketDecodedAt =
        _traceInt(
      trace,
      'flutterSocketDecodedAtMs',
    );

    final appRealtimeAt =
        _traceInt(
      trace,
      'flutterAppRealtimeAtMs',
    );

    final homeReceivedAt =
        _traceInt(
      trace,
      'flutterHomeReceivedAtMs',
    );

    final renderedAt =
        DateTime.now()
            .millisecondsSinceEpoch;

    int? diff(
      int? end,
      int? start,
    ) {
      if (
        end == null ||
        start == null
      ) {
        return null;
      }

      return end - start;
    }

    String backendUs(
      double? end,
      double? start,
    ) {
      if (
        end == null ||
        start == null
      ) {
        return '-';
      }

      return (
        (end - start) *
        1000
      ).toStringAsFixed(1);
    }

    final listenerToFilterUs =
        backendUs(
      filterPerf,
      listenerPerf,
    );

    final filterToDedupeUs =
        backendUs(
      dedupePerf,
      filterPerf,
    );

    final dedupeToStoreUs =
        backendUs(
      tripPerf,
      dedupePerf,
    );

    final storeToWsUs =
        backendUs(
      wsPerf,
      tripPerf,
    );

    final socketToBus =
        diff(
      appRealtimeAt,
      socketDecodedAt,
    );

    final busToHome =
        diff(
      homeReceivedAt,
      appRealtimeAt,
    );

    final homeToRender =
        diff(
      renderedAt,
      homeReceivedAt,
    );

    final flutterInternal =
        diff(
      renderedAt,
      socketDecodedAt,
    );

    final transportApprox =
        diff(
      socketDecodedAt,
      wsBroadcast,
    );

    final totalApprox =
        diff(
      renderedAt,
      listener,
    );

    final networkText =
        transportApprox != null &&
                transportApprox >= 0
            ? '${transportApprox}ms'
            : 'clock-skew';

    final totalText =
        totalApprox != null &&
                totalApprox >= 0
            ? '${totalApprox}ms'
            : 'clock-skew';

    debugPrint(
      '[LATENCY] '
      'trace=$traceId '
      'backend.filter=${listenerToFilterUs}us '
      'backend.dedupe=${filterToDedupeUs}us '
      'backend.store=${dedupeToStoreUs}us '
      'backend.ws=${storeToWsUs}us '
      'network~=$networkText '
      'flutter.socketToBus=${socketToBus ?? '-'}ms '
      'flutter.busToHome=${busToHome ?? '-'}ms '
      'flutter.homeToRender=${homeToRender ?? '-'}ms '
      'flutter.internal=${flutterInternal ?? '-'}ms '
      'total~=$totalText',
    );
  }
  bool addTrip(Map<String, dynamic> trip) {
    final tripId = trip['id']?.toString();

    if (tripId == null || tripId.isEmpty) {
      return false;
    }

    // ========================================
    // KHONG THEM TRUNG CUOC
    // ========================================

    final existed = activeTrips.any((item) => item['id']?.toString() == tripId);

    if (existed) {
      return false;
    }

    final newTrip = Map<String, dynamic>.from(trip);

    // Trang thai rieng cho UI.
    newTrip['_uiStatus'] = 'new';

    newTrip['_addedAtMs'] =
        DateTime.now()
            .millisecondsSinceEpoch;

    // ========================================
    // COUNTDOWN RIENG CUA CUOC
    // ========================================
    final displaySeconds =
        widget.settingsController.settings.tripDisplaySeconds;

    newTrip['_remainingSeconds'] =
        displaySeconds;

    newTrip['_expiresAtMs'] =
        DateTime.now()
                .millisecondsSinceEpoch +
            displaySeconds *
                1000;

    newTrip['_pausedRemainingMs'] =
        null;

    setState(() {
      // ADD CUOI DANH SACH
      // → cuoc moi nam ben duoi
      activeTrips.add(newTrip);
    });

    if (newTrip['_latencyTrace'] is Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _logTripLatencyAfterRender(
          newTrip,
        );
      });
    }

    _ensureTripCountdownTimer();

    return true;
  }

  void removeTrip(String tripId) {
    if (!mounted) {
      return;
    }

    setState(() {
      activeTrips.removeWhere((trip) => trip['id']?.toString() == tripId);
    });

    _stopTripCountdownTimerIfIdle();
  }

  Widget homeSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

        child: Row(
          children: [
            // ========================================
            // ICON
            // ========================================

            Container(
              width: 54,
              height: 54,

              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,

                borderRadius: BorderRadius.circular(16),
              ),

              child: Icon(icon, color: colorScheme.primary, size: 28),
            ),

            const SizedBox(width: 16),

            // ========================================
            // TEXT
            // ========================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,

                    style: TextStyle(
                      fontSize: 13,

                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (trailingText != null) ...[
              const SizedBox(width: 10),

              Text(
                trailingText,

                style: TextStyle(fontSize: 16, color: colorScheme.primary),
              ),
            ],

            const SizedBox(width: 6),

            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshHome() async {
    await Future.wait<void>([
      loadHomeSummary(),
      loadQuota(),
      _reconcileActiveTrips(),
    ]);
  }

  Widget buildIdleHome() {
    final colorScheme = Theme.of(context).colorScheme;

    String notificationFilterText;

    if (notificationFilterCount == 0) {
      notificationFilterText = 'Chưa có bộ lọc nào đang hoạt động';
    } else {
      notificationFilterText =
          '$notificationFilterCount bộ lọc đang hoạt động';
    }

    return RefreshIndicator(
      onRefresh: _refreshHome,
      child: SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),

        child: Column(
          children: [
            // ========================================
            // TOP COUNTERS
            // LUON LUON HIEN
            // ========================================

            Row(
              children: [
                Icon(Icons.touch_app_outlined, color: colorScheme.primary),

                const SizedBox(width: 8),

                Text(quotaLabel('trip_screen_accept'), key: const ValueKey('home-trip-screen-quota'), style: const TextStyle(fontSize: 17)),

                const SizedBox(width: 28),

                Icon(Icons.chat_bubble_outline, color: colorScheme.primary),

                const SizedBox(width: 8),

                Text(quotaLabel('chat_accept'), key: const ValueKey('home-chat-quota'), style: const TextStyle(fontSize: 17)),

                const Spacer(),

                TextButton(
                  onPressed: () {
                    // Upgrade se lam sau.
                  },

                  child: const Text('Nâng cấp'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            const Divider(height: 1),

            const SizedBox(height: 18),

            // ========================================
            // KHONG CO CUOC
            // ========================================
            if (activeTrips.isEmpty) ...[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: SizedBox(
                        height: constraints.maxHeight < 480 ? 480 : constraints.maxHeight,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: connectionStatus == 'Đã kết nối realtime'
                                ? Colors.green
                                : connectionStatus == 'Đang kết nối lại...'
                                    ? Colors.amber
                                    : connectionStatus == 'Xác thực realtime thất bại'
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          connectionStatus == 'Đã kết nối realtime'
                              ? 'Đang lắng nghe'
                              : connectionStatus,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                            ),
                            Align(
                              alignment: const Alignment(0, -0.2),
                              child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          homeSettingItem(
                            icon: Icons.notifications_none,
                            title: 'Nhóm nhận thông báo',
                            subtitle: 'Chỉ cuốc từ nhóm đã bật mới hiện ở đây',
                            trailingText: '$enabledGroupCount/$totalGroupCount',
                            onTap: openGroups,
                          ),
                          const Divider(height: 1),
                          homeSettingItem(
                            icon: Icons.tune,
                            title: 'Bộ lọc thông báo',
                            subtitle: notificationFilterText,
                            onTap: widget.onOpenNotificationFilter,
                          ),
                          const Divider(height: 1),
                          homeSettingItem(
                            icon: Icons.bolt,
                            title: 'Bộ lọc tự động nhận',
                            subtitle: 'Chưa bật bộ lọc nào — không cuốc nào được tự nhận',
                            onTap: widget.onOpenAutoAcceptFilter,
                          ),
                        ],
                      ),
                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // ========================================
              // CO CUOC
              //
              // KHONG HIEN:
              // - DANG LANG NGHE
              // - NHOM NHAN THONG BAO
              // - BO LOC THONG BAO
              // - BO LOC TU DONG NHAN
              //
              // CHI HIEN DANH SACH CUOC
              // ========================================

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),

                  physics: const AlwaysScrollableScrollPhysics(),

                  itemCount: activeTrips.length,

                  itemBuilder: (context, index) {
                    final trip = activeTrips[index];
                    return TripCard(
                      key: ValueKey('trip-${trip['id']}'),
                      trip: trip,
                      countdownRefresh: _countdownVersion,

                      settingsController: widget.settingsController,

                      onAccept: () {
                        acceptTrip(trip);
                      },

                      onIgnore: () {
                        ignoreTrip(trip);
                      },
                      onOpenMessage: () {
                        unawaited(openTripMessage(trip));
                      },
                      onSwipeReply: () => startTripReply(trip),
                      onCancelReply: () => cancelTripReply(trip),
                      onSendReply: (text) => sendTripReply(trip, text),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildIdleHome();
  }
}
