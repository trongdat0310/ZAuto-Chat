import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';

import '../../controllers/settings_controller.dart';

import '../../services/backend_service.dart';
import '../../services/speech_service.dart';
import '../../services/audio_service.dart';

import 'trip_card.dart';
import 'home_notification.dart';
import 'home_realtime.dart';

class HomePage
    extends StatefulWidget {

  final SettingsController settingsController;

  final Future<void> Function()onOpenGroups;

  final VoidCallback onOpenNotificationFilter;

  final VoidCallback onOpenAutoAcceptFilter;


  const HomePage({
    super.key,

    required this.onOpenGroups,
    required this.onOpenNotificationFilter,
    required this.onOpenAutoAcceptFilter,
    required this.settingsController,
  });


  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // THAY IP NAY BANG IP MAY TINH CUA BAN
  final BackendService backend =
  BackendService(
    baseUrl: AppConfig.backendUrl,
  );

  late final HomeNotificationHandler notificationHandler;

  late final HomeRealtimeHandler realtimeHandler;

  final SpeechService speechService =
      SpeechService.instance;

  final AudioService audioService =
      AudioService.instance;

  final List<Map<String, dynamic>>
  activeTrips = [];

  final Map<String, Timer>
  tripTimers = {};

  int enabledGroupCount = 0;
  int totalGroupCount = 0;

  bool filterActive = false;
  int notificationFilterCount = 0;

  String connectionStatus =
      'Đang kết nối backend...';

  String? messageId;

  String? senderId;
  String? senderName;

  String? groupId;
  String? groupName;

  String? message;

  bool accepting = false;
  bool accepted = false;

  bool notificationInitialized = false;

  @override
  void initState() {
    super.initState();

    speechService.initialize();

    loadHomeSummary();

    notificationHandler =
        HomeNotificationHandler(

          settingsController:
          widget.settingsController,

          backend:
          backend,

          audioService:
          audioService,

          speechService:
          speechService,
        );

    realtimeHandler =
        HomeRealtimeHandler(

          backend:
          backend,


          onAuthenticated:
              () {

            if (!mounted) {
              return;
            }


            setState(() {

              connectionStatus =
              'Đã kết nối realtime';
            });
          },


          onAuthError:
              () {

            if (!mounted) {
              return;
            }


            setState(() {

              connectionStatus =
              'Xác thực realtime thất bại';
            });
          },


          onNewTrip:
              (
              data,
              ) {

            if (!mounted) {
              return;
            }


            addTrip(
              data,
            );

            notificationHandler
                .handleTripNotificationSpeech(
              data,
            );

              },


          onConnectionError:
              () {

            if (!mounted) {
              return;
            }


            setState(() {

              connectionStatus =
              'Mất kết nối backend';
            });
          },


          onConnectionDone:
              () {

            if (!mounted) {
              return;
            }


            setState(() {

              connectionStatus =
              'Backend đã ngắt kết nối';
            });
          },
        );


    realtimeHandler.start();
  }

  @override
  void didChangeDependencies() {

    super.didChangeDependencies();


    if (
    notificationInitialized
    ) {
      return;
    }


    notificationInitialized = true;


    notificationHandler.initialize(
      context,
    );
  }

  Future<void> acceptTrip(
      Map<String, dynamic> trip,
      ) async {

    final tripId =
    trip['id']
        ?.toString();


    if (
    tripId == null ||
        tripId.isEmpty
    ) {
      return;
    }


    final currentStatus =
    trip['_uiStatus']
        ?.toString();


    if (
    currentStatus ==
        'accepting' ||
        currentStatus ==
            'ignoring' ||
        currentStatus ==
            'accepted'
    ) {
      return;
    }

    tripTimers[
    tripId
    ]?.cancel();

    tripTimers.remove(
      tripId,
    );

    setState(() {
      trip['_uiStatus'] =
      'accepting';
    });


    try {

      await backend
          .acceptMessage(
        tripId,

        replyText:
        widget
            .settingsController
            .settings
            .acceptReplyText,
      );


      if (!mounted) {
        return;
      }


      setState(() {
        trip['_uiStatus'] =
        'accepted';
      });


      // ========================================
      // CHO NGUOI DUNG THAY "DA NHAN"
      // ROI MOI BIEN MAT
      // ========================================

      await Future.delayed(
        const Duration(
          milliseconds: 1500,
        ),
      );


      if (!mounted) {
        return;
      }


      removeTrip(
        tripId,
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      setState(() {
        trip['_uiStatus'] =
        'new';
      });


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Không thể nhận cuốc: $error',
          ),
        ),
      );
    }
  }

  Future<void> loadHomeSummary() async {

    try {

      final groups =
      await backend.getGroups();


      final filters =
      await backend.getFilters();


      if (!mounted) {
        return;
      }


      final includeKeywords =
      filters['includeKeywords'];


      setState(() {

        totalGroupCount =
            groups.length;


        enabledGroupCount =
            groups
                .where(
                  (group) =>
              group['enabled'] ==
                  true,
            )
                .length;


        filterActive =
            filters['enabled'] ==
                true;


        notificationFilterCount =
        includeKeywords is List
            ? includeKeywords.length
            : 0;
      });

    } catch (error) {

      debugPrint(
        'HOME SUMMARY ERROR: $error',
      );
    }
  }

  Future<void> openGroups() async {

    await widget
        .onOpenGroups();


    if (!mounted) {
      return;
    }


    await loadHomeSummary();
  }

  Future<void> ignoreTrip(
      Map<String, dynamic> trip,
      ) async {

    final tripId =
    trip['id']
        ?.toString();


    if (
    tripId == null ||
        tripId.isEmpty
    ) {
      return;
    }


    final currentStatus =
    trip['_uiStatus']
        ?.toString();


    if (
    currentStatus ==
        'accepting' ||
        currentStatus ==
            'ignoring'
    ) {
      return;
    }

    tripTimers[
    tripId
    ]?.cancel();

    tripTimers.remove(
      tripId,
    );

    setState(() {
      trip['_uiStatus'] =
      'ignoring';
    });


    try {

      await backend
          .ignoreMessage(
        tripId,
      );


      if (!mounted) {
        return;
      }


      setState(() {
        trip['_uiStatus'] =
        'ignored';
      });


      await Future.delayed(
        const Duration(
          milliseconds: 1000,
        ),
      );


      if (!mounted) {
        return;
      }


      removeTrip(
        tripId,
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      setState(() {
        trip['_uiStatus'] =
        'new';
      });


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Không thể bỏ qua cuốc: $error',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    realtimeHandler.dispose();

    for (
    final timer
    in tripTimers.values
    ) {
      timer.cancel();
    }

    tripTimers.clear();

    super.dispose();
  }

  void addTrip(
      Map<String, dynamic> trip,
      ) {

    final tripId =
    trip['id']
        ?.toString();


    if (
    tripId == null ||
        tripId.isEmpty
    ) {
      return;
    }


    // ========================================
    // KHONG THEM TRUNG CUOC
    // ========================================

    final existed =
    activeTrips.any(
          (item) =>
      item['id']
          ?.toString() ==
          tripId,
    );


    if (existed) {
      return;
    }


    final newTrip =
    Map<String, dynamic>.from(
      trip,
    );

    // Trang thai rieng cho UI.
    newTrip['_uiStatus'] = 'new';

    // ========================================
    // COUNTDOWN RIENG CUA CUOC
    // ========================================
    newTrip['_remainingSeconds'] =
        widget
            .settingsController
            .settings
            .tripDisplaySeconds;

    setState(() {

      // ADD CUOI DANH SACH
      // → cuoc moi nam ben duoi
      activeTrips.add(
        newTrip,
      );
    });


    // ========================================
    // AUTO HIDE SAU THOI GIAN CAI DAT
    // ========================================

    // ========================================
// COUNTDOWN TIMER
// MOI CUOC CO TIMER RIENG
// ========================================

    tripTimers[
    tripId
    ]?.cancel();


    tripTimers[
    tripId
    ] = Timer.periodic(

      const Duration(
        seconds: 1,
      ),

          (
          timer,
          ) {

        if (!mounted) {

          timer.cancel();

          return;
        }


        // ========================================
        // TIM CUOC TRONG DANH SACH
        // ========================================

        final index =
        activeTrips.indexWhere(
              (
              item,
              ) =>
          item['id']
              ?.toString() ==
              tripId,
        );


        // Cuoc da bi xoa bang NHAN / BO QUA.
        if (
        index == -1
        ) {

          timer.cancel();

          tripTimers.remove(
            tripId,
          );

          return;
        }


        final currentRemaining =
        activeTrips[index]['_remainingSeconds']
        is int
            ? activeTrips[index]['_remainingSeconds'] as int
            : widget
            .settingsController
            .settings
            .tripDisplaySeconds;


        final nextRemaining =
            currentRemaining - 1;


        // ========================================
        // HET GIO
        // ========================================

        if (
        nextRemaining <= 0
        ) {

          removeTrip(
            tripId,
          );

          return;
        }


        // ========================================
        // CAP NHAT COUNTDOWN
        // ========================================

        setState(() {

          activeTrips[index][
          '_remainingSeconds'
          ] =
              nextRemaining;
        });
      },
    );
  }

  void removeTrip(
      String tripId,
      ) {

    tripTimers[
    tripId
    ]?.cancel();


    tripTimers.remove(
      tripId,
    );


    if (!mounted) {
      return;
    }


    setState(() {

      activeTrips.removeWhere(
            (trip) =>
        trip['id']
            ?.toString() ==
            tripId,
      );
    });
  }

  Widget homeSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingText,
  }) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return InkWell(
      onTap:
      onTap,

      child:
      Padding(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        child:
        Row(
          children: [

            // ========================================
            // ICON
            // ========================================

            Container(
              width: 54,
              height: 54,

              decoration:
              BoxDecoration(
                color:
                colorScheme
                    .primaryContainer,

                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),

              child:
              Icon(
                icon,

                color:
                colorScheme
                    .primary,

                size: 28,
              ),
            ),


            const SizedBox(
              width: 16,
            ),


            // ========================================
            // TEXT
            // ========================================

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(
                    title,

                    style:
                    const TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),


                  const SizedBox(
                    height: 4,
                  ),


                  Text(
                    subtitle,

                    style:
                    TextStyle(
                      fontSize: 13,

                      color:
                      colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),


            if (
            trailingText != null
            ) ...[

              const SizedBox(
                width: 10,
              ),


              Text(
                trailingText,

                style:
                TextStyle(
                  fontSize: 16,

                  color:
                  colorScheme
                      .primary,
                ),
              ),
            ],


            const SizedBox(
              width: 6,
            ),


            const Icon(
              Icons.chevron_right,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIdleHome() {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    String notificationFilterText;


    if (
    !filterActive ||
        notificationFilterCount == 0
    ) {

      notificationFilterText =
      'Chưa bật bộ lọc nào — mọi cuốc đều hiện';

    } else {

      notificationFilterText =
      '$notificationFilterCount điều kiện lọc đang hoạt động';
    }


    return SafeArea(
      child:
      Padding(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          14,
          20,
          16,
        ),

        child:
        Column(
          children: [

            // ========================================
            // TOP COUNTERS
            // LUON LUON HIEN
            // ========================================

            Row(
              children: [

                Icon(
                  Icons.touch_app_outlined,

                  color:
                  colorScheme.primary,
                ),


                const SizedBox(
                  width: 8,
                ),


                const Text(
                  '0/0',

                  style:
                  TextStyle(
                    fontSize: 17,
                  ),
                ),


                const SizedBox(
                  width: 28,
                ),


                Icon(
                  Icons.chat_bubble_outline,

                  color:
                  colorScheme.primary,
                ),


                const SizedBox(
                  width: 8,
                ),


                const Text(
                  '0/0',

                  style:
                  TextStyle(
                    fontSize: 17,
                  ),
                ),


                const Spacer(),


                TextButton(
                  onPressed:
                      () {
                    // Upgrade se lam sau.
                  },

                  child:
                  const Text(
                    'Nâng cấp',
                  ),
                ),
              ],
            ),


            const SizedBox(
              height: 14,
            ),


            const Divider(
              height: 1,
            ),


            const SizedBox(
              height: 18,
            ),


            // ========================================
            // KHONG CO CUOC
            // ========================================

            if (
            activeTrips.isEmpty
            ) ...[

              // ----------------------------------------
              // DANG LANG NGHE
              // ----------------------------------------

              Row(
                children: [

                  Container(
                    width: 9,
                    height: 9,

                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,

                      color:
                      connectionStatus ==
                          'Đã kết nối realtime'
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),


                  const SizedBox(
                    width: 12,
                  ),


                  Text(
                    connectionStatus ==
                        'Đã kết nối realtime'
                        ? 'Đang lắng nghe'
                        : connectionStatus,

                    style:
                    TextStyle(
                      color:
                      colorScheme
                          .onSurfaceVariant,

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
                clipBehavior:
                Clip.antiAlias,

                child:
                Column(
                  children: [

                    // ==================================
                    // NHOM NHAN THONG BAO
                    // ==================================

                    homeSettingItem(
                      icon:
                      Icons.notifications_none,

                      title:
                      'Nhóm nhận thông báo',

                      subtitle:
                      'Chỉ cuốc từ nhóm đã bật mới hiện ở đây',

                      trailingText:
                      '$enabledGroupCount/$totalGroupCount',

                      onTap:
                      openGroups,
                    ),


                    const Divider(
                      height: 1,
                    ),


                    // ==================================
                    // BO LOC THONG BAO
                    // ==================================

                    homeSettingItem(
                      icon:
                      Icons.tune,

                      title:
                      'Bộ lọc thông báo',

                      subtitle:
                      notificationFilterText,

                      onTap:
                      widget
                          .onOpenNotificationFilter,
                    ),


                    const Divider(
                      height: 1,
                    ),


                    // ==================================
                    // TU DONG NHAN
                    // ==================================

                    homeSettingItem(
                      icon:
                      Icons.bolt,

                      title:
                      'Bộ lọc tự động nhận',

                      subtitle:
                      'Chưa bật bộ lọc nào — không cuốc nào được tự nhận',

                      onTap:
                      widget
                          .onOpenAutoAcceptFilter,
                    ),
                  ],
                ),
              ),


              const Spacer(
                flex: 2,
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
                child:
                ListView.builder(
                  padding:
                  const EdgeInsets.only(
                    bottom: 16,
                  ),

                  physics:
                  const AlwaysScrollableScrollPhysics(),

                  itemCount:
                  activeTrips.length,

                  itemBuilder:
                      (
                      context,
                      index,
                      ) {

                        return TripCard(

                          trip:
                          activeTrips[index],

                          settingsController:
                          widget.settingsController,

                          onAccept:
                              () {
                            acceptTrip(
                              activeTrips[index],
                            );
                          },

                          onIgnore:
                              () {
                            ignoreTrip(
                              activeTrips[index],
                            );
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
  Widget build(
      BuildContext context,
      ) {

    return buildIdleHome();
  }




}

