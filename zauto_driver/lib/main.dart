import 'package:flutter/material.dart';
import 'dart:async';
import 'services/backend_service.dart';
import 'pages/groups_page.dart';
import 'config/app_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/notification_service.dart';
import 'pages/login_page.dart';
import 'pages/zalo_link_page.dart';
import 'services/auth_service.dart';
import 'pages/account_page.dart';
import 'pages/messages_page.dart';
import 'pages/settings_page.dart';
import 'services/theme_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {

  await Firebase.initializeApp(
    options:
    DefaultFirebaseOptions.currentPlatform,
  );


  final data =
      message.data;


  if (
  data['type'] != 'new_trip'
  ) {
    return;
  }


  await NotificationService.instance
      .showTrip(
    messageId:
    data['messageId'] ?? '',

    groupName:
    data['groupName'],

    senderName:
    data['senderName'],

    content:
    data['content'] ?? '',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding
      .ensureInitialized();


  await Firebase.initializeApp(
    options:
    DefaultFirebaseOptions
        .currentPlatform,
  );


  FirebaseMessaging
      .onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );


  runApp(
    const ZautoDriverApp(),
  );
}

class ZautoDriverApp extends StatelessWidget {

  const ZautoDriverApp({
    super.key,
  });


  @override
  Widget build(
      BuildContext context,
      ) {

    return ValueListenableBuilder<
        ThemeMode>(
      valueListenable:
      ThemeService.themeMode,

      builder:
          (
          context,
          themeMode,
          child,
          ) {

        return MaterialApp(
          debugShowCheckedModeBanner:
          false,

          title:
          'Driver Assistant',


          // ========================================
          // LIGHT THEME
          // ========================================

          theme:
          ThemeData(
            useMaterial3:
            true,

            brightness:
            Brightness.light,

            colorSchemeSeed:
            Colors.blue,
          ),


          // ========================================
          // DARK THEME
          // ========================================

          darkTheme:
          ThemeData(
            useMaterial3:
            true,

            brightness:
            Brightness.dark,

            colorSchemeSeed:
            Colors.blue,
          ),


          // ========================================
          // LIGHT / DARK / SYSTEM
          // ========================================

          themeMode:
          themeMode,


          home:
          const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
  });

  @override
  State<AuthGate>
  createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {

  final AuthService auth =
  AuthService();

  final BackendService backend =
  BackendService(
    baseUrl:
    AppConfig.backendUrl,
  );

  bool loading = true;

  Map<String, dynamic>?
  user;


  @override
  void initState() {
    super.initState();

    refreshAuth();
  }


  Future<void> refreshAuth() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }


    try {
      final currentUser =
      await auth
          .getCurrentUser();

      if (!mounted) return;


      setState(() {
        user = currentUser;
      });

      if (currentUser != null) {
        await registerPushDevice();
      }

    } catch (error) {

      debugPrint(
        'AUTH CHECK ERROR: $error',
      );

      if (mounted) {
        setState(() {
          user = null;
        });
      }

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> logout() async {

    try {
      final token =
      await FirebaseMessaging
          .instance
          .getToken();


      if (
      token != null &&
          token.isNotEmpty
      ) {
        await backend
            .unregisterDevice(
          token,
        );
      }

    } catch (error) {

      debugPrint(
        'DEVICE UNREGISTER ERROR: $error',
      );
    }


    // Sau khi unregister device
    // moi revoke JWT.
    await auth.logout();


    if (!mounted) return;


    setState(() {
      user = null;
    });
  }

  Future<void> registerPushDevice() async {

    try {
      final messaging =
          FirebaseMessaging.instance;


      await messaging
          .requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );


      final token =
      await messaging
          .getToken();


      if (
      token == null ||
          token.isEmpty
      ) {
        return;
      }


      await backend
          .registerDevice(
        token:
        token,

        platform:
        Platform.isIOS
            ? 'ios'
            : 'android',
      );


      debugPrint(
        'USER DEVICE REGISTERED',
      );

    } catch (error) {

      debugPrint(
        'USER DEVICE REGISTER ERROR: $error',
      );
    }
  }

  Future<void> accountDeleted() async {

    // Account backend da bi xoa,
    // khong goi /logout nua.
    await auth.clearLocalSession();


    if (!mounted) {
      return;
    }


    setState(() {
      user = null;
    });
  }

  @override
  Widget build(
      BuildContext context,
      ) {

    if (loading) {
      return const Scaffold(
        body: Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }


    if (user == null) {
      return LoginPage(
        onAuthenticated:
        refreshAuth,
      );
    }


// ========================================
// DA LOGIN
// LUON VAO MAIN SCREEN
// DU DA LINK ZALO HAY CHUA
// ========================================

    return MainScreen(
      user: user!,
      onLogout: logout,
      onAuthChanged: refreshAuth,
      onAccountDeleted: accountDeleted,
    );
  }
}

class MainScreen
    extends StatefulWidget {

  final Map<String, dynamic>
  user;

  final Future<void> Function()
  onLogout;

  final Future<void> Function()
  onAuthChanged;

  final Future<void> Function()
  onAccountDeleted;


  const MainScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onAuthChanged,
    required this.onAccountDeleted,
  });


  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState
    extends State<MainScreen> {

  int currentIndex = 0;

  int tripDisplaySeconds = 10;

  int filterInitialTab = 0;

  double notificationFontSize = 12;

  String acceptButtonPosition = 'right';

  Future<void> openZaloLink() async {

    final linked =
    await Navigator.push<bool>(
      context,

      MaterialPageRoute(
        builder: (linkContext) {

          return ZaloLinkPage(
            user:
            widget.user,


            // ========================================
            // LOGOUT TU MAN HINH LINK
            // ========================================

            onLogout:
                () async {

              if (
              Navigator.of(
                linkContext,
              ).canPop()
              ) {
                Navigator.of(
                  linkContext,
                ).pop(false);
              }


              await widget
                  .onLogout();
            },


            // ========================================
            // LINK THANH CONG
            // ========================================

            onLinked:
                () async {

              if (
              Navigator.of(
                linkContext,
              ).canPop()
              ) {
                Navigator.of(
                  linkContext,
                ).pop(true);
              }
            },
          );
        },
      ),
    );


    if (
    linked != true ||
        !mounted
    ) {
      return;
    }


    // GET /api/me lai
    // de cap nhat zaloLinked = true
    await widget
        .onAuthChanged();
  }

  Future<void> openGroupsFromHome() async {

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
        const GroupsPage(),
      ),
    );


    if (!mounted) {
      return;
    }


    // Khi quay lại từ GroupsPage
    // rebuild HomePage để cập nhật số nhóm.
    setState(() {});
  }

