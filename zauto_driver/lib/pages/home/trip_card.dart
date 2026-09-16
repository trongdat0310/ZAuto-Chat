import 'package:flutter/material.dart';

import '../../controllers/settings_controller.dart';


class TripCard extends StatelessWidget {

  final Map<String, dynamic> trip;

  final SettingsController settingsController;

  final VoidCallback onAccept;

  final VoidCallback onIgnore;


  const TripCard({

    super.key,

    required this.trip,

    required this.settingsController,

    required this.onAccept,

    required this.onIgnore,

  });

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

  @override
  Widget build(
      BuildContext context,
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
          ? trip['_remainingSeconds'] as int
          :settingsController
          .settings
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

            onIgnore();
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

            onAccept();
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
                      settingsController
                      .settings
                      .chatFontSize,

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

                    settingsController
                    .settings
                    .acceptButtonPosition ==
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