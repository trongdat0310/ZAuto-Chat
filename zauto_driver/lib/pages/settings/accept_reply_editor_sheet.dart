import 'package:flutter/material.dart';


class AcceptReplyEditorSheet
    extends StatefulWidget {

  final String initialText;


  const AcceptReplyEditorSheet({

    super.key,

    required this.initialText,

  });


  @override
  State<AcceptReplyEditorSheet>
  createState() =>
      _AcceptReplyEditorSheetState();
}


class _AcceptReplyEditorSheetState
    extends State<AcceptReplyEditorSheet> {

  late final TextEditingController
  controller;


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
            height:
            8,
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
            height:
            18,
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
            height:
            8,
          ),


          Row(

            children: [

              Expanded(

                child:
                OutlinedButton(

                  onPressed:
                      () {

                    Navigator
                        .of(context)
                        .pop();
                  },

                  child:
                  const Text(
                    'HỦY',
                  ),
                ),
              ),


              const SizedBox(
                width:
                12,
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


                    Navigator
                        .of(context)
                        .pop(
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