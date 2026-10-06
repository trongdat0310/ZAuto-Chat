import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';

import '../../controllers/settings_controller.dart';

import '../../services/backend_service.dart';
import '../../services/speech_service.dart';
import '../../services/audio_service.dart';
import '../../services/app_realtime_service.dart';

import 'trip_card.dart';
import 'home_notification.dart';
import 'home_realtime.dart';

class HomePage extends StatefulWidget {
  final SettingsController settingsController;

  final Future<void> Function() onOpenGroups;

  final VoidCallback onOpenNotificationFilter;

  final VoidCallback onOpenAutoAcceptFilter;

  final AppRealtimeService realtimeService;

  const HomePage({
    super.key,

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

  Timer? tripCountdownTimer;

  int enabledGroupCount = 0;
  int totalGroupCount = 0;

  bool filterActive = false;
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

    if (
      state !=
      AppLifecycleState.resumed
    ) {
      return;
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

    final reconcileStartedAtMs =
        DateTime.now()
            .millisecondsSinceEpoch;

    try {
      final pending =
          await backend.getRecentPendingTrips(
        displaySeconds:
            displaySeconds,
      );

      if (!mounted) {
        return;
      }


      final nowMs =
          DateTime.now()
              .millisecondsSinceEpoch;


      final pendingById =
          <String, Map<String, dynamic>>{};


      for (
        final incoming in pending
      ) {
        final id =
            incoming['id']
                ?.toString()
                .trim() ??
            '';

        if (id.isEmpty) {
          continue;
        }

        pendingById[id] =
            incoming;
      }


      setState(() {
        // Cuoc local dang NEW nhung backend khong con
        // pending/hoac da het cua so hien thi -> bo.
        // Cuoc dang accepting/ignoring giu nguyen
        // cho request local ket thuc.
        activeTrips.removeWhere(
          (trip) {
            final status =
                trip['_uiStatus']
                    ?.toString() ??
                'new';

            if (
              status ==
                  'accepting' ||
              status ==
                  'ignoring' ||
              status ==
                  'accepted' ||
              status ==
                  'ignored'
            ) {
              return false;
            }

            final addedAtMs =
                trip['_addedAtMs'];

            if (
              addedAtMs is int &&
              addedAtMs >
                  reconcileStartedAtMs
            ) {
              return false;
            }

            final id =
                trip['id']
                    ?.toString()
                    .trim() ??
                '';

            return (
              id.isEmpty ||
              !pendingById.containsKey(
                id,
              )
            );
          },
        );


        for (
          final entry
          in pendingById.entries
        ) {
          final id =
              entry.key;

          final incoming =
              entry.value;

          final remainingMs =
              incoming['_reconcileRemainingMs'];

          if (
            remainingMs is! int ||
            remainingMs <=
                0
          ) {
            continue;
          }


          final existingIndex =
              activeTrips.indexWhere(
            (trip) =>
                trip['id']
                    ?.toString() ==
                id,
          );


          if (
            existingIndex >=
            0
          ) {
            final existing =
                activeTrips[
                    existingIndex];

            final status =
                existing['_uiStatus']
                    ?.toString() ??
                'new';


            // Khong pha state cua request dang chay.
            if (
              status ==
                  'accepting' ||
              status ==
                  'ignoring' ||
              status ==
                  'accepted' ||
              status ==
                  'ignored'
            ) {
              continue;
            }


            existing.addAll(
              incoming,
            );

            existing['_uiStatus'] =
                'new';

            existing['_expiresAtMs'] =
                nowMs +
                remainingMs;

            existing['_pausedRemainingMs'] =
                null;

            existing['_remainingSeconds'] =
                (
                  (remainingMs + 999) ~/
                  1000
                ).clamp(
                  0,
                  displaySeconds,
                ).toInt();

            continue;
          }


          final restored =
              Map<String, dynamic>.from(
            incoming,
          );

          restored['_uiStatus'] =
              'new';

          restored['_addedAtMs'] =
              nowMs;

          restored['_expiresAtMs'] =
              nowMs +
              remainingMs;

          restored['_pausedRemainingMs'] =
              null;

          restored['_remainingSeconds'] =
              (
                (remainingMs + 999) ~/
                1000
              ).clamp(
                0,
                displaySeconds,
              ).toInt();


          // Reconcile KHONG phat lai notification/audio.
          // User co the da nhan push khi app background.
          activeTrips.add(
            restored,
          );
        }
      });


      _ensureTripCountdownTimer();

      _stopTripCountdownTimerIfIdle();

    } catch (error) {
      debugPrint(
        'HOME TRIP RECONCILE ERROR: $error',
      );
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

  bool get _hasCountdownTrips {
    return activeTrips.any((trip) {
      final status = trip['_uiStatus']?.toString() ?? 'new';

      return status == 'new';
    });
  }

  void _ensureTripCountdownTimer() {
    if (!mounted || tripCountdownTimer != null || !_hasCountdownTrips) {
      return;
    }

    tripCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickTripCountdowns();
    });
  }

  void _stopTripCountdownTimerIfIdle() {
    if (_hasCountdownTrips) {
      return;
    }

    tripCountdownTimer?.cancel();

    tripCountdownTimer = null;
  }

  int _remainingSecondsForTrip(
    Map<String, dynamic> trip,
  ) {
    final pausedMs =
        trip['_pausedRemainingMs'];

    if (pausedMs is int) {
      return (
        (pausedMs + 999) ~/
        1000
      ).clamp(
        0,
        widget.settingsController.settings.tripDisplaySeconds,
      ).toInt();
    }


    final expiresAtMs =
        trip['_expiresAtMs'];

    if (expiresAtMs is! int) {
      return trip['_remainingSeconds'] is int
          ? trip['_remainingSeconds'] as int
          : widget.settingsController.settings.tripDisplaySeconds;
    }


    final remainingMs =
        expiresAtMs -
        DateTime.now()
            .millisecondsSinceEpoch;


    if (remainingMs <= 0) {
      return 0;
    }


    return (
      (remainingMs + 999) ~/
      1000
    ).clamp(
      0,
      widget.settingsController.settings.tripDisplaySeconds,
    ).toInt();
  }


  void _pauseTripCountdown(
    Map<String, dynamic> trip,
  ) {
    final expiresAtMs =
        trip['_expiresAtMs'];

    if (expiresAtMs is int) {
      final remainingMs =
          expiresAtMs -
          DateTime.now()
              .millisecondsSinceEpoch;

      trip['_pausedRemainingMs'] =
          remainingMs > 0
              ? remainingMs
              : 0;
    } else {
      final remainingSeconds =
          trip['_remainingSeconds'] is int
              ? trip['_remainingSeconds'] as int
              : widget.settingsController.settings.tripDisplaySeconds;

      trip['_pausedRemainingMs'] =
          remainingSeconds *
          1000;
    }

    trip['_expiresAtMs'] =
        null;
  }


  void _resumeTripCountdown(
    Map<String, dynamic> trip,
  ) {
    final pausedMs =
        trip['_pausedRemainingMs'];

    final remainingMs =
        pausedMs is int
            ? pausedMs
            : widget.settingsController.settings.tripDisplaySeconds *
                1000;


    trip['_pausedRemainingMs'] =
        null;

    trip['_expiresAtMs'] =
        DateTime.now()
                .millisecondsSinceEpoch +
            remainingMs;

    trip['_remainingSeconds'] =
        (
          (remainingMs + 999) ~/
          1000
        ).clamp(
          0,
          widget.settingsController.settings.tripDisplaySeconds,
        ).toInt();
  }


  void _tickTripCountdowns() {
    if (!mounted) {
      tripCountdownTimer?.cancel();

      tripCountdownTimer = null;

      return;
    }

    if (!_hasCountdownTrips) {
      _stopTripCountdownTimerIfIdle();

      return;
    }

    setState(() {
      for (final trip in activeTrips) {
        final status = trip['_uiStatus']?.toString() ?? 'new';

        if (status != 'new') {
          continue;
        }

        trip['_remainingSeconds'] =
            _remainingSecondsForTrip(
          trip,
        );
      }

      activeTrips.removeWhere((trip) {
        final status = trip['_uiStatus']?.toString() ?? 'new';

        if (status != 'new') {
          return false;
        }

        return _remainingSecondsForTrip(
              trip,
            ) <=
            0;
      });
    });

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
      await backend.acceptMessage(
        tripId,

        replyText: widget.settingsController.settings.acceptReplyText,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        trip['_uiStatus'] = 'accepted';
      });

      // ========================================
      // CHO NGUOI DUNG THAY "DA NHAN"
      // ROI MOI BIEN MAT
      // ========================================

      await Future.delayed(const Duration(milliseconds: 1500));

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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không thể nhận cuốc: $error')));
    }
  }

