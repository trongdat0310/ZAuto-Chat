import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../config/app_config.dart';
import '../services/backend_service.dart';

import '../controllers/settings_controller.dart';

class SettingsPage
    extends StatefulWidget {

  final SettingsController settingsController;

  const SettingsPage({

    super.key,

    required this.settingsController,

  });


  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsPage> {

  final BackendService backend =
  BackendService(
    baseUrl:
    AppConfig.backendUrl,
  );

  // ========================================
  // GIAO DIEN
  // ========================================

  String selectedTheme = ThemeService.currentKey;

  late int currentTripDisplaySeconds;
  late double notificationFontSize;

  late String currentAcceptButtonPosition;

  late String currentAcceptReplyText;

  // ========================================
  // BO LOC TIN NHAN
  // Tam thoi luu local.
  // Buoc sau se noi vao backend.
  // ========================================

  bool showImages =
  true;

  bool deduplicateMessages =
  true;

  bool showVoiceMessages =
  true;

  bool transcribeVoiceMessages =
  false;


  // ========================================
  // SETTINGS TILE
  // ========================================

  Widget settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool enabled = true,
  }) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    final foreground =
    enabled
        ? colorScheme.onSurface
        : colorScheme
        .onSurface
        .withValues(
      alpha: 0.38,
    );


    return InkWell(
      onTap:
      enabled
          ? onTap
          : null,

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

            Container(
              width: 52,
              height: 52,

              decoration:
              BoxDecoration(
                color:
                colorScheme
                    .primaryContainer,

                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),

              child:
              Icon(
                icon,

                color:
                enabled
                    ? colorScheme.primary
                    : foreground,
              ),
            ),


            const SizedBox(
              width: 16,
            ),


            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(
                    title,

                    style:
                    TextStyle(
                      fontSize: 17,

                      fontWeight:
                      FontWeight.w500,

                      color:
                      foreground,
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
                      enabled
                          ? colorScheme
                          .onSurfaceVariant
                          : foreground,
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(
              width: 10,
            ),


            if (trailing != null)
              trailing
            else
              Icon(
                Icons.chevron_right,

                color:
                foreground,
              ),
          ],
        ),
      ),
    );
  }


  // ========================================
  // GIAO DIEN VA TUONG TAC
  // ========================================

  void openInterfaceSettings() {

    showModalBottomSheet<void>(
      context:
      context,

      isScrollControlled:
      true,

      useSafeArea:
      true,

      showDragHandle:
      true,

      builder:
          (
          bottomSheetContext,
          ) {

        return StatefulBuilder(
          builder:
              (
              context,
              setSheetState,
              ) {

            final colorScheme =
                Theme.of(context)
                    .colorScheme;


            return SingleChildScrollView(
              padding:
              EdgeInsets.fromLTRB(
                20,
                6,
                20,
                24 +
                    MediaQuery.of(
                      context,
                    ).viewInsets.bottom,
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  const Text(
                    'Giao diện và Tương tác',

                    style:
                    TextStyle(
                      fontSize: 25,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),


                  const SizedBox(
                    height: 22,
                  ),


                  // ==================================
                  // GIAO DIEN + FONT
                  // ==================================

                  Card(
                    clipBehavior:
                    Clip.antiAlias,

                    child:
                    Column(
                      children: [

                        Padding(
                          padding:
                          const EdgeInsets.all(
                            18,
                          ),

                          child:
                          Row(
                            children: [

                              const Text(
                                'Giao diện',

                                style:
                                TextStyle(
                                  fontSize: 16,
                                ),
                              ),


                              const Spacer(),


                              SegmentedButton<String>(
                                segments:
                                const [

                                  ButtonSegment(
                                    value:
                                    'light',

                                    label:
                                    Text(
                                      'Sáng',
                                    ),
                                  ),

                                  ButtonSegment(
                                    value:
                                    'dark',

                                    label:
                                    Text(
                                      'Tối',
                                    ),
                                  ),

                                  ButtonSegment(
                                    value:
                                    'system',

                                    label:
                                    Text(
                                      'Hệ thống',
                                    ),
                                  ),
                                ],

                                selected:
                                {
                                  selectedTheme,
                                },

                                showSelectedIcon:
                                false,

                                onSelectionChanged:
                                    (
                                    value,
                                    ) async {

                                  if (
                                  value.isEmpty
                                  ) {
                                    return;
                                  }


                                  final selected =
                                      value.first;


                                  // ========================================
                                  // UPDATE SETTINGS UI
                                  // ========================================

                                  setState(() {
                                    selectedTheme =
                                        selected;
                                  });


                                  // ========================================
                                  // DOI THEME TOAN BO APP
                                  // ========================================

                                  await widget
                                      .settingsController
                                      .updateTheme(
                                    selected,
                                  );

                                  // ========================================
                                  // UPDATE BOTTOM SHEET
                                  // ========================================

                                  setSheetState(
                                        () {},
                                  );
                                },
                              ),
                            ],
                          ),
                        ),


                        const Divider(
                          height: 1,
                        ),


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

                              Row(
                                children: [

                                  const Text(
                                    'Cỡ chữ thông báo',

                                    style:
                                    TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),


                                  const Spacer(),


                                  Text(
                                    notificationFontSize
                                        .round()
                                        .toString(),

                                    style:
                                    TextStyle(
                                      fontSize: 16,

                                      fontWeight:
                                      FontWeight.bold,

                                      color:
                                      colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),


                              Slider(
                                min:
                                10,

                                max:
                                30,

                                divisions:
                                20,

                                value:
                                notificationFontSize,

                                onChanged:
                                    (
                                    value,
                                    ) async {

                                  // ========================================
                                  // UPDATE SETTINGS LOCAL UI
                                  // ========================================

                                  setState(() {
                                    notificationFontSize =
                                        value;
                                  });


                                  // ========================================
                                  // UPDATE TOAN APP
                                  // ========================================

                                  await widget
                                      .settingsController
                                      .updateFontSize(
                                    value,
                                  );

                                  // ========================================
                                  // UPDATE BOTTOM SHEET
                                  // ========================================

                                  setSheetState(
                                        () {},
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),


                  const SizedBox(
                    height: 28,
                  ),


                  Center(
                    child:
                    Text(
                      'TƯƠNG TÁC VỚI THẺ CUỐC',

                      style:
                      TextStyle(
                        fontSize: 13,

                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),


                  const SizedBox(
                    height: 12,
                  ),


                  Card(
                    clipBehavior:
                    Clip.antiAlias,

                    child:
                    Column(
                      children: [

                        // ==============================
                        // TIME
                        // ==============================

                        ListTile(
                          title:
                          const Text(
                            'Thời gian hiện thông báo',
                          ),

                          trailing:
                          Row(
                            mainAxisSize:
                            MainAxisSize.min,

                            children: [

                              Text(
                                '${currentTripDisplaySeconds}s',

                                style:
                                TextStyle(
                                  color:
                                  colorScheme.primary,

                                  fontSize: 16,
                                ),
                              ),


                              const SizedBox(
                                width: 6,
                              ),


                              const Icon(
                                Icons.chevron_right,
                              ),
                            ],
                          ),

                          onTap:
                              () async {

                            await openTripDurationPicker();


                            if (!mounted) {
                              return;
                            }


                            // Rebuild bottom sheet "Giao diện và Tương tác"
                            setSheetState(
                                  () {},
                            );
                          },
                        ),


                        const Divider(
                          height: 1,
                        ),


                        // ==============================
                        // QUICK ACCEPT - DE SAU
                        // ==============================

                        SwitchListTile(
                          value:
                          false,

                          onChanged:
                          null,

                          title:
                          const Text(
                            'Chạm vào tin nhắn để nhận nhanh',
                          ),

                          secondary:
                          const Icon(
                            Icons.lock_outline,
                          ),
                        ),


                        const Divider(
                          height: 1,
                        ),


                        // ==============================
                        // SWIPE REPLY - DE SAU
                        // ==============================

                        SwitchListTile(
                          value:
                          false,

                          onChanged:
                          null,

                          title:
                          const Text(
                            'Vuốt để trả lời thông báo',
                          ),

                          secondary:
                          const Icon(
                            Icons.lock_outline,
                          ),
                        ),


                        const Divider(
                          height: 1,
                        ),


                        // ==============================
                        // ACCEPT BUTTON POSITION
                        // ==============================

                        ListTile(
                          title:
                          const Text(
                            'Vị trí nút nhận',
                          ),

                          trailing:
                          Row(
                            mainAxisSize:
                            MainAxisSize.min,

                            children: [

                              Text(
                                currentAcceptButtonPosition ==
                                    'left'
                                    ? 'Bên trái'
                                    : 'Bên phải',

                                style:
                                TextStyle(
                                  color:
                                  colorScheme.primary,

                                  fontSize:
                                  16,
                                ),
                              ),


                              const SizedBox(
                                width: 6,
                              ),


                              const Icon(
                                Icons.chevron_right,
                              ),
                            ],
                          ),

                          onTap:
                              () async {

                            await openAcceptButtonPositionPicker();


                            if (!mounted) {
                              return;
                            }


                            setSheetState(
                                  () {},
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // ========================================
  // PICK 5 / 10 / 15 GIAY
  // ========================================

  Future<void> openTripDurationPicker() async {

    await showModalBottomSheet<void>(
      context:
      context,

      showDragHandle:
      true,

      builder:
          (
          pickerContext,
          ) {

        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              20,
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                const Padding(
                  padding:
                  EdgeInsets.all(
                    12,
                  ),

                  child:
                  Text(
                    'Thời gian hiện thông báo',

                    style:
                    TextStyle(
                      fontSize: 22,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                RadioGroup<int>(
                  groupValue: currentTripDisplaySeconds,

                  onChanged:
                      (
                      value,
                      ) async {

                    if (
                    value ==
                        null
                    ) {
                      return;
                    }


                    final oldValue =
                        currentTripDisplaySeconds;


                    // ========================================
                    // 1. UPDATE UI NGAY
                    // ========================================

                    setState(() {
                      currentTripDisplaySeconds =
                          value;
                    });


                    // ========================================
                    // 2. UPDATE HOME PAGE
                    // ========================================

                    await widget
                        .settingsController
                        .updateTripDisplaySeconds(
                      value,
                    );

                    try {

                      // ========================================
                      // LUU THOI GIAN LEN BACKEND
                      // ========================================

                      await backend
                          .updateMessageSettings(
                        dedupeWindowSeconds:
                        value,
                      );

                      // ========================================
                      // KIEM TRA STATE SETTINGS PAGE
                      // ========================================

                      if (!mounted) {
                        return;
                      }


                      // ========================================
                      // KIEM TRA CONTEXT CUA PICKER
                      // SAU ASYNC GAP
                      // ========================================

                      if (!pickerContext.mounted) {
                        return;
                      }


                      // ========================================
                      // DONG PICKER 5 / 10 / 15 GIAY
                      // ========================================

                      Navigator.of(
                        pickerContext,
                      ).pop();

                    } catch (error) {

                      if (!mounted) {
                        return;
                      }


                      // ========================================
                      // ROLLBACK NEU BACKEND LOI
                      // ========================================

                      setState(() {
                        currentTripDisplaySeconds =
                            oldValue;
                      });

                      await widget
                          .settingsController
                          .updateTripDisplaySeconds(
                        oldValue,
                      );

                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger
                          .of(context)
                          .showSnackBar(
                        SnackBar(
                          content:
                          Text(
                            'Không thể lưu thời gian thông báo: $error',
                          ),
                        ),
                      );
                    }
                  },

                  child:
                  Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      for (
                      final seconds
                      in [
                        5,
                        10,
                        15,
                      ]
                      )
                        RadioListTile<int>(
                          value:
                          seconds,

                          title:
                          Text(
                            '$seconds giây',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void>
  loadMessageSettings() async {

    try {

      final settings =
      await backend
          .getMessageSettings();


      if (!mounted) {
        return;
      }

      final rawWindow =
        settings[
          'dedupeWindowSeconds'
        ];

      final savedSeconds =
        rawWindow is num
            ? rawWindow.toInt()
            : null;

      setState(() {

        deduplicateMessages =
            settings[
            'deduplicateMessages'
            ] !=
                false;


        if (
        savedSeconds == 5 ||
            savedSeconds == 10 ||
            savedSeconds == 15
        ) {

          currentTripDisplaySeconds =
          savedSeconds!;
        }
      });

      if (
      savedSeconds == 5 ||
          savedSeconds == 10 ||
          savedSeconds == 15
      ) {

        await widget
            .settingsController
            .updateTripDisplaySeconds(
          savedSeconds!,
        );
      }

    } catch (error) {

      debugPrint(
        'LOAD MESSAGE SETTINGS ERROR: $error',
      );
    }
  }

  Future<void> openAcceptReplyTextEditor() async {

    final result =
    await showModalBottomSheet<String>(

      context:
      context,

      isScrollControlled:
      true,

      useSafeArea:
      true,

      showDragHandle:
      true,

      builder:
          (
          sheetContext,
          ) {

        return _AcceptReplyEditorSheet(
          initialText:
          currentAcceptReplyText,
        );
      },
    );


    if (
    result == null ||
        result.trim().isEmpty ||
        !mounted
    ) {
      return;
    }


    final value =
    result.trim();


    // ========================================
    // UPDATE UI
    // ========================================

    setState(() {

      currentAcceptReplyText =
          value;
    });


    // ========================================
    // SAVE SETTINGS
    // ========================================

    try {

      await widget
          .settingsController
          .updateAcceptReplyText(
        value,
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
            'Không thể lưu nội dung trả lời: $error',
          ),
        ),
      );
    }
  }

  Future<void>
  openAcceptButtonPositionPicker() async {

    await showModalBottomSheet<void>(
      context:
      context,

      showDragHandle:
      true,

      builder:
          (
          pickerContext,
          ) {

        return SafeArea(
          child:
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              20,
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                const Padding(
                  padding:
                  EdgeInsets.all(
                    12,
                  ),

                  child:
                  Text(
                    'Vị trí nút nhận',

                    style:
                    TextStyle(
                      fontSize:
                      22,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),


                RadioGroup<String>(
                  groupValue:
                  currentAcceptButtonPosition,

                  onChanged:
                      (
                      value,
                      ) async {

                    if (
                    value ==
                        null
                    ) {
                      return;
                    }


                    setState(() {
                      currentAcceptButtonPosition =
                          value;
                    });


                    await widget
                        .settingsController
                        .updateAcceptButtonPosition(
                      value,
                    );

                    if (!pickerContext.mounted) {
                      return;
                    }

                    Navigator.of(
                      pickerContext,
                    ).pop();
                  },

                  child:
                  const Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      RadioListTile<String>(
                        value:
                        'left',

                        title:
                        Text(
                          'Bên trái',
                        ),

                        secondary:
                        Icon(
                          Icons.arrow_back,
                        ),
                      ),


                      RadioListTile<String>(
                        value:
                        'right',

                        title:
                        Text(
                          'Bên phải',
                        ),

                        secondary:
                        Icon(
                          Icons.arrow_forward,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // ========================================
  // BO LOC TIN NHAN
  // ========================================

  void openMessageFilters() {

    showModalBottomSheet<void>(
      context:
      context,

      isScrollControlled:
      true,

      useSafeArea:
      true,

      showDragHandle:
      true,

      builder:
          (
          bottomSheetContext,
          ) {

        return StatefulBuilder(
          builder:
              (
              context,
              setSheetState,
              ) {

            final colorScheme =
                Theme.of(context)
                    .colorScheme;


            return SingleChildScrollView(
              padding:
              const EdgeInsets.fromLTRB(
                20,
                6,
                20,
                28,
              ),

              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  const Text(
                    'Bộ lọc tin nhắn',

                    style:
                    TextStyle(
                      fontSize: 25,

                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),


                  const SizedBox(
                    height: 22,
                  ),


                  Card(
                    clipBehavior:
                    Clip.antiAlias,

                    child:
                    Column(
                      children: [

                        SwitchListTile(
                          value:
                          showImages,

                          title:
                          const Text(
                            'Hiển thị ảnh',
                          ),

                          onChanged:
                              (
                              value,
                              ) {

                            // ========================================
                            // TAM THOI CHI DOI UI
                            // CHUC NANG ANH SE NOI BACKEND SAU
                            // ========================================

                            setState(() {
                              showImages =
                                  value;
                            });


                            setSheetState(
                                  () {},
                            );
                          },
                        ),

                        const Divider(
                          height: 1,
                        ),

                        SwitchListTile(
                          value:
                          deduplicateMessages,

                          title:
                          const Text(
                            'Lọc trùng thông báo',
                          ),

                          subtitle:
                          const Text(
                            'Bỏ qua cuốc trùng khi thông báo trước vẫn đang hiển thị',
                          ),

                          onChanged:
                              (
                              value,
                              ) async {

                            final oldValue =
                                deduplicateMessages;


                            // ========================================
                            // 1. DOI UI NGAY
                            // ========================================

                            setState(() {
                              deduplicateMessages =
                                  value;
                            });


                            setSheetState(
                                  () {},
                            );


                            try {

                              // ========================================
                              // 2. LUU BACKEND
                              // ========================================

                              await backend
                                  .updateMessageSettings(
                                deduplicateMessages:
                                value,
                              );

                            } catch (error) {

                              // ========================================
                              // STATE SETTINGS PAGE
                              // ========================================

                              if (!mounted) {
                                return;
                              }


                              // ========================================
                              // CONTEXT CUA BOTTOM SHEET
                              //
                              // Phai check chinh BuildContext nay
                              // sau await.
                              // ========================================

                              if (!context.mounted) {
                                return;
                              }


                              // ========================================
                              // 3. ROLLBACK NEU SERVER LOI
                              // ========================================

                              setState(() {
                                deduplicateMessages =
                                    oldValue;
                              });


                              setSheetState(
                                    () {},
                              );

                              if (!mounted) {
                                return;
                              }

                              ScaffoldMessenger
                                  .of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content:
                                  Text(
                                    'Không thể lưu Lọc trùng: $error',
                                  ),
                                ),
                              );
                            }
                          },
                        ),

                        const Divider(
                          height: 1,
                        ),


                        ListTile(
                          leading:
                          Container(
                            width: 46,
                            height: 46,

                            decoration:
                            BoxDecoration(
                              color:
                              colorScheme
                                  .primaryContainer,

                              borderRadius:
                              BorderRadius.circular(
                                12,
                              ),
                            ),

                            child:
                            const Icon(
                              Icons.info_outline,
                            ),
                          ),

                          title:
                          const Text(
                            'Lọc trùng hoạt động thế nào?',
                          ),

                          trailing:
                          const Icon(
                            Icons.chevron_right,
                          ),

                          onTap:
                          showDuplicateInfo,
                        ),
                      ],
                    ),
                  ),


                  const SizedBox(
                    height: 28,
                  ),


                  Center(
                    child:
                    Text(
                      'TIN NHẮN THOẠI',

                      style:
                      TextStyle(
                        fontSize: 13,

                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),


                  const SizedBox(
                    height: 12,
                  ),


                  Card(
                    clipBehavior:
                    Clip.antiAlias,

                    child:
                    Column(
                      children: [

                        SwitchListTile(
                          value:
                          showVoiceMessages,

                          title:
                          const Text(
                            'Hiển thị tin nhắn thoại',
                          ),

                          onChanged:
                              (
                              value,
                              ) {

                            setState(() {
                              showVoiceMessages =
                                  value;
                            });


                            setSheetState(
                                  () {},
                            );
                          },
                        ),


                        const Divider(
                          height: 1,
                        ),


                        SwitchListTile(
                          value:
                          transcribeVoiceMessages,

                          title:
                          const Text(
                            'Phiên âm tin nhắn thoại',
                          ),

                          onChanged:
                          showVoiceMessages
                              ? (
                              value,
                              ) {

                            setState(() {
                              transcribeVoiceMessages =
                                  value;
                            });


                            setSheetState(
                                  () {},
                            );
                          }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // ========================================
  // DUPLICATE INFO
  // ========================================

  void showDuplicateInfo() {

    showDialog<void>(
      context:
      context,

      builder:
          (
          dialogContext,
          ) {

        return AlertDialog(
          title:
          const Text(
            'Hướng dẫn Lọc trùng thông báo',
          ),

          content:
          const Text(
            'Khi Lọc trùng thông báo được bật, ZChatAuto sẽ so sánh người gửi và nội dung cuốc.\n\n'
                'Nếu cùng một người gửi đăng cùng một nội dung trong nhiều nhóm trong thời gian thông báo trước đó vẫn đang hiển thị, hệ thống chỉ hiển thị cuốc đó một lần.\n\n'
                'Khoảng thời gian lọc trùng sử dụng đúng thời gian bạn chọn tại Giao diện và Tương tác: 5, 10 hoặc 15 giây.\n\n'
                'Nếu nội dung giống nhau nhưng do hai người khác nhau gửi, các cuốc vẫn được hiển thị riêng.',
          ),

          actions: [

            SizedBox(
              width:
              double.infinity,

              child:
              FilledButton(
                onPressed:
                    () {

                  Navigator.of(
                    dialogContext,
                  ).pop();
                },

                child:
                const Text(
                  'Đã hiểu',
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  // ========================================
  // SOUND
  // ANH SO 5 CHUA DUOC GUI
  // ========================================

  void openSoundSettings() {

    showModalBottomSheet<void>(
      context:
      context,

      showDragHandle:
      true,

      builder:
          (
          context,
          ) {

        return const SafeArea(
          child:
          Padding(
            padding:
            EdgeInsets.fromLTRB(
              24,
              8,
              24,
              40,
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(
                  'Âm thanh và Đọc thông báo',

                  style:
                  TextStyle(
                    fontSize: 24,

                    fontWeight:
                    FontWeight.bold,
                  ),
                ),


                SizedBox(
                  height: 20,
                ),


                Text(
                  'Phần giao diện này sẽ được hoàn thiện theo ảnh số 5.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // ========================================
  // MAIN
  // ========================================

  @override
  Widget build(
      BuildContext context,
      ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return SafeArea(
      child:
      ListView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          30,
        ),

        children: [

          const Center(
            child:
            Text(
              'Cài đặt',

              style:
              TextStyle(
                fontSize: 28,

                fontWeight:
                FontWeight.w500,
              ),
            ),
          ),


          const SizedBox(
            height: 28,
          ),


          // ========================================
          // MAIN SETTINGS
          // ========================================

          Card(
            clipBehavior:
            Clip.antiAlias,

            child:
            Column(
              children: [

                settingTile(
                  icon:
                  Icons.palette_outlined,

                  title:
                  'Giao diện và Tương tác',

                  subtitle:
                  'Chủ đề, cỡ chữ, thẻ cuốc...',

                  onTap:
                  openInterfaceSettings,
                ),


                const Divider(
                  height: 1,
                ),


                settingTile(
                  icon:
                  Icons.filter_alt_outlined,

                  title:
                  'Bộ lọc tin nhắn',

                  subtitle:
                  'Hình ảnh, tin thoại, lọc trùng...',

                  onTap:
                  openMessageFilters,
                ),


                const Divider(
                  height: 1,
                ),


                settingTile(
                  icon:
                  Icons.volume_up_outlined,

                  title:
                  'Âm thanh và Đọc thông báo',

                  subtitle:
                  'Chuông báo cuốc mới, đọc nội dung cuốc',

                  onTap:
                  openSoundSettings,
                ),
              ],
            ),
          ),


          const SizedBox(
            height: 28,
          ),


          Text(
            'TRẢ LỜI',

            style:
            TextStyle(
              color:
              colorScheme
                  .onSurfaceVariant,

              fontSize: 14,
            ),
          ),


          const SizedBox(
            height: 10,
          ),


          // ========================================
          // REPLY - CHUA LAM
          // ========================================

          Card(
            clipBehavior:
            Clip.antiAlias,

            child:
            Column(
              children: [

                settingTile(
                  icon:
                  Icons.edit_outlined,

                  title:
                  'Nội dung trả lời',

                  subtitle:
                  '"$currentAcceptReplyText"',

                  onTap:
                  openAcceptReplyTextEditor,
                ),


                const Divider(
                  height: 1,
                ),


                settingTile(
                  icon:
                  Icons.list_alt_outlined,

                  title:
                  'Mẫu trả lời',

                  subtitle:
                  '4 mẫu hệ thống',

                  enabled:
                  false,

                  trailing:
                  const Row(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      Icon(
                        Icons.lock_outline,
                      ),

                      SizedBox(
                        width: 8,
                      ),

                      Icon(
                        Icons.chevron_right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {

    super.initState();


    final settings =
        widget
            .settingsController
            .settings;


    selectedTheme =
        settings
            .themeMode
            .name;


    currentTripDisplaySeconds =
        settings
            .tripDisplaySeconds;


    notificationFontSize =
        settings
            .chatFontSize;


    currentAcceptButtonPosition =
        settings
            .acceptButtonPosition;

    currentAcceptReplyText =
        settings
            .acceptReplyText;


    loadMessageSettings();
  }

}

class _AcceptReplyEditorSheet
    extends StatefulWidget {

  final String initialText;

  const _AcceptReplyEditorSheet({
    required this.initialText,
  });

  @override
  State<_AcceptReplyEditorSheet>
  createState() =>
      _AcceptReplyEditorSheetState();
}


class _AcceptReplyEditorSheetState
    extends State<_AcceptReplyEditorSheet> {

  late final TextEditingController controller;


  @override
  void initState() {
    super.initState();

    controller =
        TextEditingController(
          text:
          widget.initialText,
        );
  }


  @override
  void dispose() {

    controller.dispose();

    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return Padding(

      padding:
      EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 +
            MediaQuery.of(
              context,
            ).viewInsets.bottom,
      ),

      child:
      Column(

        mainAxisSize:
        MainAxisSize.min,

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          Text(
            'Nội dung trả lời',

            style:
            Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontWeight:
              FontWeight.bold,
            ),
          ),


          const SizedBox(
            height: 8,
          ),


          Text(
            'Đây là nội dung ZChatAuto sẽ gửi khi bạn nhận cuốc.',

            style:
            TextStyle(
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ),


          const SizedBox(
            height: 18,
          ),


          TextField(

            controller:
            controller,

            autofocus:
            true,

            maxLength:
            200,

            minLines:
            1,

            maxLines:
            4,

            textInputAction:
            TextInputAction.done,

            decoration:
            const InputDecoration(

              labelText:
              'Nội dung',

              hintText:
              'Ví dụ: Nhận',

              border:
              OutlineInputBorder(),
            ),
          ),


          const SizedBox(
            height: 8,
          ),


          Row(

            children: [

              Expanded(
                child:
                OutlinedButton(
                  onPressed:
                      () {

                    Navigator.of(
                      context,
                    ).pop();
                  },

                  child:
                  const Text(
                    'HỦY',
                  ),
                ),
              ),


              const SizedBox(
                width: 12,
              ),


              Expanded(
                child:
                FilledButton(
                  onPressed:
                      () {

                    final value =
                    controller
                        .text
                        .trim();


                    if (
                    value.isEmpty
                    ) {

                      return;
                    }


                    Navigator.of(
                      context,
                    ).pop(
                      value,
                    );
                  },

                  child:
                  const Text(
                    'LƯU',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}