import 'package:flutter/material.dart';

import '../../controllers/settings_controller.dart';


class SoundSettingsSheet
    extends StatefulWidget {

  final SettingsController settingsController;


  const SoundSettingsSheet({

    super.key,

    required this.settingsController,

  });


  @override
  State<SoundSettingsSheet>
  createState() =>
      _SoundSettingsSheetState();
}


class _SoundSettingsSheetState
    extends State<SoundSettingsSheet> {


  late double speechRate;


  @override
  void initState() {

    super.initState();


    speechRate =
        widget
            .settingsController
            .settings
            .speechRate;
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    final settings =
        widget
            .settingsController
            .settings;


    final colorScheme =
        Theme.of(context)
            .colorScheme;


    return SafeArea(

      child:
      Padding(

        padding:
        const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          30,
        ),

        child:
        Column(

          mainAxisSize:
          MainAxisSize.min,

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            const Text(

              'Âm thanh và Đọc thông báo',

              style:
              TextStyle(
                fontSize:
                24,

                fontWeight:
                FontWeight.bold,
              ),
            ),


            const SizedBox(
              height:
              20,
            ),


            Card(

              clipBehavior:
              Clip.antiAlias,

              child:
              Column(

                children: [

                  // ========================================
                  // PHAT AM BAO
                  // ========================================

                  SwitchListTile(

                    value:
                    settings
                        .playTripSound,

                    title:
                    const Text(
                      'Phát âm báo cuốc mới',
                    ),

                    subtitle:
                    const Text(
                      'Kêu một tiếng khi có cuốc mới',
                    ),

                    onChanged:
                        (
                        value,
                        ) async {

                      await widget
                          .settingsController
                          .updatePlayTripSound(
                        value,
                      );


                      if (!mounted) {
                        return;
                      }


                      setState(() {});
                    },
                  ),


                  const Divider(
                    height:
                    1,
                  ),


                  // ========================================
                  // DOC THONG BAO
                  // ========================================

                  SwitchListTile(

                    value:
                    settings
                        .readTripNotification,

                    title:
                    const Text(
                      'Đọc thông báo cuốc',
                    ),

                    subtitle:
                    const Text(
                      'Đọc nội dung cuốc vừa nhận được',
                    ),

                    onChanged:
                        (
                        value,
                        ) async {


                      await widget
                          .settingsController
                          .updateReadTripNotification(
                        value,
                      );


                      if (!mounted) {
                        return;
                      }


                      setState(() {});
                    },
                  ),


                  const Divider(
                    height:
                    1,
                  ),


                  // ========================================
                  // TOC DO DOC
                  // ========================================

                  Padding(

                    padding:
                    const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      14,
                    ),

                    child:
                    Column(

                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [

                        Row(

                          children: [

                            const Text(
                              'Tốc độ đọc',
                            ),


                            const Spacer(),


                            Text(

                              speechRate <
                                  0.45

                                  ? 'Chậm'

                                  : speechRate >
                                  0.55

                                  ? 'Nhanh'

                                  : 'Bình thường',

                              style:
                              TextStyle(
                                color:
                                colorScheme
                                    .primary,

                                fontWeight:
                                FontWeight.w500,
                              ),
                            ),
                          ],
                        ),


                        Slider(

                          min:
                          0.35,

                          max:
                          0.65,

                          divisions:
                          15,

                          value:
                          speechRate,

                          label:
                          speechRate
                              .toStringAsFixed(
                            2,
                          ),

                          onChanged:
                              (
                              value,
                              ) {

                            setState(() {

                              speechRate =
                                  value;
                            });
                          },


                          onChangeEnd:
                              (
                              value,
                              ) async {

                            await widget
                                .settingsController
                                .updateSpeechRate(
                              value,
                            );
                          },
                        ),


                        Row(

                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [

                            Text(
                              'Chậm',

                              style:
                              TextStyle(
                                color:
                                colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),


                            Text(
                              'Nhanh',

                              style:
                              TextStyle(
                                color:
                                colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}