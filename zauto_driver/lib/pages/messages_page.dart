import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/backend_service.dart';
import 'chat_page.dart';
import 'dart:async';

class MessagesPage
    extends StatefulWidget {

  final VoidCallback
  onOpenSettings;


  const MessagesPage({
    super.key,
    required this.onOpenSettings,
  });


  @override
  State<MessagesPage>
  createState() =>
      _MessagesPageState();
}


class _MessagesPageState
    extends State<MessagesPage>
    with SingleTickerProviderStateMixin {

  final BackendService backend =
  BackendService(
    baseUrl:
    AppConfig.backendUrl,
  );


  final TextEditingController
  searchController =
  TextEditingController();


  late TabController
  tabController;


  List<Map<String, dynamic>>
  conversations = [];

  List<Map<String, dynamic>>
  acceptedTrips = [];

  Set<String>
  enabledGroupIds = {};

  bool loading =
  true;

  bool syncing =
  false;

  String searchText =
      '';

  DateTime? lastSyncAt;

  StreamSubscription<Map<String, dynamic>>?
  realtimeSubscription;

  Timer? realtimeRefreshTimer;

  @override
  void initState() {
    super.initState();

    tabController =
        TabController(
          length: 3,
          vsync: this,
        );


    searchController
        .addListener(
          () {

        if (!mounted) {
          return;
        }


        setState(() {

          searchText =
              searchController
                  .text
                  .trim()
                  .toLowerCase();
        });
      },
    );

    loadData();
    startRealtime();
  }

  void startRealtime() {

    realtimeSubscription =
        backend
            .connectRealtime()
            .listen(
              (
              event,
              ) {

                final type =
                event['type']
                    ?.toString();


// ========================================
// CUOC VUA DUOC NHAN
// ========================================

                if (
                type ==
                    'trip_accepted'
                ) {

                  refreshAcceptedTrips();

                  return;
                }


                // ========================================
                // TIN NHAN / CONVERSATION THAY DOI
                // ========================================

                if (
                type !=
                    'conversation_message' &&
                type !=
                    'conversation_message_updated' &&
                type !=
                    'conversation_read' &&
                type !=
                    'new_trip'
                ) {
                  return;
                }


                scheduleRealtimeRefresh();
          },

          onError:
              (
              error,
              ) {

            debugPrint(
              'MESSAGES REALTIME ERROR: $error',
            );
          },
        );
  }

  void scheduleRealtimeRefresh() {

    realtimeRefreshTimer
        ?.cancel();


    realtimeRefreshTimer =
        Timer(
          const Duration(
            milliseconds:
            350,
          ),

              () async {

            if (!mounted) {
              return;
            }


            await loadData(
              showLoading:
              false,
            );
          },
        );
  }

  // ========================================
  // LOAD
  // ========================================

  Future<void> loadData({
    bool showLoading = true,
  }) async {

    if (
    showLoading &&
        mounted
    ) {

      setState(() {
        loading = true;
      });
    }


    try {
      final acceptedResult =
      await backend
          .getAcceptedTrips();

      final results =
      await Future.wait([
        backend.getConversations(),
        backend.getGroups(),
      ]);


      final conversationResult =
      results[0];


      final groupResult =
      results[1];


      final enabled =
      <String>{};


      for (
      final group
      in groupResult
      ) {

        if (
        group['enabled'] ==
            true
        ) {

          final id =
          group['groupId']
              ?.toString();


          if (
          id != null &&
              id.isNotEmpty
          ) {

            enabled.add(
              id,
            );
          }
        }
      }


      if (!mounted) {
        return;
      }


      setState(() {
        acceptedTrips =
            acceptedResult;

        conversations =
            conversationResult;

        enabledGroupIds =
            enabled;

        loading =
        false;
      });

    } catch (error) {

      if (!mounted) {
        return;
      }


      setState(() {
        loading = false;
      });


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Không thể tải tin nhắn: $error',
          ),
        ),
      );
    }
  }

  Future<void>
  refreshAcceptedTrips() async {

    try {

      final result =
      await backend
          .getAcceptedTrips();


      if (!mounted) {
        return;
      }


      setState(() {
        acceptedTrips =
            result;
      });

    } catch (error) {

      debugPrint(
        'REFRESH ACCEPTED TRIPS ERROR: $error',
      );
    }
  }


  // ========================================
  // SYNC
  // ========================================

  Future<void>
  syncConversations() async {

    if (syncing) {
      return;
    }


    setState(() {
      syncing = true;
    });


    try {

      await backend
          .syncConversations();


      await loadData(
        showLoading:
        false,
      );


      if (!mounted) {
        return;
      }


      setState(() {
        lastSyncAt =
            DateTime.now();
      });


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Đã đồng bộ nhóm',
          ),
        ),
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Đồng bộ thất bại: $error',
          ),
        ),
      );

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

  bool matchesSearch(
      Map<String, dynamic> conversation,
      ) {

    if (searchText.isEmpty) {
      return true;
    }


    final name =
        conversation['name']
            ?.toString()
            .toLowerCase() ??
            '';


    final content =
        conversation[
        'lastContent']
            ?.toString()
            .toLowerCase() ??
            '';


    return name.contains(
      searchText,
    ) ||
        content.contains(
          searchText,
        );
  }


  List<Map<String, dynamic>>
  get allFiltered {

    return conversations
        .where(
      matchesSearch,
    )
        .toList();
  }


  List<Map<String, dynamic>>
  get notifyingFiltered {

    return conversations
        .where(
          (conversation) {

        final groupId =
        conversation[
        'groupId']
            ?.toString();


        if (
        groupId == null ||
            !enabledGroupIds
                .contains(
              groupId,
            )
        ) {

          return false;
        }


        return matchesSearch(
          conversation,
        );
      },
    )
        .toList();
  }


  // ========================================
  // TIME
  // ========================================

  String formatTime(
      dynamic timestamp,
      ) {

    if (timestamp == null) {
      return '';
    }


    final value =
    int.tryParse(
      timestamp.toString(),
    );


    if (value == null) {
      return '';
    }


    final date =
    DateTime
        .fromMillisecondsSinceEpoch(
      value,
    );


    final now =
    DateTime.now();


    final sameDay =
        date.year ==
            now.year &&
            date.month ==
                now.month &&
            date.day ==
                now.day;


    if (sameDay) {

      final hour =
      date.hour
          .toString()
          .padLeft(
        2,
        '0',
      );


      final minute =
      date.minute
          .toString()
          .padLeft(
        2,
        '0',
      );


      return '$hour:$minute';
    }


    return '${date.day}/${date.month}';
  }


  // ========================================
  // OPEN CHAT
  // ========================================

  Future<void> openConversation(
      Map<String, dynamic> conversation,
      ) async {

    final groupId =
    conversation['groupId']
        ?.toString();


    if (
    groupId == null ||
        groupId.isEmpty
    ) {
      return;
    }


    final groupName =
        conversation['name']
            ?.toString() ??
            'Nhóm Zalo';


    await Navigator
        .of(context)
        .push(
      MaterialPageRoute(
        builder:
            (_) =>
            ChatPage(
              groupId:
              groupId,

              groupName:
              groupName,
            ),
      ),
    );


    if (!mounted) {
      return;
    }


    await loadData(
      showLoading:
      false,
    );
  }

  String? firstNonEmptyString(
      List<dynamic> values,
      ) {

    for (final value in values) {

      if (value == null) {
        continue;
      }

      final text =
      value
          .toString()
          .trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return null;
  }

  Future<void> openAcceptedTrip(
      Map<String, dynamic> trip,
      ) async {

    // Ho tro ca record moi va record cu.
    final groupId =
    firstNonEmptyString([
      trip['sourceThreadId'],
      trip['groupId'],
      trip['threadId'],
    ]);


    final msgId =
    firstNonEmptyString([
      trip['sourceMsgId'],
      trip['zaloMessageId'],
      trip['msgId'],
    ]);


    final cliMsgId =
    firstNonEmptyString([
      trip['sourceCliMsgId'],
      trip['clientMessageId'],
      trip['cliMsgId'],
    ]);


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


    if (
    (
        msgId == null ||
            msgId.isEmpty
    ) &&
        (
            cliMsgId == null ||
                cliMsgId.isEmpty
        )
    ) {

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
        builder:
            (_) =>
            ChatPage(
              groupId:
              groupId,

              groupName:
              groupName,

              targetMsgId:
              msgId,

              targetCliMsgId:
              cliMsgId,
            ),
      ),
    );
  }

  Future<void> showMessageNotFound(
      String detail,
      ) async {

    if (!mounted) {
      return;
    }


    await showDialog<void>(
      context:
      context,

      builder:
          (dialogContext) {

        return AlertDialog(
          title:
          const Text(
            'Không tìm thấy tin nhắn',
          ),

          content:
          Text(
            detail,
          ),

          actions: [

            TextButton(
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },

              child:
              const Text(
                'OK',
              ),
            ),
          ],
        );
      },
    );
  }


  // ========================================
  // CONVERSATION ITEM
  // ========================================

  // ========================================
