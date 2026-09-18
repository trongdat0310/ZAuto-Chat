import 'package:flutter/material.dart';


class TextMessageBubble
    extends StatelessWidget {

  final bool isSelf;

  final bool isRecalled;

  final String senderName;

  final String content;

  final String timeText;


  // ========================================
  // QUOTE
  // ========================================

  final bool hasQuote;

  final String? quoteSender;

  final String? quoteMessage;

  final VoidCallback? onQuoteTap;


  const TextMessageBubble({
    super.key,
    required this.isSelf,
    required this.isRecalled,
    required this.senderName,
    required this.content,
    required this.timeText,
    required this.hasQuote,
    required this.quoteSender,
    required this.quoteMessage,
    required this.onQuoteTap,
  });


  @override
  Widget build(
    BuildContext context,
  ) {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    // ========================================
    // COLORS
    // ========================================

    final incomingBubble =
        colorScheme
            .surfaceContainerHighest;


    final outgoingBubble =
        colorScheme
            .primaryContainer;


    final normalText =
        colorScheme
            .onSurface;


    final secondaryText =
        colorScheme
            .onSurfaceVariant;


    final nameColor =
        colorScheme
            .primary;


    final quoteLineColor =
        colorScheme
            .primary;


    // ========================================
    // QUOTE SAFE TEXT
    // ========================================

    final safeQuoteSender =
        quoteSender != null &&
                quoteSender!
                    .trim()
                    .isNotEmpty

            ? quoteSender!.trim()

            : 'Tin nhắn được trả lời';


    final safeQuoteMessage =
        quoteMessage != null &&
                quoteMessage!
                    .trim()
                    .isNotEmpty

            ? quoteMessage!.trim()

            : '[Tin nhắn]';


    return Container(

      constraints:
          BoxConstraints(

        maxWidth:
            MediaQuery
                    .of(context)
                    .size
                    .width *
                0.76,
      ),


      padding:
          const EdgeInsets
              .fromLTRB(
        12,
        9,
        10,
        7,
      ),


      decoration:
          BoxDecoration(

        color:
            isSelf
                ? outgoingBubble
                : incomingBubble,


        borderRadius:
            BorderRadius.only(

          topLeft:
              Radius.circular(
            isSelf
                ? 14
                : 5,
          ),


          topRight:
              Radius.circular(
            isSelf
                ? 5
                : 14,
          ),


          bottomLeft:
              const Radius.circular(
            14,
          ),


          bottomRight:
              const Radius.circular(
            14,
          ),
        ),


        boxShadow: [

          BoxShadow(

            color:
                colorScheme
                    .shadow
                    .withValues(

              alpha:
                  Theme.of(context)
                              .brightness ==
                          Brightness.dark

                      ? 0.18

                      : 0.10,
            ),


            blurRadius:
                3,


            offset:
                const Offset(
              0,
              1,
            ),
          ),
        ],
      ),


      child:
          Column(

        mainAxisSize:
            MainAxisSize.min,


        crossAxisAlignment:
            CrossAxisAlignment.start,


        children: [

          // ========================================
          // TEN NGUOI GUI
          // ========================================

          if (
              !isSelf &&
              senderName.isNotEmpty
          ) ...[

            Text(

              senderName,


              maxLines:
                  1,


              overflow:
                  TextOverflow
                      .ellipsis,


              style:
                  TextStyle(

                fontSize:
                    13,

                fontWeight:
                    FontWeight.w600,

                color:
                    nameColor,
              ),
            ),


            const SizedBox(
              height:
                  4,
            ),
          ],


          // ========================================
          // QUOTE
          // ========================================

          if (
              hasQuote
          ) ...[

            Material(

              color:
                  Colors.transparent,


              child:
                  InkWell(

                borderRadius:
                    BorderRadius.circular(
                  6,
                ),


                onTap:
                    onQuoteTap,


                child:
                    Container(

                  width:
                      double.infinity,


                  margin:
                      const EdgeInsets.only(
                    bottom:
                        7,
                  ),


                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    9,
                    6,
                    8,
                    6,
                  ),


                  decoration:
                      BoxDecoration(

                    color:
                        isSelf

                            ? colorScheme
                                .surface
                                .withValues(
                              alpha:
                                  0.55,
                            )

                            : colorScheme
                                .surfaceContainerLow,


                    borderRadius:
                        BorderRadius.circular(
                      6,
                    ),


                    border:
                        Border(

                      left:
                          BorderSide(

                        color:
                            quoteLineColor,

                        width:
                            3,
                      ),
                    ),
                  ),


                  child:
                      Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,


                    children: [

                      Text(

                        safeQuoteSender,


                        maxLines:
                            1,


                        overflow:
                            TextOverflow
                                .ellipsis,


                        style:
                            TextStyle(

                          fontSize:
                              12,

                          fontWeight:
                              FontWeight.w700,

                          color:
                              colorScheme
                                  .onSurface,
                        ),
                      ),


                      const SizedBox(
                        height:
                            2,
                      ),


                      Text(

                        safeQuoteMessage,


                        maxLines:
                            2,


                        overflow:
                            TextOverflow
                                .ellipsis,


                        style:
                            TextStyle(

                          fontSize:
                              13,

                          color:
                              colorScheme
                                  .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],


          // ========================================
          // NOI DUNG
          // ========================================

          Text(

            content,


            style:
                TextStyle(

              fontSize:
                  15,

              height:
                  1.25,

              color:
                  normalText,


              fontStyle:
                  isRecalled

                      ? FontStyle.italic

                      : FontStyle.normal,
            ),
          ),


          const SizedBox(
            height:
                4,
          ),


          // ========================================
          // TIME
          // ========================================

          Align(

            alignment:
                Alignment.centerRight,


            child:
                Text(

              timeText,


              style:
                  TextStyle(

                fontSize:
                    10,

                color:
                    secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}