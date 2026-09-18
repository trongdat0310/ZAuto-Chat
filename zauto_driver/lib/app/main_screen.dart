import 'package:flutter/material.dart';

import '../controllers/settings_controller.dart';

import '../pages/home/home_page.dart';
import '../pages/filter/filter_page.dart';

import '../pages/account_page.dart';
import '../pages/groups_page.dart';
import '../pages/messages_page.dart';
import '../pages/settings/settings_page.dart';

import '../pages/zalo_link_page.dart';

import 'zalo_required_page.dart';

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

  final SettingsController settingsController;

  const MainScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onAuthChanged,
    required this.onAccountDeleted,
    required this.settingsController,
  });


  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState
    extends State<MainScreen> {

  int currentIndex = 0;

  int filterInitialTab = 0;

  SettingsController get settingsController =>
      widget.settingsController;

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
        onOpenGroups: openGroupsFromHome,
        onOpenNotificationFilter: openNotificationFilter,
        onOpenAutoAcceptFilter: openAutoAcceptFilter,
        settingsController: settingsController,
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
        settingsController: settingsController,
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
  void initState() {

    super.initState();
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
}