// CONVERSATION ITEM
// ========================================

  Widget buildConversationItem(
      Map<String, dynamic> conversation,
      ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    final name =
        conversation['name']
            ?.toString() ??
            'Nhóm Zalo';


    final lastContent =
    conversation['lastContent']
        ?.toString();


    final sender =
    conversation['lastSenderName']
        ?.toString();

    final lastIsSelf =
        conversation['lastIsSelf'] ==
            true;


    final avatar =
    conversation['avatar']
        ?.toString();


    final groupId =
        conversation['groupId']
            ?.toString() ??
            '';


    final notifying =
    enabledGroupIds.contains(
      groupId,
    );


    // ========================================
    // UNREAD
    // ========================================

    final unreadCount =
        int.tryParse(
          conversation['unreadCount']
              ?.toString() ??
              '',
        ) ??
            0;


    final safeUnreadCount =
    unreadCount < 0
        ? 0
        : unreadCount;


    final hasUnread =
        safeUnreadCount >
            0;


    final unreadText =
    safeUnreadCount >
        99
        ? '9+'
        : safeUnreadCount
        .toString();


    // ========================================
    // SUBTITLE
    // ========================================

    String subtitle;


// ========================================
// CHUA CO MESSAGE
// ========================================

    if (
    lastContent == null ||
        lastContent.isEmpty
    ) {

      subtitle =
      'Chưa có tin nhắn mới';


// ========================================
// MESSAGE DO CHINH MINH GUI
// ========================================

    } else if (
    lastIsSelf
    ) {

      subtitle =
      'Bạn: $lastContent';


// ========================================
// MESSAGE NGUOI KHAC GUI
// ========================================

    } else if (
    sender != null &&
        sender.isNotEmpty
    ) {

      subtitle =
      '$sender: $lastContent';


    } else {

      subtitle =
          lastContent;
    }


    // ========================================
    // TIME
    // ========================================

    final timeText =
    formatTime(
      conversation[
      'lastMessageAt'
      ],
    );


    return InkWell(

      onTap:
          () =>
          openConversation(
            conversation,
          ),


      child:
      Padding(

        padding:
        const EdgeInsets.symmetric(
          horizontal:
          16,

          vertical:
          11,
        ),


        child:
        Row(

          children: [

            // ========================================
            // AVATAR
            // ========================================

            CircleAvatar(

              radius:
              27,


              backgroundImage:
              avatar != null &&
                  avatar.isNotEmpty
                  ? NetworkImage(
                avatar,
              )
                  : null,


              child:
              avatar == null ||
                  avatar.isEmpty
                  ? Text(

                name.isNotEmpty
                    ? name[0]
                    .toUpperCase()
                    : '?',

                style:
                const TextStyle(
                  fontSize:
                  20,
                ),
              )
                  : null,
            ),


            const SizedBox(
              width:
              13,
            ),


            // ========================================
            // NAME + LAST MESSAGE
            // ========================================

            Expanded(

              child:
              Column(

                crossAxisAlignment:
                CrossAxisAlignment
                    .start,


                children: [

                  Row(

                    children: [

                      Expanded(

                        child:
                        Text(

                          name,


                          maxLines:
                          1,


                          overflow:
                          TextOverflow
                              .ellipsis,


                          style:
                          TextStyle(

                            fontSize:
                            16,


                            // ========================================
                            // UNREAD -> DAM HON
                            // ========================================

                            fontWeight:
                            hasUnread
                                ? FontWeight
                                .w700
                                : FontWeight
                                .w600,
                          ),
                        ),
                      ),


                      if (
                      notifying
                      )
                        Padding(

                          padding:
                          const EdgeInsets.only(
                            left:
                            6,
                          ),


                          child:
                          Icon(

                            Icons
                                .notifications_active_outlined,


                            size:
                            17,


                            color:
                            hasUnread
                                ? colorScheme
                                .primary
                                : colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),


                  const SizedBox(
                    height:
                    5,
                  ),


                  Text(

                    subtitle,


                    maxLines:
                    1,


                    overflow:
                    TextOverflow
                        .ellipsis,


                    style:
                    TextStyle(

                      color:
                      hasUnread
                          ? colorScheme
                          .onSurface
                          : colorScheme
                          .onSurfaceVariant,


                      fontWeight:
                      hasUnread
                          ? FontWeight
                          .w600
                          : FontWeight
                          .normal,
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(
              width:
              10,
            ),


            // ========================================
            // TIME + UNREAD BADGE
            // ========================================

            Column(

              mainAxisAlignment:
              MainAxisAlignment
                  .center,


              crossAxisAlignment:
              CrossAxisAlignment
                  .end,


              children: [

                Text(

                  timeText,


                  style:
                  TextStyle(

                    fontSize:
                    12,


                    color:
                    hasUnread
                        ? colorScheme
                        .primary
                        : colorScheme
                        .onSurfaceVariant,


                    fontWeight:
                    hasUnread
                        ? FontWeight
                        .w600
                        : FontWeight
                        .normal,
                  ),
                ),


                // ========================================
                // BADGE
                // ========================================

                if (
                hasUnread
                ) ...[

                  const SizedBox(
                    height:
                    6,
                  ),


                  Container(

                    constraints:
                    const BoxConstraints(

                      minWidth:
                      22,

                      minHeight:
                      22,
                    ),


                    padding:
                    const EdgeInsets.symmetric(
                      horizontal:
                      6,

                      vertical:
                      2,
                    ),


                    alignment:
                    Alignment.center,


                    decoration:
                    BoxDecoration(

                      color:
                      colorScheme
                          .primary,


                      borderRadius:
                      BorderRadius.circular(
                        999,
                      ),
                    ),


                    child:
                    Text(

                      unreadText,


                      style:
                      TextStyle(

                        color:
                        colorScheme
                            .onPrimary,


                        fontSize:
                        11,


                        fontWeight:
                        FontWeight
                            .w700,


                        height:
                        1,
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
      List<Map<String, dynamic>> items,
      {
        required String emptyTitle,
        required String emptySubtitle,
      }
      ) {

    if (items.isEmpty) {

      return RefreshIndicator(
        onRefresh:
        loadData,

        child:
        ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),

          children: [

            SizedBox(
              height:
              MediaQuery
                  .of(context)
                  .size
                  .height *
                  0.42,
            ),


            const Icon(
              Icons
                  .chat_bubble_outline,

              size:
              64,
            ),


            const SizedBox(
              height:
              16,
            ),


            Text(
              emptyTitle,

              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                fontSize:
                20,

                fontWeight:
                FontWeight.w600,
              ),
            ),


            const SizedBox(
              height:
              8,
            ),


            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 40,
              ),

              child:
              Text(
                emptySubtitle,

                textAlign:
                TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }


    return RefreshIndicator(
      onRefresh:
      loadData,

      child:
      ListView.separated(
        physics:
        const AlwaysScrollableScrollPhysics(),

        itemCount:
        items.length,

        separatorBuilder:
            (_, _) =>
        const Divider(
          height: 1,
          indent: 72,
        ),

        itemBuilder:
            (
            context,
            index,
            ) {

          return buildConversationItem(
            items[index],
          );
        },
      ),
    );
  }


  // ========================================
  // HISTORY PLACEHOLDER
  // ========================================

  Widget buildAcceptedHistory() {

    if (
    acceptedTrips.isEmpty
    ) {

      return const Center(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [

            Icon(
              Icons.history,
              size: 68,
            ),

            SizedBox(
              height: 16,
            ),

            Text(
              'Chưa có cuốc đã nhận',

              style:
              TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'Các cuốc bạn đã nhận sẽ xuất hiện tại đây.',
            ),
          ],
        ),
      );
    }


    if (
    acceptedFiltered.isEmpty
    ) {

      return const Center(
        child:
        Column(
          mainAxisSize:
          MainAxisSize.min,

          children: [

            Icon(
              Icons.search_off_outlined,
              size: 60,
            ),

            SizedBox(
              height: 16,
            ),

            Text(
              'Không tìm thấy cuốc',

              style:
              TextStyle(
                fontSize: 19,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'Thử tìm bằng nội dung, tên nhóm hoặc người gửi.',
            ),
          ],
        ),
      );
    }


    return RefreshIndicator(
      onRefresh:
      loadData,

      child:
      ListView.separated(

        physics:
        const AlwaysScrollableScrollPhysics(),

        itemCount:
        acceptedFiltered.length,

        separatorBuilder:
            (_, _) =>
        const Divider(
          height: 1,
        ),

        itemBuilder:
            (
            context,
            index,
            ) {

          final trip =
          acceptedFiltered[index];


          final content =
              trip['content']
                  ?.toString() ??
                  'Cuốc đã nhận';


          final groupName =
              trip['groupName']
                  ?.toString() ??
                  'Nhóm Zalo';


          final senderName =
              trip['senderName']
                  ?.toString() ??
                  'Không rõ người gửi';


          final acceptedAt =
          DateTime.tryParse(
            trip['acceptedAt']
                ?.toString() ??
                '',
          );


          String timeText =
              '';


          if (acceptedAt != null) {

            final local =
            acceptedAt.toLocal();


            final hour =
            local.hour
                .toString()
                .padLeft(
              2,
              '0',
            );


            final minute =
            local.minute
                .toString()
                .padLeft(
              2,
              '0',
            );


            timeText =
            '$hour:$minute';
          }


          return ListTile(

            onTap:
                () =>
                openAcceptedTrip(
                  trip,
                ),


            leading:
            const CircleAvatar(
              child:
              Icon(
                Icons.local_taxi,
              ),
            ),


            title:
            Text(
              content,

              maxLines:
              2,

              overflow:
              TextOverflow.ellipsis,
            ),


            subtitle:
            Text(
              '$groupName\n'
                  '$senderName',

              maxLines:
              2,

              overflow:
              TextOverflow.ellipsis,
            ),


            trailing:
            Column(
              mainAxisAlignment:
              MainAxisAlignment.center,

              crossAxisAlignment:
              CrossAxisAlignment.end,

              children: [

                Text(
                  timeText,
                ),

                const SizedBox(
                  height: 4,
                ),

                const Icon(
                  Icons.chevron_right,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>>
  get acceptedFiltered {

    if (searchText.isEmpty) {
      return acceptedTrips;
    }


    return acceptedTrips
        .where(
          (
          trip,
          ) {

        final content =
            trip['content']
                ?.toString()
                .toLowerCase() ??
                '';


        final groupName =
            trip['groupName']
                ?.toString()
                .toLowerCase() ??
                '';


        final senderName =
            trip['senderName']
                ?.toString()
                .toLowerCase() ??
                '';


        return content.contains(
          searchText,
        ) ||
            groupName.contains(
              searchText,
            ) ||
            senderName.contains(
              searchText,
            );
      },
    )
        .toList();
  }

  @override
  void dispose() {

    realtimeSubscription
        ?.cancel();


    realtimeRefreshTimer
        ?.cancel();


    backend.disconnect();


    tabController.dispose();

    searchController.dispose();


    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    if (loading) {

      return const SafeArea(
        child:
        Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }


    return SafeArea(
      child:
      Column(
        children: [

          // ========================================
          // TOP TABS
          // ========================================

          TabBar(
            controller:
            tabController,

            isScrollable:
            true,

            tabs:
            const [

              Tab(
                text:
                'Tất cả',
              ),


              Tab(
                icon:
                Icon(
                  Icons
                      .notifications_none,

                  size:
                  18,
                ),

                text:
                'Đang thông báo',
              ),


              Tab(
                icon:
                Icon(
                  Icons.history,

                  size:
                  18,
                ),

                text:
                'Lịch sử nhận',
              ),
            ],
          ),


          const SizedBox(
            height:
            12,
          ),


          // ========================================
          // SEARCH + SETTINGS
          // ========================================

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 16,
            ),

            child:
            Row(
              children: [

                Expanded(
                  child:
                  TextField(
                    controller:
                    searchController,

                    decoration:
                    InputDecoration(
                      hintText:
                      'Tìm kiếm cuộc trò chuyện...',

                      prefixIcon:
                      const Icon(
                        Icons.search,
                      ),

                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),
                ),


                const SizedBox(
                  width:
                  8,
                ),


                IconButton(
                  onPressed:
                  widget
                      .onOpenSettings,

                  icon:
                  const Icon(
                    Icons.settings,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),


          const SizedBox(
            height:
            8,
          ),


          // ========================================
          // SYNC LINE
          // ========================================

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal:
              16,
            ),

            child:
            Row(
              children: [

                Expanded(
                  child:
                  Text(
                    lastSyncAt ==
                        null
                        ? '${enabledGroupIds.length}/${conversations.length} nhóm đang bật thông báo'
                        : 'Đã đồng bộ nhóm',

                    style:
                    Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ),


                TextButton.icon(
                  onPressed:
                  syncing
                      ? null
                      : syncConversations,

                  icon:
                  syncing
                      ? const SizedBox(
                    width:
                    16,
                    height:
                    16,

                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                    ),
                  )
                      : const Icon(
                    Icons.sync,
                  ),

                  label:
                  const Text(
                    'Đồng bộ nhóm',
                  ),
                ),
              ],
            ),
          ),


          const Divider(
            height:
            1,
          ),


          // ========================================
          // TAB CONTENT
          // ========================================

          Expanded(
            child:
            TabBarView(
              controller:
              tabController,

              children: [

                buildConversationList(
                  allFiltered,

                  emptyTitle:
                  'Chưa có hội thoại',

                  emptySubtitle:
                  'Các nhóm Zalo sẽ xuất hiện tại đây sau khi đồng bộ.',
                ),


                buildConversationList(
                  notifyingFiltered,

                  emptyTitle:
                  'Chưa có nhóm đang thông báo',

                  emptySubtitle:
                  'Hãy bật nhóm trong phần Nhóm nhận thông báo.',
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