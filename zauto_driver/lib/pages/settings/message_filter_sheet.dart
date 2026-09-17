import 'package:flutter/material.dart';

import '../../services/backend_service.dart';


class MessageFilterSheet
    extends StatefulWidget {

  final BackendService backend;

  final bool initialShowImages;

  final bool initialDeduplicateMessages;

  final bool initialShowVoiceMessages;

  final bool initialTranscribeVoiceMessages;


  final ValueChanged<bool>
  onShowImagesChanged;

  final ValueChanged<bool>
  onDeduplicateMessagesChanged;

  final ValueChanged<bool>
  onShowVoiceMessagesChanged;

  final ValueChanged<bool>
  onTranscribeVoiceMessagesChanged;


  const MessageFilterSheet({

    super.key,

    required this.backend,

    required this.initialShowImages,

    required this.initialDeduplicateMessages,

    required this.initialShowVoiceMessages,

    required this.initialTranscribeVoiceMessages,

    required this.onShowImagesChanged,

    required this.onDeduplicateMessagesChanged,

    required this.onShowVoiceMessagesChanged,

    required this.onTranscribeVoiceMessagesChanged,
  });


  @override
  State<MessageFilterSheet> createState() =>
      _MessageFilterSheetState();
}


class _MessageFilterSheetState
    extends State<MessageFilterSheet> {

  late bool showImages;

  late bool deduplicateMessages;

  late bool showVoiceMessages;

  late bool transcribeVoiceMessages;


  @override
  void initState() {

    super.initState();


    showImages =
        widget.initialShowImages;


    deduplicateMessages =
        widget.initialDeduplicateMessages;


    showVoiceMessages =
        widget.initialShowVoiceMessages;


    transcribeVoiceMessages =
        widget.initialTranscribeVoiceMessages;
  }


  @override
  Widget build(
      BuildContext context,
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
              fontSize:
              25,

              fontWeight:
              FontWeight.bold,
            ),
          ),


          const SizedBox(
            height:
            22,
          ),


          Card(

            clipBehavior:
            Clip.antiAlias,

            child:
            Column(

              children: [

                // ========================================
                // HIEN THI ANH
                // ========================================

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

                    setState(() {

                      showImages =
                          value;
                    });


                    widget
                        .onShowImagesChanged(
                      value,
                    );
                  },
                ),


                const Divider(
                  height:
                  1,
                ),


                // ========================================
                // LOC TRUNG
                // ========================================

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
                    // DOI UI NGAY
                    // ========================================

                    setState(() {

                      deduplicateMessages =
                          value;
                    });


                    widget
                        .onDeduplicateMessagesChanged(
                      value,
                    );


                    try {

                      // ========================================
                      // LUU BACKEND
                      // ========================================

                      await widget
                          .backend
                          .updateMessageSettings(

                        deduplicateMessages:
                        value,
                      );

                    } catch (error) {

                      if (!mounted) {
                        return;
                      }


                      if (!context.mounted) {
                        return;
                      }


                      setState(() {

                        deduplicateMessages =
                            oldValue;
                      });


                      widget
                          .onDeduplicateMessagesChanged(
                        oldValue,
                      );


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
                  height:
                  1,
                ),


                // ========================================
                // THONG TIN LOC TRUNG
                // ========================================

                ListTile(

                  leading:
                  Container(

                    width:
                    46,

                    height:
                    46,

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
                  _showDuplicateInfo,
                ),
              ],
            ),
          ),


          const SizedBox(
            height:
            28,
          ),


          Center(

            child:
            Text(

              'TIN NHẮN THOẠI',

              style:
              TextStyle(

                fontSize:
                13,

                color:
                colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),


          const SizedBox(
            height:
            12,
          ),


          Card(

            clipBehavior:
            Clip.antiAlias,

            child:
            Column(

              children: [

                // ========================================
                // HIEN THI TIN THOAI
                // ========================================

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


                    widget
                        .onShowVoiceMessagesChanged(
                      value,
                    );
                  },
                ),


                const Divider(
                  height:
                  1,
                ),


                // ========================================
                // PHIEN AM
                // ========================================

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


                    widget
                        .onTranscribeVoiceMessagesChanged(
                      value,
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
  }


  // ========================================
  // DUPLICATE INFO
  // ========================================

  void _showDuplicateInfo() {

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
}