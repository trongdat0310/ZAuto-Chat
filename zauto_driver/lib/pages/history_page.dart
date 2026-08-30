import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/backend_service.dart';


class HistoryPage
    extends StatefulWidget {

  const HistoryPage({
    super.key,
  });

  @override
  State<HistoryPage>
  createState() =>
      _HistoryPageState();
}


class _HistoryPageState
    extends State<HistoryPage> {

  final BackendService backend =
  BackendService(
    baseUrl: AppConfig.backendUrl,
  );


  List<Map<String, dynamic>>
  messages = [];


  bool loading = true;


  final Set<String> processing =
  {};


  @override
  void initState() {
    super.initState();

    loadMessages();
  }


  // ========================================
  // LOAD HISTORY
  // ========================================

  Future<void> loadMessages() async {

    if (mounted) {
      setState(() {
        loading = true;
      });
    }


    try {
      final result =
      await backend.getMessages(
        limit: 200,
      );


      if (!mounted) return;


      setState(() {
        messages = result;
      });

    } catch (error) {

      if (!mounted) return;


      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi tải lịch sử: $error',
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
  // ACCEPT
  // ========================================

  Future<void> accept(
      Map<String, dynamic> message,
      ) async {

    final id =
    message['id']?.toString();


    if (id == null ||
        processing.contains(id)) {
      return;
    }


    setState(() {
      processing.add(id);
    });


    try {

      await backend.acceptMessage(id);


      if (!mounted) return;


      await loadMessages();


      if (!mounted) return;


      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Đã nhận cuốc',
          ),
        ),
      );

    } catch (error) {

      if (!mounted) return;


      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi: $error',
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          processing.remove(id);
        });
      }
    }
  }


  // ========================================
  // IGNORE
  // ========================================

  Future<void> ignore(
      Map<String, dynamic> message,
      ) async {

    final id =
    message['id']?.toString();


    if (id == null ||
        processing.contains(id)) {
      return;
    }


    setState(() {
      processing.add(id);
    });


    try {

      await backend.ignoreMessage(id);


      if (!mounted) return;


      await loadMessages();


      if (!mounted) return;


      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Đã bỏ qua cuốc',
          ),
        ),
      );

    } catch (error) {

      if (!mounted) return;


      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi: $error',
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          processing.remove(id);
        });
      }
    }
  }


  // ========================================
  // STATUS
  // ========================================

  String statusText(
      String status,
      ) {

    switch (status) {

      case 'accepted':
        return 'Đã nhận';

      case 'ignored':
        return 'Bỏ qua';

      default:
        return 'Mới';
    }
  }


  IconData statusIcon(
      String status,
      ) {

    switch (status) {

      case 'accepted':
        return Icons.check_circle;

      case 'ignored':
        return Icons.block;

      default:
        return Icons.fiber_new;
    }
  }


  // ========================================
  // TIME
  // ========================================

  String formatTime(
      dynamic rawValue,
      ) {

    if (rawValue == null) {
      return '';
    }


    final date =
    DateTime.tryParse(
      rawValue.toString(),
    );


    if (date == null) {
      return '';
    }


    final local =
    date.toLocal();


    String twoDigits(int value) =>
        value
            .toString()
            .padLeft(2, '0');


    return
      '${twoDigits(local.hour)}:'
          '${twoDigits(local.minute)} '
          '${twoDigits(local.day)}/'
          '${twoDigits(local.month)}/'
          '${local.year}';
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadMessages,

        child: loading

            ? ListView(
          children: const [
            SizedBox(
              height: 300,
            ),

            Center(
              child:
              CircularProgressIndicator(),
            ),
          ],
        )

            : ListView(
          padding:
          const EdgeInsets
              .all(20),

          children: [

            const Text(
              'Lịch sử',
              style: TextStyle(
                fontSize: 30,
                fontWeight:
                FontWeight.bold,
              ),
            ),


            const SizedBox(
              height: 8,
            ),


            Text(
              '${messages.length} cuốc đã lưu',
            ),


            const SizedBox(
              height: 20,
            ),


            if (messages.isEmpty)
              const Padding(
                padding:
                EdgeInsets.only(
                  top: 120,
                ),

                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons
                            .history,
                        size: 70,
                      ),

                      SizedBox(
                        height: 16,
                      ),

                      Text(
                        'Chưa có lịch sử cuốc',
                        style:
                        TextStyle(
                          fontSize:
                          18,
                        ),
                      ),
                    ],
                  ),
                ),
              )


            else
              ...messages.map(
                    (message) {

                  final status =
                      message[
                      'status']
                          ?.toString() ??
                          'new';


                  final id =
                  message['id']
                      ?.toString();


                  final busy =
                      id != null &&
                          processing
                              .contains(
                            id,
                          );


                  return Card(
                    margin:
                    const EdgeInsets
                        .only(
                      bottom: 12,
                    ),

                    child:
                    Padding(
                      padding:
                      const EdgeInsets
                          .all(16),

                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [

                          Row(
                            children: [

                              Icon(
                                statusIcon(
                                  status,
                                ),
                              ),


                              const SizedBox(
                                width: 8,
                              ),


                              Text(
                                statusText(
                                  status,
                                ),
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),


                              const Spacer(),


                              Text(
                                formatTime(
                                  message[
                                  'receivedAt'],
                                ),
                                style:
                                const TextStyle(
                                  fontSize:
                                  12,
                                ),
                              ),
                            ],
                          ),


                          const SizedBox(
                            height: 16,
                          ),


                          Text(
                            message[
                            'content']
                                ?.toString() ??
                                '',
                            style:
                            const TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),


                          const SizedBox(
                            height: 10,
                          ),

                          Row(
                            children: [
                              const Icon(
                                Icons.groups_outlined,
                                size: 18,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child: Text(
                                  message['groupName']
                                      ?.toString() ??
                                      'Nhóm Zalo',
                                ),
                              ),
                            ],
                          ),
                          if (
                          message['senderName'] != null ||
                              message['senderId'] != null
                          ) ...[
                            const SizedBox(
                              height: 8,
                            ),

                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 18,
                                ),

                                const SizedBox(
                                  width: 8,
                                ),

                                Expanded(
                                  child: Text(
                                    message['senderName']
                                        ?.toString() ??
                                        message['senderId']
                                            ?.toString() ??
                                        '',
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (status ==
                              'new') ...[

                            const SizedBox(
                              height: 18,
                            ),


                            Row(
                              children: [

                                Expanded(
                                  child:
                                  OutlinedButton
                                      .icon(
                                    onPressed:
                                    busy
                                        ? null
                                        : () =>
                                        ignore(
                                          message,
                                        ),

                                    icon:
                                    const Icon(
                                      Icons.close,
                                    ),

                                    label:
                                    const Text(
                                      'BỎ QUA',
                                    ),
                                  ),
                                ),


                                const SizedBox(
                                  width: 12,
                                ),


                                Expanded(
                                  child:
                                  FilledButton
                                      .icon(
                                    onPressed:
                                    busy
                                        ? null
                                        : () =>
                                        accept(
                                          message,
                                        ),

                                    icon:
                                    busy
                                        ? const SizedBox(
                                      width:
                                      18,
                                      height:
                                      18,
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth:
                                        2,
                                      ),
                                    )
                                        : const Icon(
                                      Icons
                                          .local_taxi,
                                    ),

                                    label:
                                    const Text(
                                      'NHẬN',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],


                          if (status ==
                              'accepted' &&
                              message[
                              'acceptedAt'] !=
                                  null) ...[

                            const SizedBox(
                              height: 10,
                            ),

                            Text(
                              'Nhận lúc: ${formatTime(message['acceptedAt'])}',
                            ),
                          ],


                          if (status ==
                              'ignored' &&
                              message[
                              'ignoredAt'] !=
                                  null) ...[

                            const SizedBox(
                              height: 10,
                            ),

                            Text(
                              'Bỏ qua lúc: ${formatTime(message['ignoredAt'])}',
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}