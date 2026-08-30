import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/zalo_link_service.dart';


class ZaloLinkPage
    extends StatefulWidget {

  const ZaloLinkPage({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onLinked,
  });


  final Map<String, dynamic>
  user;

  final Future<void> Function()
  onLogout;

  final Future<void> Function()
  onLinked;


  @override
  State<ZaloLinkPage>
  createState() =>
      _ZaloLinkPageState();
}


class _ZaloLinkPageState
    extends State<ZaloLinkPage> {

  final ZaloLinkService zalo =
  ZaloLinkService();


  Timer? timer;


  bool starting = false;

  String status = 'idle';

  String? qrBase64;

  String? scannedName;

  String? error;


  bool get alreadyLinked =>
      widget.user['zaloLinked'] ==
          true;


  Future<void> startLink() async {
    if (starting) return;


    setState(() {
      starting = true;
      error = null;
    });


    try {
      final result =
      await zalo.start();


      applyStatus(
        result,
      );


      startPolling();

    } catch (e) {

      if (!mounted) return;


      setState(() {
        error =
            e
                .toString()
                .replaceFirst(
              'Exception: ',
              '',
            );
      });

    } finally {

      if (mounted) {
        setState(() {
          starting = false;
        });
      }
    }
  }


  void startPolling() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(
        seconds: 1,
      ),
          (_) async {
        try {
          final result =
          await zalo.status();

          if (!mounted) return;

          applyStatus(
            result,
          );

          if (
          result['status'] ==
              'linked'
          ) {
            timer?.cancel();

            ScaffoldMessenger
                .of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Liên kết Zalo thành công',
                ),
              ),
            );

            await widget.onLinked();
          }
        } catch (e) {
          debugPrint(
            'ZALO LINK POLL ERROR: $e',
          );
        }
      },
    );
  }


  void applyStatus(
      Map<String, dynamic> result,
      ) {
    setState(() {
      status =
          result['status']
              ?.toString() ??
              'idle';

      qrBase64 =
          result['qrBase64']
              ?.toString();

      scannedName =
          result['scannedName']
              ?.toString();

      error =
          result['error']
              ?.toString();
    });
  }


  Future<void> cancelLink() async {
    timer?.cancel();

    await zalo.cancel();


    if (!mounted) return;


    setState(() {
      status = 'idle';
      qrBase64 = null;
      scannedName = null;
    });
  }


  Uint8List? get qrBytes {
    if (
    qrBase64 == null ||
        qrBase64!.isEmpty
    ) {
      return null;
    }

    try {
      return base64Decode(
        qrBase64!,
      );
    } catch (e) {
      debugPrint(
        'QR decode error: $e',
      );

      return null;
    }
  }


  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    final name =
        widget.user['name']
            ?.toString() ??
            'Người dùng';


    if (alreadyLinked) {
      return Scaffold(
        appBar: AppBar(
          title:
          const Text(
            'Tài khoản',
          ),

          actions: [
            IconButton(
              onPressed:
              widget.onLogout,

              icon:
              const Icon(
                Icons.logout,
              ),
            ),
          ],
        ),

        body: Center(
          child: Padding(
            padding:
            const EdgeInsets.all(
              24,
            ),

            child: Column(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                const Icon(
                  Icons
                      .check_circle,
                  size: 80,
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Đã liên kết Zalo',

                  style:
                  TextStyle(
                    fontSize: 26,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'Zalo ID: ${widget.user['zaloUserId'] ?? ''}',
                ),

                const SizedBox(
                  height: 12,
                ),

                const Text(
                  'Bước tiếp theo chúng ta sẽ chuyển Groups, Filters và Messages sang tài khoản này.',
                  textAlign:
                  TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }


    final image =
        qrBytes;


    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Liên kết Zalo',
        ),

        actions: [
          IconButton(
            onPressed:
            widget.onLogout,

            icon:
            const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: ListView(
          padding:
          const EdgeInsets.all(
            24,
          ),

          children: [
            Text(
              'Xin chào $name',

              style:
              const TextStyle(
                fontSize: 26,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Liên kết Zalo để đồng bộ các nhóm của bạn.',
            ),

            const SizedBox(
              height: 32,
            ),


            if (
            status == 'idle'
            )
              SizedBox(
                height: 56,

                child:
                FilledButton.icon(
                  onPressed:
                  starting
                      ? null
                      : startLink,

                  icon:
                  const Icon(
                    Icons.qr_code_2,
                  ),

                  label:
                  const Text(
                    'LIÊN KẾT ZALO',
                  ),
                ),
              ),


            if (
            status ==
                'starting' ||
                status ==
                    'refreshing'
            )
              const Center(
                child: Padding(
                  padding:
                  EdgeInsets.all(
                    40,
                  ),

                  child:
                  CircularProgressIndicator(),
                ),
              ),


            if (
            image != null
            ) ...[
              const Text(
                'Dùng Zalo quét mã QR',

                textAlign:
                TextAlign.center,

                style:
                TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Center(
                child: Container(
                  padding:
                  const EdgeInsets.all(
                    14,
                  ),

                  color:
                  Colors.white,

                  child:
                  Image.memory(
                    image,

                    width:
                    260,

                    height:
                    260,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              if (
              status ==
                  'waiting_scan'
              )
                const Text(
                  'Đang chờ quét mã...',
                  textAlign:
                  TextAlign.center,
                ),

              if (
              status ==
                  'scanned'
              )
                Text(
                  'Đã quét: ${scannedName ?? ''}\nHãy xác nhận đăng nhập trong Zalo.',
                  textAlign:
                  TextAlign.center,
                ),

              const SizedBox(
                height: 20,
              ),

              TextButton(
                onPressed:
                cancelLink,

                child:
                const Text(
                  'Hủy liên kết',
                ),
              ),
            ],


            if (
            error != null &&
                error!.isNotEmpty
            )
              Padding(
                padding:
                const EdgeInsets.only(
                  top: 20,
                ),

                child: Text(
                  error!,

                  textAlign:
                  TextAlign.center,

                  style:
                  TextStyle(
                    color:
                    Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}