  Future<void> loadHomeSummary() async {
    try {
      final groups = await backend.getGroups();

      final filters = await backend.getFilters();

      if (!mounted) {
        return;
      }

      final includeKeywords = filters['includeKeywords'];

      setState(() {
        totalGroupCount = groups.length;

        enabledGroupCount = groups
            .where((group) => group['enabled'] == true)
            .length;

        filterActive = filters['enabled'] == true;

        notificationFilterCount = includeKeywords is List
            ? includeKeywords.length
            : 0;
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

    tripCountdownTimer?.cancel();

    tripCountdownTimer = null;

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

  Widget buildIdleHome() {
    final colorScheme = Theme.of(context).colorScheme;

    String notificationFilterText;

    if (!filterActive || notificationFilterCount == 0) {
      notificationFilterText = 'Chưa bật bộ lọc nào — mọi cuốc đều hiện';
    } else {
      notificationFilterText =
          '$notificationFilterCount điều kiện lọc đang hoạt động';
    }

    return SafeArea(
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

                const Text('0/0', style: TextStyle(fontSize: 17)),

                const SizedBox(width: 28),

                Icon(Icons.chat_bubble_outline, color: colorScheme.primary),

                const SizedBox(width: 8),

                const Text('0/0', style: TextStyle(fontSize: 17)),

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
              // ----------------------------------------
              // DANG LANG NGHE
              // ----------------------------------------

              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,

                      color: connectionStatus == 'Đã kết nối realtime'
                          ? colorScheme.primary
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

              // ----------------------------------------
              // KHOANG TRONG
              // ----------------------------------------
              const Spacer(),

              // ========================================
              // SETTINGS
              // CHI HIEN KHI KHONG CO CUOC
              // ========================================
              Card(
                clipBehavior: Clip.antiAlias,

                child: Column(
                  children: [
                    // ==================================
                    // NHOM NHAN THONG BAO
                    // ==================================

                    homeSettingItem(
                      icon: Icons.notifications_none,

                      title: 'Nhóm nhận thông báo',

                      subtitle: 'Chỉ cuốc từ nhóm đã bật mới hiện ở đây',

                      trailingText: '$enabledGroupCount/$totalGroupCount',

                      onTap: openGroups,
                    ),

                    const Divider(height: 1),

                    // ==================================
                    // BO LOC THONG BAO
                    // ==================================
                    homeSettingItem(
                      icon: Icons.tune,

                      title: 'Bộ lọc thông báo',

                      subtitle: notificationFilterText,

                      onTap: widget.onOpenNotificationFilter,
                    ),

                    const Divider(height: 1),

                    // ==================================
                    // TU DONG NHAN
                    // ==================================
                    homeSettingItem(
                      icon: Icons.bolt,

                      title: 'Bộ lọc tự động nhận',

                      subtitle:
                          'Chưa bật bộ lọc nào — không cuốc nào được tự nhận',

                      onTap: widget.onOpenAutoAcceptFilter,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),
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
                    return TripCard(
                      trip: activeTrips[index],

                      settingsController: widget.settingsController,

                      onAccept: () {
                        acceptTrip(activeTrips[index]);
                      },

                      onIgnore: () {
                        ignoreTrip(activeTrips[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildIdleHome();
  }
}