  // Không dùng:
  //
  // final pages = const [...]
  //
  // vì AccountPage cần callback từ widget.
  List<Widget> get pages {

    final zaloLinked =
        widget.user['zaloLinked'] ==
            true;


    return [

      // ========================================
      // 0. CANH ME
      // ========================================

      zaloLinked
          ? HomePage(
        tripDisplaySeconds: tripDisplaySeconds,
        notificationFontSize: notificationFontSize,
        onOpenGroups: openGroupsFromHome,
        onOpenNotificationFilter: openNotificationFilter,
        onOpenAutoAcceptFilter: openAutoAcceptFilter,
        acceptButtonPosition: acceptButtonPosition,
      )
          : ZaloRequiredPage(
        onLinkZalo:
        openZaloLink,
      ),


      // ========================================
      // 1. TIN NHAN
      // ========================================

      zaloLinked
          ? MessagesPage(
        onOpenSettings:
        openSettingsFromMessages,
      )
          : ZaloRequiredPage(
        onLinkZalo:
        openZaloLink,

        title:
        'Liên kết Zalo để xem tin nhắn',

        description:
        'Sau khi liên kết Zalo, các cuộc trò chuyện nhóm sẽ xuất hiện tại đây.',
      ),


      // ========================================
      // 2. CAI DAT
      // ========================================

      SettingsPage(
        tripDisplaySeconds: tripDisplaySeconds,
        onTripDisplaySecondsChanged: updateTripDisplaySeconds,
        notificationFontSize: notificationFontSize,
        onNotificationFontSizeChanged: updateNotificationFontSize,
        acceptButtonPosition: acceptButtonPosition,
        onAcceptButtonPositionChanged: updateAcceptButtonPosition,
      ),


      // ========================================
      // 3. BO LOC
      // ========================================

      FilterPage(
        key:
        ValueKey(
          'filter-$filterInitialTab',
        ),

        initialTab:
        filterInitialTab,
      ),


      // ========================================
      // 4. TAI KHOAN
      // ========================================

      AccountPage(
        onLogout:
        widget.onLogout,

        onAuthChanged:
        widget.onAuthChanged,

        onAccountDeleted:
        widget.onAccountDeleted,
      ),
    ];
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    return Scaffold(

      // ========================================
      // GIU TAT CA TAB TON TAI
      // HOME PAGE KHONG BI DISPOSE KHI DOI TAB
      // ========================================

      body:
      IndexedStack(
        index:
        currentIndex,

        children:
        pages,
      ),


      bottomNavigationBar:
      NavigationBar(

        selectedIndex:
        currentIndex,


        onDestinationSelected:
            (index) {

          setState(() {
            currentIndex =
                index;
          });
        },


        destinations:
        const [

          // ========================================
          // 0. CANH ME
          // ========================================

          NavigationDestination(
            icon:
            Icon(
              Icons.home_outlined,
            ),

            selectedIcon:
            Icon(
              Icons.home,
            ),

            label:
            'Cuốc',
          ),


          // ========================================
          // 1. TIN NHAN
          // ========================================

          NavigationDestination(
            icon:
            Icon(
              Icons.chat_bubble_outline,
            ),

            selectedIcon:
            Icon(
              Icons.chat_bubble,
            ),

            label:
            'Tin nhắn',
          ),


          // ========================================
          // 2. CAI DAT
          // ========================================

          NavigationDestination(
            icon:
            Icon(
              Icons.settings_outlined,
            ),

            selectedIcon:
            Icon(
              Icons.settings,
            ),

            label:
            'Cài đặt',
          ),


          // ========================================
          // 3. BO LOC
          // ========================================

          NavigationDestination(
            icon:
            Icon(
              Icons.tune,
            ),

            selectedIcon:
            Icon(
              Icons.tune,
            ),

            label:
            'Bộ lọc',
          ),


          // ========================================
          // 4. TAI KHOAN
          // ========================================

          NavigationDestination(
            icon:
            Icon(
              Icons.person_outline,
            ),

            selectedIcon:
            Icon(
              Icons.person,
            ),

            label:
            'Tài khoản',
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(
      covariant MainScreen oldWidget,
      ) {

    super.didUpdateWidget(
      oldWidget,
    );


    final oldLinked =
        oldWidget.user['zaloLinked'] ==
            true;


    final newLinked =
        widget.user['zaloLinked'] ==
            true;


    if (
    oldLinked !=
        newLinked
    ) {

      currentIndex =
      0;
    }
  }

  void openNotificationFilter() {

    setState(() {

      // Tab Lọc thông báo
      filterInitialTab = 0;

      // Bottom navigation:
      // 0 Canh me
      // 1 Tin nhắn
      // 2 Cài đặt
      // 3 Bộ lọc
      // 4 Tài khoản
      currentIndex = 3;
    });
  }

  void openAutoAcceptFilter() {

    setState(() {

      // Tab Tự động nhận
      filterInitialTab = 1;

      currentIndex = 3;
    });
  }

  void openSettingsFromMessages() {

    setState(() {
      currentIndex = 2;
    });
  }

  void updateTripDisplaySeconds(
      int seconds,
      ) {

    if (
    seconds != 5 &&
        seconds != 10 &&
        seconds != 15
    ) {
      return;
    }


    setState(() {
      tripDisplaySeconds =
          seconds;
    });
  }

  void updateNotificationFontSize(
      double size,
      ) {

    if (
    size < 10 ||
        size > 30
    ) {
      return;
    }


    setState(() {
      notificationFontSize =
          size;
    });
  }

  void updateAcceptButtonPosition(
      String position,
      ) {

    if (
    position != 'left' &&
        position != 'right'
    ) {
      return;
    }


    setState(() {
      acceptButtonPosition =
          position;
    });
  }
}

class ZaloRequiredPage
    extends StatelessWidget {

  final Future<void> Function()
  onLinkZalo;

  final String title;

  final String description;


  const ZaloRequiredPage({
    super.key,

    required this.onLinkZalo,

    this.title =
    'Vui lòng liên kết Zalo với ZAUTO',

    this.description =
    'Cho phép ZAUTO đọc và tổng hợp tin nhắn từ các nhóm Zalo bạn đã chọn.',
  });


  @override
  Widget build(
      BuildContext context,
      ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return SafeArea(
      child:
      Column(
        children: [

          // ========================================
          // WARNING
          // ========================================

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              0,
            ),

            child:
            Text(
              '*Hãy luôn mở ứng dụng để không bỏ lỡ tin nhắn',

              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                Colors.amber.shade700,

                fontSize:
                13,
              ),
            ),
          ),


          // ========================================
          // CENTER CARD
          // ========================================

          Expanded(
            child:
            Center(
              child:
              SingleChildScrollView(
                padding:
                const EdgeInsets.all(
                  24,
                ),

                child:
                Card(
                  elevation:
                  1,

                  child:
                  ConstrainedBox(
                    constraints:
                    const BoxConstraints(
                      maxWidth:
                      520,
                    ),

                    child:
                    Padding(
                      padding:
                      const EdgeInsets.all(
                        28,
                      ),

                      child:
                      Column(
                        mainAxisSize:
                        MainAxisSize.min,

                        children: [

                          CircleAvatar(
                            radius:
                            32,

                            backgroundColor:
                            colorScheme
                                .primaryContainer,

                            child:
                            Icon(
                              Icons.chat_bubble_outline,

                              size:
                              32,

                              color:
                              colorScheme
                                  .primary,
                            ),
                          ),


                          const SizedBox(
                            height:
                            20,
                          ),


                          Text(
                            title,

                            textAlign:
                            TextAlign.center,

                            style:
                            const TextStyle(
                              fontSize:
                              20,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),


                          const SizedBox(
                            height:
                            14,
                          ),


                          Text(
                            description,

                            textAlign:
                            TextAlign.center,

                            style:
                            TextStyle(
                              fontSize:
                              15,

                              color:
                              colorScheme
                                  .onSurfaceVariant,

                              height:
                              1.45,
                            ),
                          ),


                          const SizedBox(
                            height:
                            26,
                          ),


                          SizedBox(
                            width:
                            double.infinity,

                            height:
                            54,

                            child:
                            FilledButton.icon(
                              onPressed:
                                  () async {

                                await onLinkZalo();
                              },

                              icon:
                              const Icon(
                                Icons.link,
                              ),

                              label:
                              const Text(
                                'LIÊN KẾT NGAY',

                                style:
                                TextStyle(
                                  fontSize:
                                  16,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
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
          ),
        ],
      ),
    );
  }
}

class HomePage
    extends StatefulWidget {

  final int tripDisplaySeconds;

  final double notificationFontSize;

  final Future<void> Function()onOpenGroups;

  final VoidCallback onOpenNotificationFilter;

  final VoidCallback onOpenAutoAcceptFilter;

  final String acceptButtonPosition;


  const HomePage({
    super.key,

    required this.tripDisplaySeconds,
    required this.notificationFontSize,
    required this.onOpenGroups,
    required this.onOpenNotificationFilter,
    required this.onOpenAutoAcceptFilter,
    required this.acceptButtonPosition,
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

  final List<Map<String, dynamic>>
  activeTrips = [];

  final Map<String, Timer>
  tripTimers = {};

  int enabledGroupCount = 0;
  int totalGroupCount = 0;

  bool filterActive = false;
  int notificationFilterCount = 0;

  StreamSubscription<Map<String, dynamic>>?
  subscription;

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

  @override
  void initState() {
    super.initState();

    loadHomeSummary();

    setupLocalNotifications();
    setupPushNotifications();

    subscription =
        backend.connectRealtime().listen(
              (event) {
            final type =
            event['type']?.toString();

            // Backend vua ket noi
            if (
            type ==
                'auth_required'
            ) {
              return;
            }


            if (
            type ==
                'authenticated'
            ) {
              if (!mounted) return;

              setState(() {
                connectionStatus =
                'Đã kết nối realtime';
              });

              return;
            }


            if (
            type ==
                'auth_error'
            ) {
              if (!mounted) return;

              setState(() {
                connectionStatus =
                'Xác thực realtime thất bại';
              });

              return;
            }


            if (
            type !=
                'new_trip'
            ) {
              return;
            }


            // ========================================
            // CUOC MOI
            // THEM VAO DANH SACH, KHONG GHI DE
            // ========================================

            final rawData =
            event['data'];


            if (
            rawData is! Map
            ) {
              return;
            }


            final data =
            Map<String, dynamic>.from(
              rawData,
            );


            if (!mounted) {
              return;
            }


            // Khong con:
            // message = ...
            // messageId = ...
            //
            // Ma them cuoc vao danh sach.
            addTrip(
              data,
            );
          },

          onError: (error) {
            if (!mounted) return;

            setState(() {
              connectionStatus =
              'Mất kết nối backend';
            });

            debugPrint(
              'WebSocket error: $error',
            );
          },

          onDone: () {
            if (!mounted) return;

            setState(() {
              connectionStatus =
              'Backend đã ngắt kết nối';
            });
          },
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

  Future<void> setupPushNotifications() async {

    // ========================================
    // APP DANG MO
    // ========================================

    FirebaseMessaging
        .onMessage
        .listen(
          (
          RemoteMessage remoteMessage,
          ) async {

        final data =
            remoteMessage.data;


        if (
        data['type'] !=
            'new_trip'
        ) {
          return;
        }


        await NotificationService
            .instance
            .showTrip(
          messageId:
          data['messageId'] ??
              '',

          groupName:
          data['groupName'],

          senderName:
          data['senderName'],

          content:
          data['content'] ??
              '',
        );
      },
    );
  }

  Future<void> setupLocalNotifications() async {

    await NotificationService
        .instance
        .initialize(
      onAction: (
          NotificationResponse response,
          ) async {

        await handleNotificationAction(
          response,
        );
      },
    );
  }

  Future<void> handleNotificationAction(
      NotificationResponse response,
      ) async {


    final payload =
        response.payload;


    if (payload == null) {
      return;
    }


    final decoded =
    jsonDecode(payload);


    final messageId =
    decoded['messageId']
        ?.toString();


    if (
    messageId == null ||
        messageId.isEmpty
    ) {
      return;
    }


    try {

      if (
      response.actionId ==
          NotificationService
              .acceptAction
      ) {

        await backend
            .acceptMessage(
          messageId,
        );


        if (!mounted) return;


        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Đã nhận cuốc',
            ),
          ),
        );

        return;
      }


      if (
      response.actionId ==
          NotificationService
              .ignoreAction
      ) {

        await backend
            .ignoreMessage(
          messageId,
        );


        if (!mounted) return;


        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Đã bỏ qua cuốc',
            ),
          ),
        );
      }

    } catch (error) {

      debugPrint(
          'Notification action error: $error'
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
    subscription?.cancel();

    for (
    final timer
    in tripTimers.values
    ) {
      timer.cancel();
    }

    tripTimers.clear();
    backend.disconnect();

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
        widget.tripDisplaySeconds;

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
        activeTrips[index][
        '_remainingSeconds'
        ] is int
            ? activeTrips[index][
        '_remainingSeconds'
        ] as int
            : widget
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

                    return buildTripCard(
                      activeTrips[index],
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

  String formatTripCountdown(
      int seconds,
      ) {

    final safeSeconds =
    seconds < 0
        ? 0
        : seconds;


    final minutes =
        safeSeconds ~/ 60;


    final remainingSeconds =
        safeSeconds % 60;


    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget buildTripCard(
      Map<String, dynamic> trip,
      ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    final content =
        trip['content']
            ?.toString() ??
            'Cuốc mới';


    final groupName =
        trip['groupName']
            ?.toString() ??
            'Nhóm Zalo';


    final senderName =
        trip['senderName']
            ?.toString() ??
            'Không rõ người gửi';


    final status =
        trip['_uiStatus']
            ?.toString() ??
            'new';

    final remainingSeconds =
        trip['_remainingSeconds']
            is int
                ? trip['_remainingSeconds']
            as int
                : widget
                .tripDisplaySeconds;

    final isCountdownWarning =
        remainingSeconds <= 3;

    final processing =
        status ==
            'accepting' ||
            status ==
                'ignoring';


    // ========================================
    // SUCCESS STATUS
    // ========================================

    if (
    status ==
        'accepted'
    ) {

      return Card(
        margin:
        const EdgeInsets.only(
          bottom: 12,
        ),

        child:
        Padding(
          padding:
          const EdgeInsets.all(
            20,
          ),

          child:
          Row(
            children: [

              Icon(
                Icons
                    .check_circle_outline,

                color:
                colorScheme.primary,

                size:
                30,
              ),


              const SizedBox(
                width: 14,
              ),


              const Expanded(
                child:
                Text(
                  'Đã nhận cuốc',

                  style:
                  TextStyle(
                    fontSize: 17,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }


    if (
    status ==
        'ignored'
    ) {

      return const Card(
        margin:
        EdgeInsets.only(
          bottom: 12,
        ),

        child:
        Padding(
          padding:
          EdgeInsets.all(
            20,
          ),

          child:
          Row(
            children: [

              Icon(
                Icons
                    .visibility_off_outlined,

                size:
                28,
              ),

              SizedBox(
                width:
                14,
              ),

              Expanded(
                child:
                Text(
                  'Đã bỏ qua cuốc',

                  style:
                  TextStyle(
                    fontSize:
                    17,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }


    // ========================================
    // NORMAL TRIP CARD
    // ========================================

    final ignoreButton =
    Expanded(
      child:
      OutlinedButton.icon(

        onPressed:
        processing
            ? null
            : () {

          ignoreTrip(
            trip,
          );
        },

        icon:
        status ==
            'ignoring'
            ? const SizedBox(
          width: 18,
          height: 18,

          child:
          CircularProgressIndicator(
            strokeWidth:
            2,
          ),
        )
            : const Icon(
          Icons.close,
        ),

        label:
        const Text(
          'BỎ QUA',
        ),
      ),
    );


    final acceptButton =
    Expanded(
      child:
      FilledButton.icon(

        onPressed:
        processing
            ? null
            : () {

          acceptTrip(
            trip,
          );
        },

        icon:
        status ==
            'accepting'
            ? const SizedBox(
          width: 18,
          height: 18,

          child:
          CircularProgressIndicator(
            strokeWidth:
            2,
          ),
        )
            : const Icon(
          Icons.check,
        ),

        label:
        const Text(
          'NHẬN',
        ),
      ),
    );

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),

      child:
      Padding(
        padding:
        const EdgeInsets.all(
          18,
        ),

        child:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            // ========================================
            // HEADER
            // ========================================

            Row(
              children: [

                // ========================================
                // CUOC MOI
                // ========================================

                Icon(
                  Icons.local_taxi,

                  color:
                  colorScheme.primary,
                ),


                const SizedBox(
                  width: 10,
                ),


                const Text(
                  'CUỐC MỚI',

                  style:
                  TextStyle(
                    fontWeight:
                    FontWeight.bold,

                    fontSize:
                    15,
                  ),
                ),


                const Spacer(),


                // ========================================
                // COUNTDOWN
                // ========================================

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration:
                  BoxDecoration(

                    // ========================================
                    // <= 3 GIAY -> MAU CANH BAO
                    // ========================================

                    color:
                    isCountdownWarning
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,

                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),

                  child:
                  Row(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      Icon(
                        isCountdownWarning
                            ? Icons.warning_amber_rounded
                            : Icons.timer_outlined,

                        size:
                        16,

                        color:
                        isCountdownWarning
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),


                      const SizedBox(
                        width: 5,
                      ),


                      Text(
                        formatTripCountdown(
                          remainingSeconds,
                        ),

                        style:
                        TextStyle(
                          fontSize:
                          14,

                          fontWeight:
                          FontWeight.bold,

                          color:
                          isCountdownWarning
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),


            const SizedBox(
              height: 14,
            ),


            // ========================================
            // CONTENT
            // ========================================

            Text(
              content,

              style:
              TextStyle(
                fontSize:
                widget.notificationFontSize,

                fontWeight:
                FontWeight.w600,

                height:
                1.25,
              ),
            ),


            const SizedBox(
              height: 14,
            ),


            Text(
              'Nhóm: $groupName',
            ),


            const SizedBox(
              height: 5,
            ),


            Text(
              'Người gửi: $senderName',
            ),


            const SizedBox(
              height: 20,
            ),


            // ========================================
            // BUTTONS
            // ========================================

            Row(
              children:

              // ========================================
              // NHAN BEN TRAI
              // ========================================

              widget.acceptButtonPosition ==
                  'left'
                  ? [

                acceptButton,

                const SizedBox(
                  width:
                  12,
                ),

                ignoreButton,
              ]

              // ========================================
              // NHAN BEN PHAI
              // ========================================

                  : [

                ignoreButton,

                const SizedBox(
                  width:
                  12,
                ),

                acceptButton,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FilterPage
    extends StatefulWidget {

  final int initialTab;


  const FilterPage({
    super.key,

    this.initialTab = 0,
  });


  @override
  State<FilterPage>
  createState() =>
      _FilterPageState();
}

class _FilterPageState
    extends State<FilterPage> {

  late int selectedTab;

  final BackendService backend = BackendService(
    baseUrl: AppConfig.backendUrl,
  );

  final includeController = TextEditingController();
  final excludeController = TextEditingController();

  bool filterEnabled = true;
  bool loading = true;
  bool saving = false;


  @override
  void initState() {
    super.initState();

    selectedTab =
        widget.initialTab;

    loadFilters();
  }


  // ========================================
  // LOAD FILTER FROM BACKEND
  // ========================================

  Future<void> loadFilters() async {
    setState(() {
      loading = true;
    });

    try {
      final filters =
      await backend.getFilters();

      final include =
      filters['includeKeywords'];

      final exclude =
      filters['excludeKeywords'];

      includeController.text =
      include is List
          ? include.join(', ')
          : '';

      excludeController.text =
      exclude is List
          ? exclude.join(', ')
          : '';

      if (!mounted) return;

      setState(() {
        filterEnabled =
            filters['enabled'] != false;
      });

    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi tải bộ lọc: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }


  // ========================================
  // TEXT -> KEYWORD LIST
  // ========================================

  List<String> parseKeywords(
      String text,
      ) {
    return text
        .split(
      RegExp(r'[,;\n]'),
    )
        .map(
          (value) => value.trim(),
    )
        .where(
          (value) => value.isNotEmpty,
    )
        .toSet()
        .toList();
  }


  // ========================================
  // SAVE TO BACKEND
  // ========================================

  Future<void> saveFilters() async {
    if (saving) return;

    setState(() {
      saving = true;
    });

    try {
      final includeKeywords =
      parseKeywords(
        includeController.text,
      );

      final excludeKeywords =
      parseKeywords(
        excludeController.text,
      );

      await backend.updateFilters(
        includeKeywords:
        includeKeywords,

        excludeKeywords:
        excludeKeywords,

        enabled:
        filterEnabled,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu bộ lọc trên server',
          ),
        ),
      );

    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi lưu bộ lọc: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }


  @override
  void dispose() {
    includeController.dispose();
    excludeController.dispose();

    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: loading

          ? const Center(
        child:
        CircularProgressIndicator(),
      )

          : RefreshIndicator(
        onRefresh: loadFilters,

        child: ListView(
          padding:
          const EdgeInsets.all(
            20,
          ),

          children: [
            const Text(
              'Bộ lọc',
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Backend sẽ chỉ báo những cuốc phù hợp với điều kiện này.',
            ),

            const SizedBox(
              height: 24,
            ),


            // ========================================
            // ENABLE FILTER
            // ========================================

            Card(
              child: SwitchListTile(
                title: const Text(
                  'Bật bộ lọc',
                ),

                subtitle:
                const Text(
                  'Tắt để nhận tất cả tin nhắn từ những nhóm đang theo dõi.',
                ),

                value:
                filterEnabled,

                onChanged:
                    (value) {
                  setState(() {
                    filterEnabled =
                        value;
                  });
                },
              ),
            ),


            const SizedBox(
              height: 20,
            ),


            // ========================================
            // INCLUDE
            // ========================================

            TextField(
              controller:
              includeController,

              enabled:
              filterEnabled,

              minLines: 3,

              maxLines: 6,

              decoration:
              const InputDecoration(
                labelText:
                'Từ khóa cần có',

                hintText:
                'Nội Bài, NB, Cầu Giấy, sân bay',

                helperText:
                'Chỉ cần trùng một từ khóa.',

                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(
              height: 20,
            ),


            // ========================================
            // EXCLUDE
            // ========================================

            TextField(
              controller:
              excludeController,

              enabled:
              filterEnabled,

              minLines: 3,

              maxLines: 6,

              decoration:
              const InputDecoration(
                labelText:
                'Từ khóa loại trừ',

                hintText:
                'ship, hàng, ghép',

                helperText:
                'Nếu có từ khóa loại trừ, tin sẽ bị bỏ qua.',

                border:
                OutlineInputBorder(),
              ),
            ),


            const SizedBox(
              height: 24,
            ),


            // ========================================
            // SAVE
            // ========================================

            SizedBox(
              height: 56,

              child:
              FilledButton.icon(
                onPressed:
                saving
                    ? null
                    : saveFilters,

                icon:
                saving
                    ? const SizedBox(
                  width:
                  20,
                  height:
                  20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )
                    : const Icon(
                  Icons.save,
                ),

                label: Text(
                  saving
                      ? 'ĐANG LƯU...'
                      : 'LƯU BỘ LỌC',
                ),
              ),
            ),


            const SizedBox(
              height: 20,
            ),

            const Card(
              child: Padding(
                padding:
                EdgeInsets.all(
                  16,
                ),

                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

                  children: [
                    Icon(
                      Icons
                          .cloud_done_outlined,
                    ),

                    SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child: Text(
                        'Bộ lọc được lưu trên backend. Khi app đóng, backend vẫn tiếp tục sử dụng cấu hình này.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
