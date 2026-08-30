import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/backend_service.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() =>
      _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final BackendService backend =
  BackendService(
    baseUrl: AppConfig.backendUrl,
  );

  final TextEditingController
  searchController =
  TextEditingController();

  List<Map<String, dynamic>> groups = [];

  bool loading = true;

  String searchText = '';

  final Set<String> updatingGroups = {};


  @override
  void initState() {
    super.initState();

    loadGroups();

    searchController.addListener(() {
      setState(() {
        searchText =
            searchController.text
                .trim()
                .toLowerCase();
      });
    });
  }


  Future<void> loadGroups() async {
    setState(() {
      loading = true;
    });

    try {
      final result =
      await backend.getGroups();

      if (!mounted) return;

      setState(() {
        groups = result;
      });

    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi tải nhóm: $error',
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


  Future<void> changeGroupStatus(
      Map<String, dynamic> group,
      bool enabled,
      ) async {
    final groupId =
    group['groupId'].toString();

    if (updatingGroups.contains(groupId)) {
      return;
    }

    setState(() {
      updatingGroups.add(groupId);
    });

    try {
      final result =
      await backend.toggleGroup(
        groupId,
        enabled,
      );

      if (!mounted) return;

      setState(() {
        group['enabled'] = result;
      });

    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Không thể cập nhật nhóm: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingGroups.remove(groupId);
        });
      }
    }
  }


  List<Map<String, dynamic>>
  get filteredGroups {
    if (searchText.isEmpty) {
      return groups;
    }

    return groups.where((group) {
      final name =
          group['name']
              ?.toString()
              .toLowerCase() ??
              '';

      return name.contains(searchText);
    }).toList();
  }


  int get enabledCount {
    return groups
        .where(
          (group) =>
      group['enabled'] == true,
    )
        .length;
  }


  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return Scaffold(

      // ========================================
      // APP BAR + BACK
      // ========================================

      appBar:
      AppBar(

        leading:
        IconButton(
          icon:
          const Icon(
            Icons.arrow_back,
          ),

          onPressed:
              () {

            Navigator.of(context)
                .pop();
          },
        ),

        title:
        const Text(
          'Quản lý nhóm',
        ),
      ),


      body:
      SafeArea(

        child:
        RefreshIndicator(

          onRefresh:
          loadGroups,


          child:
          ListView(

            physics:
            const AlwaysScrollableScrollPhysics(),

            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24,
            ),


            children: [

              // ========================================
              // SEARCH
              // ========================================

              Row(
                children: [

                  Expanded(
                    child:
                    TextField(

                      controller:
                      searchController,

                      decoration:
                      InputDecoration(

                        prefixIcon:
                        const Icon(
                          Icons.search,
                        ),

                        hintText:
                        'Tìm nhóm...',

                        filled:
                        true,

                        fillColor:
                        colorScheme
                            .surfaceContainerHighest,

                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),

                          borderSide:
                          BorderSide.none,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),

                          borderSide:
                          BorderSide.none,
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),

                          borderSide:
                          BorderSide(
                            color:
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(
                    width: 10,
                  ),


                  // Nút filter giao diện.
                  // Logic filter chi tiết sẽ làm sau.
                  IconButton(
                    onPressed:
                        () {

                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        const SnackBar(
                          content:
                          Text(
                            'Bộ lọc danh sách nhóm sẽ được thêm sau',
                          ),
                        ),
                      );
                    },

                    icon:
                    const Icon(
                      Icons.filter_alt,
                      size: 30,
                    ),

                    tooltip:
                    'Lọc nhóm',
                  ),
                ],
              ),


              const SizedBox(
                height: 22,
              ),


              // ========================================
              // GROUP SUMMARY
              // ========================================

              Row(
                children: [

                  Icon(
                    Icons.notifications_active_outlined,

                    color:
                    colorScheme.primary,

                    size: 22,
                  ),


                  const SizedBox(
                    width: 10,
                  ),


                  Expanded(
                    child:
                    Text(
                      'Nhóm ($enabledCount/${groups.length}) bật thông báo',

                      style:
                      const TextStyle(
                        fontSize: 17,
                        fontWeight:
                        FontWeight.w600,
                      ),
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


              // ========================================
              // LOADING
              // ========================================

              if (loading)
                const Padding(
                  padding:
                  EdgeInsets.all(
                    50,
                  ),

                  child:
                  Center(
                    child:
                    CircularProgressIndicator(),
                  ),
                )


              // ========================================
              // EMPTY
              // ========================================

              else if (
              filteredGroups.isEmpty
              )
                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    vertical: 70,
                  ),

                  child:
                  Column(
                    children: [

                      Icon(
                        Icons.groups_outlined,

                        size: 70,

                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),


                      const SizedBox(
                        height: 16,
                      ),


                      const Text(
                        'Không tìm thấy nhóm',

                        style:
                        TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )


              // ========================================
              // GROUP LIST
              // ========================================

              else
                ...filteredGroups.map(
                      (group) {

                    final groupId =
                    group['groupId']
                        .toString();


                    final enabled =
                        group['enabled'] ==
                            true;


                    final updating =
                    updatingGroups
                        .contains(
                      groupId,
                    );


                    final memberCount =
                    group[
                    'totalMember'
                    ];


                    final name =
                        group['name']
                            ?.toString() ??
                            'Unknown Group';


                    // Ký tự đầu làm avatar khi chưa có ảnh.
                    final firstLetter =
                    name.isNotEmpty
                        ? name[0]
                        .toUpperCase()
                        : '?';


                    return Column(
                      children: [

                        ListTile(

                          contentPadding:
                          const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),


                          // ========================================
                          // AVATAR
                          // ========================================

                          leading:
                          CircleAvatar(

                            radius:
                            26,

                            backgroundColor:
                            enabled
                                ? colorScheme
                                .primaryContainer
                                : colorScheme
                                .surfaceContainerHighest,

                            child:
                            Text(
                              firstLetter,

                              style:
                              TextStyle(
                                fontSize: 20,

                                color:
                                enabled
                                    ? colorScheme
                                    .onPrimaryContainer
                                    : colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),


                          // ========================================
                          // GROUP NAME
                          // ========================================

                          title:
                          Text(
                            name,

                            maxLines:
                            2,

                            overflow:
                            TextOverflow
                                .ellipsis,

                            style:
                            const TextStyle(
                              fontSize: 17,
                              fontWeight:
                              FontWeight.w500,
                            ),
                          ),


                          // ========================================
                          // MEMBER INFO
                          // ========================================

                          subtitle:
                          Padding(
                            padding:
                            const EdgeInsets.only(
                              top: 4,
                            ),

                            child:
                            Text(
                              memberCount !=
                                  null
                                  ? '$memberCount thành viên'
                                  : 'Nhóm Zalo',

                              style:
                              TextStyle(
                                color:
                                colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),


                          // ========================================
                          // SWITCH
                          // ========================================

                          trailing:
                          updating
                              ? const SizedBox(
                            width: 28,
                            height: 28,

                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2,
                            ),
                          )
                              : Switch(
                            value:
                            enabled,

                            onChanged:
                                (value) {

                              changeGroupStatus(
                                group,
                                value,
                              );
                            },
                          ),
                        ),


                        const Divider(
                          height: 1,
                          indent: 66,
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}