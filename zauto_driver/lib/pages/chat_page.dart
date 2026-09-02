import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../services/backend_service.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class _SwipeReplyWrapper
    extends StatefulWidget {

  final Widget child;

  final VoidCallback onReply;

  final VoidCallback onLongPress;

  final bool enabled;


  const _SwipeReplyWrapper({
    required this.child,
    required this.onReply,
    required this.onLongPress,
    this.enabled = true,
  });


  @override
  State<_SwipeReplyWrapper>
  createState() =>
      _SwipeReplyWrapperState();
}


class _SwipeReplyWrapperState
    extends State<_SwipeReplyWrapper> {

  double offsetX =
  0;


  bool dragging =
  false;


  static const double maxDrag =
  76;


  static const double triggerDistance =
  46;


  void _reset() {

    if (!mounted) {
      return;
    }


    setState(() {

      dragging =
      false;

      offsetX =
      0;
    });
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    final progress =
    (
        -offsetX /
            triggerDistance
    )
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();


    return GestureDetector(

      behavior:
      HitTestBehavior.translucent,


      // ========================================
      // NHAN GIU:
      // VAN GIU MENU ACTION HIEN TAI
      // ========================================

      onLongPress:
      widget.onLongPress,


      // ========================================
      // VUOT TRAI DE REPLY
      // ========================================

      onHorizontalDragStart:
      widget.enabled
          ? (_) {

        setState(() {

          dragging =
          true;
        });
      }
          : null,


      onHorizontalDragUpdate:
      widget.enabled
          ? (
          details,
          ) {

        // ========================================
        // CHI CHO PHEP DI SANG TRAI.
        //
        // offset:
        // 0 -> -76
        // ========================================

        final next =
        (
            offsetX +
                details.delta.dx
        )
            .clamp(
          -maxDrag,
          0.0,
        )
            .toDouble();


        if (
        next ==
            offsetX
        ) {
          return;
        }


        setState(() {

          offsetX =
              next;
        });
      }
          : null,


      onHorizontalDragEnd:
      widget.enabled
          ? (
          details,
          ) {

        final velocity =
            details
                .primaryVelocity ??
                0;


        final shouldReply =
            offsetX <=
                -triggerDistance ||
                velocity <
                    -650;


        _reset();


        if (
        shouldReply
        ) {

          Future.microtask(
            widget.onReply,
          );
        }
      }
          : null,


      onHorizontalDragCancel:
      widget.enabled
          ? _reset
          : null,


      child:
      Stack(
        alignment:
        Alignment.centerRight,

        children: [

          // ========================================
          // ICON REPLY NAM PHIA SAU BUBBLE
          // ========================================

          Positioned(
            right:
            18,

            child:
            Opacity(
              opacity:
              progress,

              child:
              Transform.scale(
                scale:
                0.75 +
                    (
                        0.25 *
                            progress
                    ),

                child:
                Container(
                  width:
                  36,

                  height:
                  36,

                  decoration:
                  const BoxDecoration(
                    color:
                    Color(
                      0xFFFFFFFF,
                    ),

                    shape:
                    BoxShape.circle,
                  ),

                  child:
                  const Icon(
                    Icons
                        .reply_rounded,

                    size:
                    22,

                    color:
                    Color(
                      0xFF1687C9,
                    ),
                  ),
                ),
              ),
            ),
          ),


          // ========================================
          // BUBBLE DI CHUYEN THEO NGON TAY
          // ========================================

          AnimatedContainer(
            duration:
            dragging
                ? Duration.zero
                : const Duration(
              milliseconds:
              160,
            ),

            curve:
            Curves.easeOutCubic,

            transform:
            Matrix4
                .translationValues(
              offsetX,
              0,
              0,
            ),

            child:
            widget.child,
          ),
        ],
      ),
    );
  }
}

// ========================================
// PHOTO VIEWER ITEM
// ========================================

class _PhotoViewerItem {

  final String url;

  final String heroTag;


  const _PhotoViewerItem({
    required this.url,
    required this.heroTag,
  });
}

// ========================================
// PHOTO VIEWER PAGINATION RESULT
// ========================================

class _PhotoViewerLoadResult {

  final List<_PhotoViewerItem>
  items;


  final bool
  hasMoreOlder;


  const _PhotoViewerLoadResult({
    required this.items,
    required this.hasMoreOlder,
  });
}

// ========================================
// FULL SCREEN PHOTO VIEWER
//
// - 1 anh
// - hoac ca album
// - swipe trai/phai
// - pinch zoom
// - double tap zoom
// ========================================

class _PhotoViewerPage
    extends StatefulWidget {

  final List<_PhotoViewerItem>
  items;


  final int
  initialIndex;


  final bool
  initialHasMoreOlder;


  final Future<_PhotoViewerLoadResult>
  Function()?
  onLoadOlder;


  const _PhotoViewerPage({
    required this.items,
    required this.initialIndex,
    this.initialHasMoreOlder = false,
    this.onLoadOlder,
  });


  @override
  State<_PhotoViewerPage>
  createState() =>
      _PhotoViewerPageState();
}


class _PhotoViewerPageState
    extends State<_PhotoViewerPage> {

  late final PageController
  pageController;


  late List<_PhotoViewerItem>
  viewerItems;


  int currentIndex =
  0;


  bool currentPageZoomed =
  false;

  // ========================================
// VIEWER CONTROLS
// ========================================

  bool controlsVisible =
  true;


// ========================================
// SWIPE DOWN TO DISMISS
// ========================================

  double dismissOffsetY =
  0.0;


  bool draggingToDismiss =
  false;


  bool controlsVisibleBeforeDrag =
  true;


  bool loadingOlderPhotos =
  false;


  late bool
  hasMoreOlder;


  @override
  void initState() {

    super.initState();


    viewerItems =
    List<_PhotoViewerItem>.from(
      widget.items,
    );


    hasMoreOlder =
        widget.initialHasMoreOlder;


    if (
    viewerItems.isEmpty
    ) {

      currentIndex =
      0;

    } else {

      currentIndex =
          widget.initialIndex
              .clamp(
            0,
            viewerItems.length -
                1,
          );
    }


    pageController =
        PageController(
          initialPage:
          currentIndex,
        );


    // ========================================
    // NEU USER MO MOT ANH GAN DAU HISTORY
    // THI PREFETCH LUON ANH CU HON.
    // ========================================

    WidgetsBinding
        .instance
        .addPostFrameCallback(
          (_) {

        if (
        mounted &&
            currentIndex <=
                1
        ) {

          _loadOlderIfNeeded();
        }
      },
    );
  }


  // ========================================
  // LOAD THEM PHOTO CU
  // ========================================

  Future<void>
  _loadOlderIfNeeded() async {

    if (
    loadingOlderPhotos ||
        !hasMoreOlder ||
        widget.onLoadOlder ==
            null ||
        viewerItems.isEmpty
    ) {

      return;
    }


    final currentTag =
        viewerItems[
        currentIndex
        ].heroTag;


    setState(() {

      loadingOlderPhotos =
      true;
    });


    try {

      final result =
      await widget
          .onLoadOlder!();


      if (!mounted) {

        return;
      }


      final newItems =
          result.items;


      // ========================================
      // TIM LAI ANH DANG XEM
      //
      // VI ANH CU VUA DUOC CHEN VAO DAU LIST,
      // INDEX CUA ANH HIEN TAI SE THAY DOI.
      // ========================================

      var newCurrentIndex =
      newItems.indexWhere(
            (
            item,
            ) =>
        item.heroTag ==
            currentTag,
      );


      if (
      newCurrentIndex <
          0
      ) {

        newCurrentIndex =
            currentIndex.clamp(
              0,
              math.max(
                0,
                newItems.length -
                    1,
              ),
            );
      }


      final changed =
          newItems.length !=
              viewerItems.length;


      setState(() {

        viewerItems =
            newItems;

        currentIndex =
            newCurrentIndex;

        hasMoreOlder =
            result
                .hasMoreOlder;

        loadingOlderPhotos =
        false;
      });


      // ========================================
      // GIU NGUYEN DUNG ANH USER DANG XEM
      // SAU KHI PREPEND ANH CU.
      // ========================================

      if (
      changed
      ) {

        WidgetsBinding
            .instance
            .addPostFrameCallback(
              (_) {

            if (
            !mounted ||
                !pageController
                    .hasClients
            ) {

              return;
            }


            pageController
                .jumpToPage(
              newCurrentIndex,
            );
          },
        );
      }

    } catch (error) {

      if (!mounted) {

        return;
      }


      setState(() {

        loadingOlderPhotos =
        false;
      });


      debugPrint(
        'PHOTO VIEWER LOAD OLDER ERROR: '
            '$error',
      );
    }
  }

  void _toggleControls() {

    if (
    draggingToDismiss
    ) {

      return;
    }


    setState(() {

      controlsVisible =
      !controlsVisible;
    });
  }

  void _handleDismissDragStart(
      DragStartDetails details,
      ) {

    if (
    currentPageZoomed
    ) {

      return;
    }


    controlsVisibleBeforeDrag =
        controlsVisible;


    setState(() {

      draggingToDismiss =
      true;


      // Khi bắt đầu kéo ảnh xuống,
      // ẩn controls cho giống photo viewer.
      controlsVisible =
      false;
    });
  }

  void _handleDismissDragUpdate(
      DragUpdateDetails details,
      ) {

    if (
    currentPageZoomed ||
        !draggingToDismiss
    ) {

      return;
    }


    // ========================================
    // CHI CHO PHEP KEO XUONG
    //
    // Neu user keo nguoc len trong luc dang
    // keo xuong thi offset se giam dan ve 0.
    // ========================================

    final next =
    math.max(
      0.0,

      dismissOffsetY +
          details.delta.dy,
    );


    setState(() {

      dismissOffsetY =
          next;
    });
  }

  void _handleDismissDragEnd(
      DragEndDetails details,
      ) {

    if (
    currentPageZoomed ||
        !draggingToDismiss
    ) {

      return;
    }


    final velocity =
        details.primaryVelocity ??
            0.0;


    // ========================================
    // DONG VIEWER NEU:
    //
    // - keo xuong >= 120px
    // HOAC
    // - vuot nhanh xuong
    // ========================================

    final shouldDismiss =
        dismissOffsetY >=
            120 ||
            velocity >
                900;


    if (
    shouldDismiss
    ) {

      Navigator.of(
        context,
      ).pop();


      return;
    }


    // ========================================
    // KHONG DU XA
    // -> TRA ANH VE GIUA
    // ========================================

    setState(() {

      draggingToDismiss =
      false;


      dismissOffsetY =
      0.0;


      controlsVisible =
          controlsVisibleBeforeDrag;
    });
  }

  void _handleDismissDragCancel() {

    if (
    !draggingToDismiss
    ) {

      return;
    }


    setState(() {

      draggingToDismiss =
      false;


      dismissOffsetY =
      0.0;


      controlsVisible =
          controlsVisibleBeforeDrag;
    });
  }


  // ========================================
  // ZOOM STATE
  // ========================================

  void _handleZoomChanged(
      int pageIndex,
      bool zoomed,
      ) {

    if (
    pageIndex !=
        currentIndex
    ) {

      return;
    }


    if (
    currentPageZoomed ==
        zoomed
    ) {

      return;
    }


    setState(() {

      currentPageZoomed =
          zoomed;
    });
  }


  // ========================================
  // PAGE CHANGED
  // ========================================

  void _handlePageChanged(
      int index,
      ) {

    setState(() {

      currentIndex =
          index;

      currentPageZoomed =
      false;
    });


    // ========================================
    // CON 1 ANH NUA LA DEN DAU HISTORY
    // -> PREFETCH THEM.
    // ========================================

    if (
    index <=
        1
    ) {

      _loadOlderIfNeeded();
    }
  }


  @override
  void dispose() {

    pageController
        .dispose();


    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    if (
    viewerItems.isEmpty
    ) {

      return const Scaffold(

        backgroundColor:
        Colors.black,

        body:
        Center(

          child:
          Text(

            'Không có ảnh',

            style:
            TextStyle(
              color:
              Colors.white,
            ),
          ),
        ),
      );
    }

    final dismissProgress =
    (
        dismissOffsetY /
            300
    )
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();


    final backgroundOpacity =
    (
        1.0 -
            dismissProgress *
                0.70
    )
        .clamp(
      0.0,
      1.0,
    )
        .toDouble();


    return Scaffold(

      backgroundColor:
      Color.fromRGBO(
        0,
        0,
        0,
        backgroundOpacity,
      ),


      body:
      SafeArea(

        child:
        Stack(

          children: [

            // ========================================
            // PHOTO PAGES
            // ========================================

            Positioned.fill(

              child:
              GestureDetector(

                behavior:
                HitTestBehavior.translucent,


                // ========================================
                // CHI BAT SWIPE DOWN KHI ANH DANG 1X
                //
                // Neu dang zoom:
                // InteractiveViewer se xu ly pan.
                // ========================================

                onVerticalDragStart:
                currentPageZoomed
                    ? null
                    : _handleDismissDragStart,


                onVerticalDragUpdate:
                currentPageZoomed
                    ? null
                    : _handleDismissDragUpdate,


                onVerticalDragEnd:
                currentPageZoomed
                    ? null
                    : _handleDismissDragEnd,


                onVerticalDragCancel:
                currentPageZoomed
                    ? null
                    : _handleDismissDragCancel,


                child:
                AnimatedContainer(

                  duration:
                  draggingToDismiss

                      ? Duration.zero

                      : const Duration(
                    milliseconds:
                    180,
                  ),


                  curve:
                  Curves.easeOutCubic,


                  // ========================================
                  // ANH DI THEO NGON TAY
                  // ========================================

                  transform:
                  Matrix4.translationValues(
                    0.0,
                    dismissOffsetY,
                    0.0,
                  ),


                  child:
                  NotificationListener<
                      OverscrollNotification>(

                    onNotification:
                        (
                        notification,
                        ) {

                      if (
                      !currentPageZoomed &&
                          currentIndex ==
                              0 &&
                          notification
                              .overscroll <
                              0
                      ) {

                        _loadOlderIfNeeded();
                      }


                      return false;
                    },


                    child:
                    PageView.builder(

                      controller:
                      pageController,


                      physics:
                      currentPageZoomed

                          ? const NeverScrollableScrollPhysics()

                          : const PageScrollPhysics(),


                      itemCount:
                      viewerItems.length,


                      onPageChanged:
                      _handlePageChanged,


                      itemBuilder:
                          (
                          context,
                          index,
                          ) {

                        return _PhotoViewerSlide(

                          item:
                          viewerItems[
                          index
                          ],


                          heroEnabled:
                          index ==
                              currentIndex,


                          onTap:
                          _toggleControls,


                          onZoomChanged:
                              (
                              zoomed,
                              ) {

                            _handleZoomChanged(
                              index,
                              zoomed,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),


            // ========================================
            // BACK
            //
            // KHONG CON x / xx.
            // ========================================

            Positioned(

              top:
              8,

              left:
              8,


              child:
              AnimatedOpacity(

                duration:
                const Duration(
                  milliseconds:
                  160,
                ),


                opacity:
                controlsVisible &&
                    !draggingToDismiss
                    ? 1.0
                    : 0.0,


                child:
                IgnorePointer(

                  ignoring:
                  !controlsVisible ||
                      draggingToDismiss,


                  child:
                  Material(

                    color:
                    const Color(
                      0x66000000,
                    ),


                    shape:
                    const CircleBorder(),


                    child:
                    IconButton(

                      tooltip:
                      'Quay lại',


                      onPressed:
                          () {

                        Navigator.of(
                          context,
                        ).pop();
                      },


                      icon:
                      const Icon(

                        Icons
                            .arrow_back_rounded,

                        color:
                        Colors.white,

                        size:
                        28,
                      ),
                    ),
                  ),
                ),
              ),
            ),


            // ========================================
            // LOADING HISTORY
            // ========================================

            if (
            loadingOlderPhotos &&
                !draggingToDismiss
            )
              const Positioned(

                left:
                18,

                top:
                0,

                bottom:
                0,

                child:
                Center(

                  child:
                  SizedBox(

                    width:
                    22,

                    height:
                    22,

                    child:
                    CircularProgressIndicator(

                      strokeWidth:
                      2,

                      color:
                      Colors.white70,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoViewerPage
    extends StatefulWidget {

  final String videoUrl;


  const _VideoViewerPage({
    required this.videoUrl,
  });


  @override
  State<_VideoViewerPage>
  createState() =>
      _VideoViewerPageState();
}


class _VideoViewerPageState
    extends State<_VideoViewerPage> {

  late final VideoPlayerController
  controller;


  bool initialized =
  false;


  bool failed =
  false;


  bool controlsVisible =
  true;


  Timer?
  hideControlsTimer;


  @override
  void initState() {

    super.initState();


    controller =
        VideoPlayerController
            .networkUrl(
          Uri.parse(
            widget.videoUrl,
          ),
        );


    controller
        .addListener(
      _handleVideoChanged,
    );


    _initialize();
  }


  Future<void>
  _initialize() async {

    try {

      await controller
          .initialize();


      if (!mounted) {
        return;
      }


      await controller
          .setLooping(
        false,
      );


      setState(() {

        initialized =
        true;
      });


      await controller
          .play();


      _scheduleHideControls();

    } catch (error) {

      debugPrint(
        'VIDEO INIT ERROR: $error',
      );


      if (!mounted) {
        return;
      }


      setState(() {

        failed =
        true;
      });
    }
  }


  void _handleVideoChanged() {

    if (!mounted) {
      return;
    }


    if (
    !initialized
    ) {
      return;
    }


    setState(() {
      // Update:
      // - progress
      // - play state
      // - duration
    });
  }


  void _scheduleHideControls() {

    hideControlsTimer
        ?.cancel();


    if (
    !controller
        .value
        .isPlaying
    ) {

      return;
    }


    hideControlsTimer =
        Timer(

          const Duration(
            seconds:
            3,
          ),

              () {

            if (!mounted) {
              return;
            }


            setState(() {

              controlsVisible =
              false;
            });
          },
        );
  }


  void _toggleControls() {

    setState(() {

      controlsVisible =
      !controlsVisible;
    });


    if (
    controlsVisible
    ) {

      _scheduleHideControls();
    }
  }


  Future<void>
  _togglePlay() async {

    if (
    !initialized
    ) {
      return;
    }


    if (
    controller
        .value
        .isPlaying
    ) {

      await controller
          .pause();


      hideControlsTimer
          ?.cancel();


      if (
      mounted
      ) {

        setState(() {

          controlsVisible =
          true;
        });
      }

    } else {

      await controller
          .play();


      if (
      mounted
      ) {

        setState(() {

          controlsVisible =
          true;
        });
      }


      _scheduleHideControls();
    }
  }


  String _formatVideoTime(
      Duration duration,
      ) {

    final totalSeconds =
        duration
            .inSeconds;


    final hours =
        totalSeconds ~/
            3600;


    final minutes =
        (
            totalSeconds %
                3600
        ) ~/
            60;


    final seconds =
        totalSeconds %
            60;


    final minuteText =
    minutes
        .toString()
        .padLeft(
      2,
      '0',
    );


    final secondText =
    seconds
        .toString()
        .padLeft(
      2,
      '0',
    );


    if (
    hours >
        0
    ) {

      return '$hours:$minuteText:$secondText';
    }


    return '$minuteText:$secondText';
  }


  Future<void>
  _seekTo(
      double value,
      ) async {

    if (
    !initialized
    ) {
      return;
    }


    final duration =
        controller
            .value
            .duration;


    if (
    duration
        .inMilliseconds <=
        0
    ) {

      return;
    }


    final targetMs =
    (
        duration
            .inMilliseconds *
            value
    ).round();


    await controller
        .seekTo(
      Duration(
        milliseconds:
        targetMs,
      ),
    );


    _scheduleHideControls();
  }


  @override
  void dispose() {

    hideControlsTimer
        ?.cancel();


    controller
        .removeListener(
      _handleVideoChanged,
    );


    controller
        .dispose();


    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    return Scaffold(

      backgroundColor:
      Colors.black,


      body:
      SafeArea(

        child:
        failed

            ? const Center(

          child:
          Column(

            mainAxisSize:
            MainAxisSize.min,

            children: [

              Icon(
                Icons
                    .error_outline_rounded,

                color:
                Colors.white70,

                size:
                48,
              ),


              SizedBox(
                height:
                12,
              ),


              Text(
                'Không thể phát video',

                style:
                TextStyle(
                  color:
                  Colors.white,
                ),
              ),
            ],
          ),
        )

            : !initialized

            ? const Center(

          child:
          CircularProgressIndicator(

            color:
            Colors.white,
          ),
        )

            : GestureDetector(

          behavior:
          HitTestBehavior.opaque,


          onTap:
          _toggleControls,


          child:
          Stack(

            children: [

              // ========================================
              // VIDEO
              // ========================================

              Positioned.fill(

                child:
                Center(

                  child:
                  AspectRatio(

                    aspectRatio:
                    controller
                        .value
                        .aspectRatio >
                        0
                        ? controller
                        .value
                        .aspectRatio
                        : 16 / 9,

                    child:
                    VideoPlayer(
                      controller,
                    ),
                  ),
                ),
              ),


              // ========================================
              // CONTROLS OVERLAY
              // ========================================

              Positioned.fill(

                child:
                AnimatedOpacity(

                  duration:
                  const Duration(
                    milliseconds:
                    180,
                  ),


                  opacity:
                  controlsVisible
                      ? 1
                      : 0,


                  child:
                  IgnorePointer(

                    ignoring:
                    !controlsVisible,


                    child:
                    Stack(

                      children: [

                        // ========================================
                        // DARK OVERLAY
                        // ========================================

                        const Positioned.fill(

                          child:
                          ColoredBox(

                            color:
                            Color(
                              0x33000000,
                            ),
                          ),
                        ),


                        // ========================================
                        // BACK
                        // ========================================

                        Positioned(

                          top:
                          8,

                          left:
                          8,

                          child:
                          Material(

                            color:
                            const Color(
                              0x66000000,
                            ),

                            shape:
                            const CircleBorder(),

                            child:
                            IconButton(

                              tooltip:
                              'Quay lại',

                              onPressed:
                                  () {

                                Navigator.of(
                                  context,
                                ).pop();
                              },

                              icon:
                              const Icon(

                                Icons
                                    .arrow_back_rounded,

                                color:
                                Colors.white,

                                size:
                                28,
                              ),
                            ),
                          ),
                        ),


                        // ========================================
                        // PLAY / PAUSE
                        // ========================================

                        Center(

                          child:
                          Material(

                            color:
                            const Color(
                              0xAA000000,
                            ),

                            shape:
                            const CircleBorder(),

                            child:
                            InkWell(

                              customBorder:
                              const CircleBorder(),

                              onTap:
                              _togglePlay,

                              child:
                              SizedBox(

                                width:
                                72,

                                height:
                                72,

                                child:
                                Icon(

                                  controller
                                      .value
                                      .isPlaying
                                      ? Icons
                                      .pause_rounded

                                      : Icons
                                      .play_arrow_rounded,

                                  size:
                                  46,

                                  color:
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),


                        // ========================================
                        // BOTTOM CONTROLS
                        // ========================================

                        Positioned(

                          left:
                          14,

                          right:
                          14,

                          bottom:
                          14,

                          child:
                          _buildVideoBottomControls(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildVideoBottomControls() {

    final position =
        controller
            .value
            .position;


    final duration =
        controller
            .value
            .duration;


    final durationMs =
        duration
            .inMilliseconds;


    final positionMs =
        position
            .inMilliseconds;


    final progress =
    durationMs >
        0
        ? (
        positionMs /
            durationMs
    )
        .clamp(
      0.0,
      1.0,
    )
        .toDouble()

        : 0.0;


    return Container(

      padding:
      const EdgeInsets
          .fromLTRB(
        12,
        8,
        12,
        7,
      ),

      decoration:
      BoxDecoration(

        color:
        const Color(
          0x99000000,
        ),

        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),

      child:
      Column(

        mainAxisSize:
        MainAxisSize.min,

        children: [

          // ========================================
          // SEEK BAR
          // ========================================

          SliderTheme(

            data:
            SliderTheme.of(
              context,
            ).copyWith(

              trackHeight:
              3,

              thumbShape:
              const RoundSliderThumbShape(
                enabledThumbRadius:
                6,
              ),

              overlayShape:
              const RoundSliderOverlayShape(
                overlayRadius:
                14,
              ),
            ),


            child:
            Slider(

              value:
              progress,

              min:
              0,

              max:
              1,

              onChanged:
                  (
                  value,
                  ) {

                _seekTo(
                  value,
                );
              },
            ),
          ),


          Row(

            children: [

              IconButton(

                visualDensity:
                VisualDensity.compact,

                padding:
                EdgeInsets.zero,

                constraints:
                const BoxConstraints(

                  minWidth:
                  36,

                  minHeight:
                  36,
                ),

                onPressed:
                _togglePlay,

                icon:
                Icon(

                  controller
                      .value
                      .isPlaying
                      ? Icons
                      .pause_rounded

                      : Icons
                      .play_arrow_rounded,

                  color:
                  Colors.white,

                  size:
                  24,
                ),
              ),


              const SizedBox(
                width:
                6,
              ),


              Text(

                '${_formatVideoTime(position)} / '
                    '${_formatVideoTime(duration)}',

                style:
                const TextStyle(

                  color:
                  Colors.white,

                  fontSize:
                  12,

                  fontWeight:
                  FontWeight.w500,
                ),
              ),


              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================
// MOT ANH TRONG FULL SCREEN VIEWER
//
// MOI PAGE CO:
// - TransformationController RIENG
// - zoom rieng
// - double tap rieng
// ========================================

class _PhotoViewerSlide
    extends StatefulWidget {

  final _PhotoViewerItem item;


  final bool heroEnabled;


  final ValueChanged<bool>
  onZoomChanged;

  final VoidCallback
  onTap;


  const _PhotoViewerSlide({
    required this.item,
    required this.heroEnabled,
    required this.onZoomChanged,
    required this.onTap,
  });

  @override
  State<_PhotoViewerSlide>
  createState() =>
      _PhotoViewerSlideState();
}


class _PhotoViewerSlideState
    extends State<_PhotoViewerSlide>
    with SingleTickerProviderStateMixin {

  final TransformationController
  transformationController =
  TransformationController();


  late final AnimationController
  animationController;


  Animation<Matrix4>?
  zoomAnimation;


  Offset doubleTapPosition =
      Offset.zero;


  bool zoomed =
  false;


  static const double
  doubleTapScale =
  2.5;


  @override
  void initState() {

    super.initState();


    animationController =
        AnimationController(

          vsync:
          this,

          duration:
          const Duration(
            milliseconds:
            220,
          ),
        );


    animationController
        .addListener(
      _handleZoomAnimation,
    );


    transformationController
        .addListener(
      _handleTransformationChanged,
    );
  }


  // ========================================
  // CHECK DANG ZOOM HAY KHONG
  // ========================================

  void _handleTransformationChanged() {

    final scale =
    transformationController
        .value
        .getMaxScaleOnAxis();


    final nextZoomed =
        scale >
            1.01;


    if (
    nextZoomed ==
        zoomed
    ) {

      return;
    }


    zoomed =
        nextZoomed;


    if (mounted) {

      setState(() {
        // Update panEnabled.
      });
    }


    widget.onZoomChanged(
      nextZoomed,
    );
  }


  // ========================================
  // ANIMATION
  // ========================================

  void _handleZoomAnimation() {

    final animation =
        zoomAnimation;


    if (
    animation ==
        null
    ) {

      return;
    }


    transformationController.value =
        animation.value;
  }


  void _animateTransformation(
      Matrix4 target,
      ) {

    animationController
        .stop();


    zoomAnimation =
        Matrix4Tween(

          begin:
          Matrix4.copy(
            transformationController
                .value,
          ),

          end:
          target,
        ).animate(

          CurvedAnimation(

            parent:
            animationController,

            curve:
            Curves.easeOutCubic,
          ),
        );


    animationController
        .forward(
      from:
      0,
    );
  }


  // ========================================
  // DOUBLE TAP POSITION
  // ========================================

  void _handleDoubleTapDown(
      TapDownDetails details,
      ) {

    doubleTapPosition =
        details.localPosition;
  }


  // ========================================
  // DOUBLE TAP
  //
  // 1X -> 2.5X
  // >1X -> 1X
  // ========================================

  void _handleDoubleTap() {

    final currentScale =
    transformationController
        .value
        .getMaxScaleOnAxis();


    if (
    currentScale >
        1.05
    ) {

      _animateTransformation(
        Matrix4.identity(),
      );


      return;
    }


    final x =
        -doubleTapPosition.dx *
            (
                doubleTapScale -
                    1
            );


    final y =
        -doubleTapPosition.dy *
            (
                doubleTapScale -
                    1
            );


    final target =
    Matrix4.identity()

      ..translateByDouble(
        x,
        y,
        0.0,
        1.0,
      )

      ..scaleByDouble(
        doubleTapScale,
        doubleTapScale,
        doubleTapScale,
        1.0,
      );


    _animateTransformation(
      target,
    );
  }


  @override
  void dispose() {

    transformationController
        .removeListener(
      _handleTransformationChanged,
    );


    animationController
        .removeListener(
      _handleZoomAnimation,
    );


    animationController
        .dispose();


    transformationController
        .dispose();


    super.dispose();
  }


  @override
  Widget build(
      BuildContext context,
      ) {

    return GestureDetector(

      behavior:
      HitTestBehavior.opaque,

      // ========================================
      // SINGLE TAP
      // -> an / hien controls
      // ========================================

      onTap:
      widget.onTap,


      onDoubleTapDown:
      _handleDoubleTapDown,


      onDoubleTap:
      _handleDoubleTap,


      child:
      InteractiveViewer(

        transformationController:
        transformationController,


        minScale:
        1.0,


        maxScale:
        5.0,


        // ========================================
        // CHI PAN KHI DANG ZOOM.
        //
        // KHI 1X:
        // VUOT NGANG DUOC NHUONG CHO PAGEVIEW.
        // ========================================

        panEnabled:
        zoomed,


        scaleEnabled:
        true,


        boundaryMargin:
        const EdgeInsets.all(
          100,
        ),


        clipBehavior:
        Clip.none,


        onInteractionStart:
            (
            details,
            ) {

          if (
          animationController
              .isAnimating
          ) {

            animationController
                .stop();
          }
        },


        child:
        Center(

          child:
          HeroMode(

            enabled:
            widget.heroEnabled,


            child:
            Hero(

              tag:
              widget.item
                  .heroTag,


              child:
              Image.network(

                widget.item.url,


                fit:
                BoxFit.contain,


                loadingBuilder:
                    (
                    context,
                    child,
                    progress,
                    ) {

                  if (
                  progress ==
                      null
                  ) {

                    return child;
                  }


                  return const SizedBox(

                    width:
                    42,

                    height:
                    42,

                    child:
                    CircularProgressIndicator(

                      strokeWidth:
                      2.5,

                      color:
                      Colors.white,
                    ),
                  );
                },


                errorBuilder:
                    (
                    context,
                    error,
                    stackTrace,
                    ) {

                  return const Column(

                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      Icon(

                        Icons
                            .broken_image_outlined,

                        size:
                        48,

                        color:
                        Colors.white70,
                      ),


                      SizedBox(
                        height:
                        10,
                      ),


                      Text(

                        'Không thể tải ảnh',

                        style:
                        TextStyle(

                          color:
                          Colors.white70,

                          fontSize:
                          14,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatPage
    extends StatefulWidget {

  final String groupId;

  final String groupName;


  // Dung cho Lich su nhan sau nay.
  final String? targetMsgId;
  final String? targetCliMsgId;


  const ChatPage({
    super.key,

    required this.groupId,
    required this.groupName,

    this.targetMsgId,
    this.targetCliMsgId,
  });


  @override
  State<ChatPage>
  createState() =>
      _ChatPageState();
}


class _ChatPageState
    extends State<ChatPage>
    with WidgetsBindingObserver {

  final ScrollController
  scrollController =
  ScrollController();

  final TextEditingController
  messageController =
  TextEditingController();

  final ImagePicker
  imagePicker =
  ImagePicker();

  bool sendingPhoto =
  false;

  final FocusNode
  messageFocusNode =
  FocusNode();


  bool sendingMessage =
  false;

  String?
  undoingMessageKey;

  String?
  deletingMessageKey;

  bool canSendMessage =
  false;

  // ========================================
  // MESSAGE DANG DUOC REPLY
  // ========================================

  Map<String, dynamic>?
  replyingToMessage;

  StreamSubscription<Map<String, dynamic>>?
  realtimeSubscription;

  // ========================================
  // MARK READ
  // ========================================

  Timer?
  markReadTimer;


  bool markReadInFlight =
  false;


  bool markReadPending =
  false;


  // Chỉ đánh dấu đã đọc khi app
  // thực sự đang foreground.
  bool appIsActive =
  true;

  Timer? realtimeReloadTimer;

  Timer? targetHighlightTimer;

  Timer? topNoticeTimer;

  int? targetIndex;

  String? targetErrorReason;

  bool highlightTarget = false;

  bool targetNoticeShown = false;

  bool isSameMessage(
      Map<String, dynamic> a,
      Map<String, dynamic> b,
      ) {

    const keys = [
      'msgId',
      'cliMsgId',
      'id',
    ];


    for (
    final key
    in keys
    ) {

      final aValue =
      a[key]
          ?.toString();

      final bValue =
      b[key]
          ?.toString();


      if (
      aValue != null &&
          aValue.isNotEmpty &&
          bValue != null &&
          bValue.isNotEmpty &&
          aValue ==
              bValue
      ) {

        return true;
      }
    }
    return false;
  }

  String _messageActionKey(
      Map<String, dynamic> message,
      ) {

    return message['id']
        ?.toString() ??
        message['msgId']
            ?.toString() ??
        message['cliMsgId']
            ?.toString() ??
        '';
  }

  void _removeMessageFromUi(
      Map<String, dynamic> message,
      ) {

    if (!mounted) {
      return;
    }


    final removeIndex =
    messages.indexWhere(
          (
          item,
          ) =>
          isSameMessage(
            item,
            message,
          ),
    );


    if (
    removeIndex < 0
    ) {
      return;
    }


    setState(() {

      // ========================================
      // XOA HAN MESSAGE KHOI DANH SACH
      // ========================================

      messages.removeAt(
        removeIndex,
      );


      // ========================================
      // SUA TARGET INDEX NEU MESSAGE BI XOA
      // NAM TRUOC / DUNG TARGET
      // ========================================

      if (
      targetIndex != null
      ) {

        if (
        targetIndex ==
            removeIndex
        ) {

          targetIndex =
          null;

          highlightTarget =
          false;

        } else if (
        removeIndex <
            targetIndex!
        ) {

          targetIndex =
              targetIndex! - 1;
        }
      }


      // ========================================
      // NEU DANG REPLY MESSAGE VUA XOA
      // THI HUY REPLY
      // ========================================

      if (
      replyingToMessage !=
          null &&
          isSameMessage(
            replyingToMessage!,
            message,
          )
      ) {

        replyingToMessage =
        null;
      }
    });
  }

  int? _messageTimestampMs(
      Map<String, dynamic> message,
      ) {

    final raw =
    int.tryParse(
      message['timestamp']
          ?.toString() ??
          '',
    );


    if (
    raw == null ||
        raw <= 0
    ) {
      return null;
    }


    // ========================================
    // HO TRO UNIX SECOND
    // ========================================

    if (
    raw <
        100000000000
    ) {

      return raw *
          1000;
    }


    return raw;
  }


  bool _isRecallExpired(
      Map<String, dynamic> message,
      ) {

    final timestampMs =
    _messageTimestampMs(
      message,
    );


    // Khong ro timestamp thi
    // de backend quyet dinh.
    if (
    timestampMs == null
    ) {
      return false;
    }


    final now =
        DateTime.now()
            .millisecondsSinceEpoch;


    final ageMs =
        now -
            timestampMs;


    if (
    ageMs < 0
    ) {
      return false;
    }


    return ageMs >=
        const Duration(
          hours:
          1,
        ).inMilliseconds;
  }

  int _findMessageIndexByIds({
    String? msgId,
    String? cliMsgId,
  }) {

    final safeMsgId =
        msgId
            ?.trim() ??
            '';


    final safeCliMsgId =
        cliMsgId
            ?.trim() ??
            '';


    return messages.indexWhere(
          (
          message,
          ) {

        final messageMsgId =
            message['msgId']
                ?.toString()
                .trim() ??
                '';


        final messageCliMsgId =
            message['cliMsgId']
                ?.toString()
                .trim() ??
                '';


        final sameMsgId =
            safeMsgId.isNotEmpty &&
                messageMsgId.isNotEmpty &&
                safeMsgId ==
                    messageMsgId;


        final sameCliMsgId =
            safeCliMsgId.isNotEmpty &&
                messageCliMsgId.isNotEmpty &&
                safeCliMsgId ==
                    messageCliMsgId;


        return sameMsgId ||
            sameCliMsgId;
      },
    );
  }

  final GlobalKey targetMessageKey =
  GlobalKey();

  final BackendService backend =
  BackendService(
    baseUrl:
    AppConfig.backendUrl,
  );


  List<Map<String, dynamic>>
  messages = [];


  bool loading =
  true;

  static const int pageSize =
  50;

  bool loadingOlder =
  false;

  bool hasMoreOlder =
  false;

  bool hasMoreNewer =
  false;


// Khong cho pagination chay
// truoc khi scroll target / scroll bottom
// lan dau hoan tat.
  bool paginationReady =
  false;

  // ========================================
// DANG TU DONG TIM TARGET TU TIN MOI NHAT
// ========================================

  bool seekingTarget =
  false;


// Moi lan tim target load 30 tin cu.
  static const int targetSeekPageSize =
  30;


  @override
  void initState() {
    super.initState();

    WidgetsBinding
        .instance
        .addObserver(
      this,
    );


    final lifecycleState =
        WidgetsBinding
            .instance
            .lifecycleState;


    appIsActive =
        lifecycleState == null ||
            lifecycleState ==
                AppLifecycleState.resumed;

    messageController
        .addListener(
      _handleComposerChanged,
    );

    initializeChat();
  }

  void _handleComposerChanged() {

    final next =
        messageController
            .text
            .trim()
            .isNotEmpty;


    if (
    next ==
        canSendMessage
    ) {
      return;
    }


    if (!mounted) {
      return;
    }


    setState(() {

      canSendMessage =
          next;
    });
  }

  void _startReply(
      Map<String, dynamic> message,
      ) {

    final status =
        message['status']
            ?.toString() ??
            'normal';


    // ========================================
    // KHONG REPLY TIN DA THU HOI / XOA
    // ========================================

    if (
    status !=
        'normal'
    ) {

      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Tin nhắn này không còn có thể trả lời.',
          ),
        ),
      );


      return;
    }


    final msgId =
    message['msgId']
        ?.toString();


    final cliMsgId =
    message['cliMsgId']
        ?.toString();


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

      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text(
            'Tin nhắn này chưa có ID Zalo để trả lời.',
          ),
        ),
      );


      return;
    }


    setState(() {

      replyingToMessage =
      Map<String, dynamic>.from(
        message,
      );
    });


    messageFocusNode
        .requestFocus();
  }


  void _cancelReply() {

    if (
    replyingToMessage ==
        null
    ) {
      return;
    }


    setState(() {

      replyingToMessage =
      null;
    });
  }

  Future<void>
  _confirmUndoMessage(
      Map<String, dynamic> message,
      ) async {

    // ========================================
// TIN QUA 1 GIO
//
// VAN HIEN NUT THU HOI,
// NHUNG BAM VAO THI THONG BAO NGAY.
// ========================================

    if (
    _isRecallExpired(
      message,
    )
    ) {

      _showTopNotice(
        'Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi.',
      );


      return;
    }

    final confirmed =
    await showDialog<bool>(
      context:
      context,

      builder:
          (
          dialogContext,
          ) {

        return AlertDialog(

          title:
          const Text(
            'Thu hồi tin nhắn?',
          ),


          content:
          const Text(
            'Tin nhắn này sẽ được thu hồi với mọi người trong nhóm Zalo.',
          ),


          actions: [

            TextButton(
              onPressed:
                  () {

                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },

              child:
              const Text(
                'Hủy',
              ),
            ),


            FilledButton(
              onPressed:
                  () {

                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },

              child:
              const Text(
                'Thu hồi',
              ),
            ),
          ],
        );
      },
    );


    if (
    confirmed !=
        true
    ) {
      return;
    }


    await _undoMessage(
      message,
    );
  }

  Future<void>
  _confirmDeleteMessage(
      Map<String, dynamic> message,
      ) async {

    final confirmed =
    await showDialog<bool>(
      context:
      context,

      builder:
          (
          dialogContext,
          ) {

        return AlertDialog(

          title:
          const Text(
            'Xóa tin nhắn?',
          ),


          content:
          const Text(
            'Tin nhắn sẽ bị xóa ở phía bạn. Người khác trong nhóm Zalo vẫn có thể thấy tin nhắn.',
          ),


          actions: [

            TextButton(
              onPressed:
                  () {

                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },

              child:
              const Text(
                'Hủy',
              ),
            ),


            FilledButton(
              onPressed:
                  () {

                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },

              child:
              const Text(
                'Xóa',
              ),
            ),
          ],
        );
      },
    );


    if (
    confirmed !=
        true
    ) {
      return;
    }


    await _deleteMessage(
      message,
    );
  }

  Future<void>
  _deleteMessage(
      Map<String, dynamic> message,
      ) async {

    final actionKey =
    _messageActionKey(
      message,
    );


    if (
    actionKey.isEmpty ||
        deletingMessageKey != null
    ) {
      return;
    }


    final msgId =
    message['msgId']
        ?.toString()
        .trim();


    final cliMsgId =
    message['cliMsgId']
        ?.toString()
        .trim();


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

      _showTopNotice(
        'Tin nhắn thiếu ID để xóa',
      );

      return;
    }


    setState(() {

      deletingMessageKey =
          actionKey;
    });


    try {

      await backend
          .deleteConversationMessage(
        groupId:
        widget.groupId,

        msgId:
        msgId,

        cliMsgId:
        cliMsgId,
      );


      if (!mounted) {
        return;
      }


      // ========================================
      // API THANH CONG
      //
      // XOA HAN BUBBLE KHOI CHATPAGE.
      // ========================================

      _removeMessageFromUi(
        message,
      );


      _showTopNotice(
        'Đã xóa tin nhắn',
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      _showTopNotice(
        'Xóa tin nhắn thất bại',
      );


      debugPrint(
        'DELETE MESSAGE ERROR: $error',
      );

    } finally {

      if (mounted) {

        setState(() {

          deletingMessageKey =
          null;
        });
      }
    }
  }

  Future<void>
  _undoMessage(
      Map<String, dynamic> message,
      ) async {

    if (
    _isRecallExpired(
      message,
    )
    ) {

      _showTopNotice(
        'Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi.',
      );


      return;
    }

    final actionKey =
    _messageActionKey(
      message,
    );


    if (
    actionKey.isEmpty ||
        undoingMessageKey !=
            null
    ) {
      return;
    }


    final isSelf =
        message['isSelf'] ==
            true;


    if (!isSelf) {

      _showTopNotice(
        'Chỉ có thể thu hồi tin nhắn của bạn',
      );

      return;
    }


    final msgId =
        message['msgId']
            ?.toString()
            .trim() ??
            '';


    final cliMsgId =
        message['cliMsgId']
            ?.toString()
            .trim() ??
            '';


    if (
    msgId.isEmpty ||
        cliMsgId.isEmpty
    ) {

      _showTopNotice(
        'Tin nhắn thiếu ID để thu hồi',
      );

      return;
    }


    setState(() {

      undoingMessageKey =
          actionKey;
    });


    try {

      await backend
          .undoConversationMessage(
        groupId:
        widget.groupId,

        msgId:
        msgId,

        cliMsgId:
        cliMsgId,
      );


      if (!mounted) {
        return;
      }


      // ========================================
      // KHONG TU SUA MESSAGE THANH recalled.
      //
      // DOI listener Zalo gui
      // conversation_message_updated VE.
      // ========================================

      _showTopNotice(
        'Đã thu hồi tin nhắn',
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      final errorText =
      error
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );


      // ========================================
      // BACKEND XAC DINH DA QUA 1 GIO
      // ========================================

      if (
      errorText.contains(
        '1 giờ',
      )
      ) {

        _showTopNotice(
          'Bạn chỉ có thể thu hồi tin nhắn trong 1 giờ sau khi gửi.',
        );

      } else {

        _showTopNotice(
          'Thu hồi tin nhắn thất bại',
        );
      }


      debugPrint(
        'UNDO MESSAGE ERROR: $error',
      );

    } finally {

      if (mounted) {

        setState(() {

          undoingMessageKey =
          null;
        });
      }
    }
  }

  void _showMessageActions(
      Map<String, dynamic> message,
      ) {

    final status =
        message['status']
            ?.toString() ??
            'normal';


    // ========================================
    // MESSAGE DA XOA LOCAL
    // KHONG CON ACTION NAO NUA
    // ========================================

    if (
    status ==
        'deleted_local'
    ) {
      return;
    }


    final isSelf =
        message['isSelf'] ==
            true;


    final msgId =
        message['msgId']
            ?.toString()
            .trim() ??
            '';


    final cliMsgId =
        message['cliMsgId']
            ?.toString()
            .trim() ??
            '';


    final messageContent =
        message['content']
            ?.toString() ??
            '';


    // ========================================
    // QUYEN CUA TUNG ACTION
    // ========================================

    final canReply =
        status ==
            'normal';


    final canCopy =
        status ==
            'normal' &&
            messageContent
                .trim()
                .isNotEmpty;


    final canUndo =
        isSelf &&
            status ==
                'normal' &&
            msgId.isNotEmpty &&
            cliMsgId.isNotEmpty;


    showModalBottomSheet<void>(
      context:
      context,

      showDragHandle:
      true,

      builder:
          (
          sheetContext,
          ) {

        return SafeArea(
          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [

              // ========================================
              // TRA LOI
              // ========================================

              if (canReply)
                ListTile(
                  leading:
                  const Icon(
                    Icons.reply_rounded,
                  ),

                  title:
                  const Text(
                    'Trả lời',
                  ),

                  onTap:
                      () {

                    Navigator.of(
                      sheetContext,
                    ).pop();


                    _startReply(
                      message,
                    );
                  },
                ),


              // ========================================
              // SAO CHEP
              // ========================================

              if (canCopy)
                ListTile(
                  leading:
                  const Icon(
                    Icons.copy_rounded,
                  ),

                  title:
                  const Text(
                    'Sao chép',
                  ),

                  onTap:
                      () async {

                    Navigator.of(
                      sheetContext,
                    ).pop();


                    await Clipboard
                        .setData(
                      ClipboardData(
                        text:
                        messageContent,
                      ),
                    );


                    if (!mounted) {
                      return;
                    }


                    _showTopNotice(
                      'Đã sao chép tin nhắn',
                    );
                  },
                ),


              // ========================================
              // THU HOI
              //
              // CHI TIN CUA CHINH MINH.
              //
              // KHONG KIEM TRA 1 GIO O DAY
              // VI TA VAN MUON HIEN NUT THU HOI.
              //
              // _confirmUndoMessage SE THONG BAO
              // NEU DA QUA 1 GIO.
              // ========================================

              if (canUndo)
                ListTile(
                  leading:
                  const Icon(
                    Icons.undo_rounded,

                    color:
                    Colors.red,
                  ),

                  title:
                  const Text(
                    'Thu hồi',

                    style:
                    TextStyle(
                      color:
                      Colors.red,
                    ),
                  ),

                  onTap:
                      () {

                    Navigator.of(
                      sheetContext,
                    ).pop();


                    _confirmUndoMessage(
                      message,
                    );
                  },
                ),


              // ========================================
              // XOA LOCAL
              //
              // CO CHO CA TIN CUA MINH
              // VA TIN CUA NGUOI KHAC.
              //
              // TIN RECALLED CUNG CO THE XOA.
              // ========================================

              ListTile(
                leading:
                const Icon(
                  Icons
                      .delete_outline_rounded,

                  color:
                  Colors.red,
                ),

                title:
                const Text(
                  'Xóa',

                  style:
                  TextStyle(
                    color:
                    Colors.red,
                  ),
                ),

                onTap:
                    () {

                  Navigator.of(
                    sheetContext,
                  ).pop();


                  _confirmDeleteMessage(
                    message,
                  );
                },
              ),


              const SizedBox(
                height:
                8,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTopNotice(
      String message,
      ) {

    if (!mounted) {
      return;
    }


    topNoticeTimer
        ?.cancel();


    final messenger =
    ScaffoldMessenger
        .of(context);


    // ========================================
    // XOA BANNER CU NEU DANG HIEN
    // ========================================

    messenger
        .hideCurrentMaterialBanner();


    // ========================================
    // HIEN THONG BAO NGAY DUOI APP BAR
    // ========================================

    messenger
        .showMaterialBanner(
      MaterialBanner(

        backgroundColor:
        Theme.of(context)
            .colorScheme
            .surface,

        elevation:
        2,

        padding:
        const EdgeInsets.symmetric(
          horizontal:
          16,

          vertical:
          8,
        ),

        leading:
        Icon(
          Icons
              .check_circle_outline_rounded,

          size:
          20,

          color:
          Theme.of(context)
              .colorScheme
              .primary,
        ),

        content:
        Text(
          message,

          style:
          const TextStyle(
            fontSize:
            14,

            fontWeight:
            FontWeight.w500,
          ),
        ),


        // ========================================
        // MaterialBanner BAT BUOC actions
        // PHAI CO IT NHAT 1 WIDGET.
        //
        // DUNG SizedBox.shrink()
        // DE KHONG HIEN NUT THUA.
        // ========================================

        actions:
        const [

          SizedBox.shrink(),
        ],
      ),
    );


    // ========================================
    // TU DONG AN SAU 1.2 GIAY
    // ========================================

    topNoticeTimer =
        Timer(
          const Duration(
            milliseconds:
            1200,
          ),

              () {

            if (!mounted) {
              return;
            }


            ScaffoldMessenger
                .of(context)
                .hideCurrentMaterialBanner();
          },
        );
  }

  Future<void>
  _pickAndSendPhoto() async {

    if (
    sendingPhoto ||
        sendingMessage ||
        loading ||
        seekingTarget
    ) {

      return;
    }


    if (
    replyingToMessage !=
        null
    ) {

      _showTopNotice(
        'Trả lời bằng ảnh sẽ được hỗ trợ sau.',
      );


      return;
    }


    List<XFile>
    pickedPhotos;


    try {

      pickedPhotos =
      await imagePicker
          .pickMultiImage(

        maxWidth:
        2048,

        imageQuality:
        90,
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      _showTopNotice(
        'Không thể mở thư viện ảnh',
      );


      debugPrint(
        'MULTI IMAGE PICKER ERROR: $error',
      );


      return;
    }


    if (
    pickedPhotos.isEmpty ||
        !mounted
    ) {

      return;
    }


    if (
    pickedPhotos.length >
        10
    ) {

      _showTopNotice(
        'Mỗi lần chỉ chọn tối đa 10 ảnh',
      );


      return;
    }


    setState(() {

      sendingPhoto =
      true;
    });


    try {

      await backend
          .sendConversationPhotos(

        groupId:
        widget.groupId,

        filePaths:
        pickedPhotos
            .map(
              (
              photo,
              ) =>
          photo.path,
        )
            .toList(),
      );


      if (!mounted) {
        return;
      }


      if (
      pickedPhotos.length ==
          1
      ) {

        _showTopNotice(
          'Đã gửi ảnh',
        );

      } else {

        _showTopNotice(
          'Đã gửi ${pickedPhotos.length} ảnh',
        );
      }


      // Realtime la nguon chinh.
      // REST reload chi la fallback.
      Future.delayed(
        const Duration(
          milliseconds:
          1000,
        ),

            () {

          if (!mounted) {
            return;
          }


          scheduleRealtimeReload(
            force:
            true,
          );
        },
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      final message =
      error
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );


      _showTopNotice(
        message.isEmpty
            ? 'Gửi ảnh thất bại'
            : message,
      );


      debugPrint(
        'SEND PHOTOS ERROR: $error',
      );

    } finally {

      if (mounted) {

        setState(() {

          sendingPhoto =
          false;
        });
      }
    }
  }

  Future<void>
  _sendChatMessage() async {

    if (
    sendingMessage
    ) {
      return;
    }


    final text =
    messageController
        .text
        .trim();


    if (text.isEmpty) {
      return;
    }


    // ========================================
    // REPLY TARGET
    // ========================================

    final replyMessage =
        replyingToMessage;


    final replyMsgId =
    replyMessage?['msgId']
        ?.toString();


    final replyCliMsgId =
    replyMessage?['cliMsgId']
        ?.toString();


    // ========================================
    // KHOA NUT SEND
    // ========================================

    setState(() {

      sendingMessage =
      true;
    });


    try {

      await backend
          .sendConversationMessage(
        groupId:
        widget.groupId,

        text:
        text,

        replyToMsgId:
        replyMsgId,

        replyToCliMsgId:
        replyCliMsgId,
      );


      if (!mounted) {
        return;
      }


      messageController
          .clear();


      setState(() {

        replyingToMessage =
        null;


        targetIndex =
        null;


        highlightTarget =
        false;
      });


      messageFocusNode
          .requestFocus();


      WidgetsBinding
          .instance
          .addPostFrameCallback(
            (_) {

          _scrollToBottom();
        },
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      _showTopNotice(
        'Gửi tin nhắn thất bại',
      );


      debugPrint(
        'SEND MESSAGE ERROR: $error',
      );

    } finally {

      if (mounted) {

        setState(() {

          sendingMessage =
          false;
        });
      }
    }
  }

  // ========================================
// SCHEDULE MARK READ
//
// Debounce de album 4 anh hoac nhieu
// message lien tuc khong tao 4-10 request.
// ========================================

  void _scheduleMarkConversationRead({
    bool immediate = false,
  }) {

    if (
    !mounted ||
        !appIsActive
    ) {

      return;
    }


    markReadTimer
        ?.cancel();


    if (
    immediate
    ) {

      unawaited(
        _markConversationReadNow(),
      );


      return;
    }


    markReadTimer =
        Timer(

          const Duration(
            milliseconds:
            250,
          ),

              () {

            if (
            !mounted ||
                !appIsActive
            ) {

              return;
            }


            unawaited(
              _markConversationReadNow(),
            );
          },
        );
  }

  // ========================================
// MARK READ NOW
// ========================================

  Future<void>
  _markConversationReadNow() async {

    if (
    !mounted ||
        !appIsActive
    ) {

      return;
    }


    // ========================================
    // Neu request truoc van dang chay,
    // ghi nho rang can chay them 1 lan.
    // ========================================

    if (
    markReadInFlight
    ) {

      markReadPending =
      true;


      return;
    }


    markReadInFlight =
    true;


    try {

      await backend
          .markConversationRead(

        groupId:
        widget.groupId,
      );


      debugPrint(
        'CHAT MARK READ: ${widget.groupId}',
      );

    } catch (error) {

      // Mark read loi KHONG DUOC
      // lam hong ChatPage.
      debugPrint(
        'CHAT MARK READ ERROR: $error',
      );

    } finally {

      markReadInFlight =
      false;


      // ========================================
      // Trong luc request dang chay
      // co message moi den.
      //
      // Chay them mot lan nua.
      // ========================================

      if (
      markReadPending
      ) {

        markReadPending =
        false;


        _scheduleMarkConversationRead();
      }
    }
  }

  Future<void> _openVideo(
      Map<String, dynamic> message,
      ) async {

    final url =
    _messageMediaUrl(
      message,
    );


    debugPrint(
      'OPEN VIDEO CALLED: '
          'mediaUrl=$url',
    );


    if (
    url == null ||
        url.isEmpty
    ) {

      _showTopNotice(
        'Video không có đường dẫn',
      );


      debugPrint(
        'OPEN VIDEO ABORT: EMPTY URL',
      );


      return;
    }


    final uri =
    Uri.tryParse(
      url,
    );


    if (
    uri == null ||
        !uri.hasScheme
    ) {

      _showTopNotice(
        'Đường dẫn video không hợp lệ',
      );


      debugPrint(
        'OPEN VIDEO ABORT: INVALID URL',
      );


      return;
    }


    try {

      debugPrint(
        'OPEN VIDEO NAVIGATING...',
      );


      await Navigator.of(
        context,
      ).push(

        MaterialPageRoute<void>(

          builder:
              (
              context,
              ) {

            return _VideoViewerPage(

              videoUrl:
              url,
            );
          },
        ),
      );


      debugPrint(
        'OPEN VIDEO PAGE CLOSED',
      );

    } catch (error) {

      debugPrint(
        'OPEN VIDEO NAVIGATION ERROR: '
            '$error',
      );


      if (!mounted) {
        return;
      }


      _showTopNotice(
        'Không thể mở video',
      );
    }
  }

  Future<void> _openFileMessage(
      Map<String, dynamic> message,
      ) async {

    final rawUrl =
    _messageMediaUrl(
      message,
    );


    if (
    rawUrl == null ||
        rawUrl.isEmpty
    ) {

      _showTopNotice(
        'Tệp không có đường dẫn',
      );


      return;
    }


    final uri =
    Uri.tryParse(
      rawUrl,
    );


    if (
    uri == null
    ) {

      _showTopNotice(
        'Đường dẫn tệp không hợp lệ',
      );


      return;
    }


    try {

      final opened =
      await launchUrl(

        uri,

        mode:
        LaunchMode.externalApplication,
      );


      if (
      !opened &&
          mounted
      ) {

        _showTopNotice(
          'Không thể mở tệp',
        );
      }

    } catch (error) {

      debugPrint(
        'OPEN FILE ERROR: $error',
      );


      if (!mounted) {
        return;
      }


      _showTopNotice(
        'Không thể mở tệp',
      );
    }
  }

  // ========================================
// APP LIFECYCLE
// ========================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {

    final wasActive =
        appIsActive;


    appIsActive =
        state ==
            AppLifecycleState.resumed;


    // ========================================
    // APP RA BACKGROUND
    //
    // Khong duoc tu coi message la da doc.
    // ========================================

    if (
    !appIsActive
    ) {

      markReadTimer
          ?.cancel();


      return;
    }


    // ========================================
    // USER QUAY LAI APP
    //
    // Neu ChatPage nay van dang mo,
    // coi conversation hien tai la da doc.
    // ========================================

    if (
    !wasActive &&
        mounted
    ) {

      _scheduleMarkConversationRead(
        immediate:
        true,
      );
    }
  }

  Future<void> initializeChat() async {

    // ========================================
    // 1. LOAD CHAT
    // ========================================

    await loadMessages();


    if (!mounted) {
      return;
    }


    // ========================================
    // 2. BAT REALTIME
    // ========================================

    startRealtime();


    // ========================================
    // 3. USER DA MO CONVERSATION
    // -> DANH DA DOC.
    // ========================================

    _scheduleMarkConversationRead(
      immediate:
      true,
    );
  }

  bool get hasTarget {

    return
      (
          widget.targetMsgId !=
              null &&
              widget.targetMsgId!
                  .isNotEmpty
      ) ||
          (
              widget.targetCliMsgId !=
                  null &&
                  widget.targetCliMsgId!
                      .isNotEmpty
          );
  }

  int _findTargetIndex() {

    return messages.indexWhere(
          (
          message,
          ) {

        final messageMsgId =
        message['msgId']
            ?.toString();


        final messageCliMsgId =
        message['cliMsgId']
            ?.toString();


        final sameMsgId =
            widget.targetMsgId !=
                null &&
                widget.targetMsgId!
                    .isNotEmpty &&
                messageMsgId !=
                    null &&
                messageMsgId
                    .isNotEmpty &&
                messageMsgId ==
                    widget.targetMsgId;


        final sameCliMsgId =
            widget.targetCliMsgId !=
                null &&
                widget.targetCliMsgId!
                    .isNotEmpty &&
                messageCliMsgId !=
                    null &&
                messageCliMsgId
                    .isNotEmpty &&
                messageCliMsgId ==
                    widget.targetCliMsgId;


        return sameMsgId ||
            sameCliMsgId;
      },
    );
  }

  Future<void> loadMessages() async {

    paginationReady =
    false;

    seekingTarget =
    false;


    if (mounted) {

      setState(() {

        loading =
        true;

        targetIndex =
        null;

        highlightTarget =
        false;
      });
    }


    try {

      // ========================================
      // LUON BAT DAU TU TIN MOI NHAT
      //
      // CA CHAT BINH THUONG
      // VA MO TU LICH SU NHAN
      // DEU GIONG NHAU.
      // ========================================

      final page =
      await backend
          .getConversationMessagesPage(
        groupId:
        widget.groupId,

        limit:
        pageSize,
      );


      if (!mounted) {
        return;
      }


      final loadedMessages =
      _extractMessages(
        page['messages'],
      );


      setState(() {

        messages =
            loadedMessages;


        hasMoreOlder =
            page['hasBefore'] ==
                true;


        // ========================================
        // TA BAT DAU TU LATEST.
        //
        // VI VAY KHONG BAO GIO CAN
        // PAGINATION NEWER.
        // ========================================

        hasMoreNewer =
        false;


        targetErrorReason =
        null;


        loading =
        false;
      });


      // ========================================
      // DOI LISTVIEW BUILD
      // ========================================

      await WidgetsBinding
          .instance
          .endOfFrame;


      if (!mounted) {
        return;
      }


      // ========================================
      // BAT DAU CHINH XAC O TIN MOI NHAT
      // ========================================

            await _jumpToBottomInitial();


            if (!mounted) {
              return;
            }


      // ========================================
      // MO TU LICH SU NHAN
      // ========================================

      if (hasTarget) {

        await _seekTargetFromLatest();

        return;
      }


      // ========================================
      // CHAT BINH THUONG
      // ========================================

      paginationReady =
      true;


      Future.microtask(
            () =>
            _ensureHistoryScrollable(),
      );

    } catch (error) {

      if (!mounted) {
        return;
      }


      setState(() {

        loading =
        false;

        seekingTarget =
        false;
      });


      paginationReady =
      true;


      ScaffoldMessenger
          .of(context)
          .showSnackBar(
        SnackBar(
          content:
          Text(
            'Không thể tải hội thoại: $error',
          ),
        ),
      );
    }
  }

  Future<void>
  _seekTargetFromLatest() async {

    if (
    seekingTarget ||
        !hasTarget
    ) {
      return;
    }


    seekingTarget =
    true;

    paginationReady =
    false;


    try {

      while (
      mounted
      ) {

        // ========================================
        // TARGET DA NAM TRONG SO MESSAGE
        // DA LOAD CHUA?
        // ========================================

        final foundIndex =
        _findTargetIndex();


        if (
        foundIndex >= 0
        ) {

          setState(() {

            targetIndex =
                foundIndex;

            targetErrorReason =
            null;
          });


          final centered =
          await _centerTargetMessage();


          if (!mounted) {
          return;
          }


          if (!centered) {

          debugPrint(
          'TARGET FOUND BUT CENTER FAILED: '
          'index=$foundIndex',
          );

          return;
          }


          setState(() {

          highlightTarget =
          true;
          });


          _removeTargetHighlightLater();


          debugPrint(
            'TARGET SEEK DONE: '
                'index=$foundIndex '
                'messages=${messages.length}',
          );


          return;
        }


        // ========================================
        // KHONG CON TIN CU DE TIM
        // ========================================

        if (
        !hasMoreOlder
        ) {

          targetErrorReason =
          'not_found';


          WidgetsBinding
              .instance
              .addPostFrameCallback(
                (_) {

              _showTargetNotFound();
            },
          );


          return;
        }


        final beforeId =
        messages.first['id']
            ?.toString();


        if (
        beforeId ==
            null ||
            beforeId.isEmpty
        ) {

          targetErrorReason =
          'not_found';


          _showTargetNotFound();

          return;
        }


        // ========================================
        // LOAD THEM MOT PAGE TIN CU
        // ========================================

        final page =
        await backend
            .getConversationMessagesPage(
          groupId:
          widget.groupId,

          limit:
          targetSeekPageSize,

          beforeId:
          beforeId,
        );


        if (!mounted) {
          return;
        }


        final older =
        _extractMessages(
          page['messages'],
        );


        final uniqueOlder =
        older
            .where(
              (
              incoming,
              ) {

            return !messages.any(
                  (
                  existing,
                  ) =>
                  isSameMessage(
                    existing,
                    incoming,
                  ),
            );
          },
        )
            .toList();


        if (
        uniqueOlder.isEmpty
        ) {

          hasMoreOlder =
          false;

          continue;
        }


        setState(() {

          messages = [
            ...uniqueOlder,
            ...messages,
          ];


          hasMoreOlder =
              page['hasBefore'] ==
                  true;
        });


// ========================================
// DOI PAGE MOI DUOC BUILD
// ========================================

        await WidgetsBinding
            .instance
            .endOfFrame;


        if (!mounted) {
          return;
        }


// ========================================
// CUC KY QUAN TRONG:
//
// KIEM TRA TARGET NGAY SAU KHI
// PAGE MOI VUA DUOC THEM.
//
// NEU TARGET NAM TRONG PAGE NAY
// THI DUNG NGAY TAI TARGET.
//
// KHONG CHAY QUA TARGET DEN CUOI PAGE.
// ========================================

        final foundAfterLoad =
        _findTargetIndex();


        if (
        foundAfterLoad >= 0
        ) {

          setState(() {

            targetIndex =
                foundAfterLoad;

            targetErrorReason =
            null;
          });


          final centered =
          await _centerTargetMessage();


          if (!mounted) {
            return;
          }


          if (!centered) {

            debugPrint(
              'TARGET FOUND AFTER LOAD '
                  'BUT CENTER FAILED: '
                  'index=$foundAfterLoad',
            );

            return;
          }


          setState(() {

            highlightTarget =
            true;
          });


          _removeTargetHighlightLater();


          debugPrint(
            'TARGET FOUND AFTER PAGE LOAD: '
                'index=$foundAfterLoad '
                'messages=${messages.length}',
          );


          return;
        }


// ========================================
// TARGET CHUA NAM TRONG PAGE VUA LOAD.
//
// BAY GIO MOI CHAY LEN DAU PAGE
// DE TIEP TUC LOAD PAGE CU HON.
// ========================================

        if (
        !scrollController
            .hasClients
        ) {
          continue;
        }


        await scrollController
            .animateTo(
          scrollController
              .position
              .maxScrollExtent,

          duration:
          const Duration(
            milliseconds:
            180,
          ),

          curve:
          Curves.easeOut,
        );
      }

    } catch (error) {

      debugPrint(
        'TARGET SEEK ERROR: $error',
      );


      if (
      mounted
      ) {

        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          SnackBar(
            content:
            Text(
              'Không thể tìm tin nhắn: $error',
            ),
          ),
        );
      }

    } finally {

      seekingTarget =
      false;


      if (mounted) {

        paginationReady =
        true;
      }
    }
  }

  Future<void>
  _jumpToQuotedMessage(
      Map<String, dynamic> quote,
      ) async {

    if (
    seekingTarget
    ) {
      return;
    }


    final quoteMsgId =
    quote['msgId']
        ?.toString()
        .trim();


    final quoteCliMsgId =
    quote['cliMsgId']
        ?.toString()
        .trim();


    // ========================================
    // QUOTE PHAI CO IT NHAT MOT ID
    // ========================================

    if (
    (
        quoteMsgId ==
            null ||
            quoteMsgId.isEmpty
    ) &&
        (
            quoteCliMsgId ==
                null ||
                quoteCliMsgId.isEmpty
        )
    ) {

      debugPrint(
        'QUOTE WITHOUT MESSAGE ID: '
            '${quote.keys.toList()}',
      );


      if (mounted) {

        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          const SnackBar(
            content:
            Text(
              'Không thể xác định tin nhắn gốc.',
            ),
          ),
        );
      }


      return;
    }


    // ========================================
    // BAT DAU CHE DO TIM TARGET
    // ========================================

    targetHighlightTimer
        ?.cancel();


    setState(() {

      seekingTarget =
      true;

      targetIndex =
      null;

      highlightTarget =
      false;
    });


    paginationReady =
    false;


    try {

      while (
      mounted
      ) {

        // ========================================
        // 1. TARGET DA DUOC LOAD CHUA?
        // ========================================

        final foundIndex =
        _findMessageIndexByIds(
          msgId:
          quoteMsgId,

          cliMsgId:
          quoteCliMsgId,
        );


        if (
        foundIndex >= 0
        ) {

          setState(() {

            targetIndex =
                foundIndex;
          });


          // ========================================
          // DUA TIN GOC VAO GIUA MAN HINH
          // ========================================

          final centered =
          await _centerTargetMessage();


          if (!mounted) {
            return;
          }


          if (
          !centered
          ) {

            ScaffoldMessenger
                .of(context)
                .showSnackBar(
              const SnackBar(
                content:
                Text(
                  'Đã tìm thấy tin nhắn nhưng không thể cuộn tới vị trí đó.',
                ),
              ),
            );


            return;
          }


          // ========================================
          // HIGHLIGHT SAU KHI DA CENTER
          // ========================================

          setState(() {

            highlightTarget =
            true;
          });


          _removeTargetHighlightLater();


          debugPrint(
            'QUOTE TARGET FOUND: '
                'index=$foundIndex '
                'msgId=$quoteMsgId '
                'cliMsgId=$quoteCliMsgId',
          );


          return;
        }


        // ========================================
        // 2. CHUA TIM THAY
        // NHUNG KHONG CON HISTORY CU HON
        // ========================================

        if (
        !hasMoreOlder ||
            messages.isEmpty
        ) {

          if (mounted) {

            ScaffoldMessenger
                .of(context)
                .showSnackBar(
              const SnackBar(
                content:
                Text(
                  'Không tìm thấy tin nhắn gốc trong lịch sử.',
                ),
              ),
            );
          }


          return;
        }


        // ========================================
        // 3. LOAD THEM MESSAGE CU HON
        // ========================================

        final beforeId =
        messages.first['id']
            ?.toString();


        if (
        beforeId ==
            null ||
            beforeId.isEmpty
        ) {

          return;
        }


        final page =
        await backend
            .getConversationMessagesPage(
          groupId:
          widget.groupId,

          limit:
          targetSeekPageSize,

          beforeId:
          beforeId,
        );


        if (!mounted) {
          return;
        }


        final older =
        _extractMessages(
          page['messages'],
        );


        final uniqueOlder =
        older.where(
              (
              incoming,
              ) {

            return !messages.any(
                  (
                  existing,
                  ) =>
                  isSameMessage(
                    existing,
                    incoming,
                  ),
            );
          },
        ).toList();


        // ========================================
        // BACKEND KHONG TRA THEM DU LIEU
        // ========================================

        if (
        uniqueOlder.isEmpty
        ) {

          hasMoreOlder =
          false;


          continue;
        }


        setState(() {

          messages = [
            ...uniqueOlder,
            ...messages,
          ];


          hasMoreOlder =
              page['hasBefore'] ==
                  true;
        });


        // ========================================
        // DOI LIST BUILD XONG ROI TIM LAI
        // ========================================

        await WidgetsBinding
            .instance
            .endOfFrame;
      }

    } catch (error) {

      debugPrint(
        'JUMP TO QUOTED MESSAGE ERROR: '
            '$error',
      );


      if (mounted) {

        ScaffoldMessenger
            .of(context)
            .showSnackBar(
          SnackBar(
            content:
            Text(
              'Không thể mở tin nhắn gốc: $error',
            ),
          ),
        );
      }

    } finally {

      seekingTarget =
      false;


      if (mounted) {

        paginationReady =
        true;
      }
    }
  }

  Future<bool>
  _centerTargetMessage() async {

    if (
    targetIndex ==
        null
    ) {
      return false;
    }


    await WidgetsBinding
        .instance
        .endOfFrame;


    if (
    !mounted ||
        !scrollController
            .hasClients
    ) {
      return false;
    }


    // ========================================
    // KHONG UOC LUONG BANG INDEX NUA.
    //
    // TA DI DAN VE PHIA TIN CU
    // CHO DEN KHI TARGET THUC SU DUOC BUILD.
    //
    // reverse:true
    //
    // min = moi nhat
    // max = cu nhat
    // ========================================

    const scanStep =
    300.0;


    for (
    int attempt = 0;
    attempt < 200;
    attempt++
    ) {

      if (!mounted) {
        return false;
      }


      // ========================================
      // TARGET DA DUOC BUILD
      // ========================================

      final targetContext =
          targetMessageKey
              .currentContext;


      if (
      targetContext != null &&
          targetContext.mounted
      ) {

        await Scrollable
            .ensureVisible(
          targetContext,

          alignment:
          0.5,

          duration:
          const Duration(
            milliseconds:
            220,
          ),

          curve:
          Curves.easeInOut,
        );


        debugPrint(
          'TARGET CENTER SUCCESS: '
              'index=$targetIndex '
              'pixels=${scrollController.position.pixels}',
        );


        return true;
      }


      if (
      !scrollController
          .hasClients
      ) {
        return false;
      }


      final position =
          scrollController.position;


      final currentPixels =
          position.pixels;


      final maxPixels =
          position.maxScrollExtent;


      // ========================================
      // DA DEN TAN CUNG PHIA TIN CU
      // MA TARGET VAN CHUA BUILD
      // ========================================

      if (
      currentPixels >=
          maxPixels - 1
      ) {

        break;
      }


      // ========================================
      // DI THEM MOT DOAN VE PHIA TIN CU
      // ========================================

      final nextPixels =
      (
          currentPixels +
              scanStep
      ).clamp(
        position
            .minScrollExtent,

        maxPixels,
      ).toDouble();


      await scrollController
          .animateTo(
        nextPixels,

        duration:
        const Duration(
          milliseconds:
          70,
        ),

        curve:
        Curves.linear,
      );


      // Cho Flutter build cac bubble
      // vua di vao viewport.
      await WidgetsBinding
          .instance
          .endOfFrame;
    }


    // ========================================
    // KIEM TRA LAN CUOI
    // ========================================

    final finalContext =
        targetMessageKey
            .currentContext;


    if (
    finalContext != null &&
        finalContext.mounted
    ) {

      await Scrollable
          .ensureVisible(
        finalContext,

        alignment:
        0.5,

        duration:
        const Duration(
          milliseconds:
          220,
        ),

        curve:
        Curves.easeInOut,
      );


      return true;
    }


    debugPrint(
      'TARGET CENTER FAILED: '
          'index=$targetIndex '
          'messages=${messages.length} '
          'pixels=${scrollController.position.pixels} '
          'max=${scrollController.position.maxScrollExtent}',
    );


    return false;
  }

  Future<void>
  loadOlderMessages() async {

    if (
    !paginationReady ||
        loadingOlder ||
        !hasMoreOlder ||
        messages.isEmpty
    ) {
      return;
    }


    final beforeId =
    messages.first['id']
        ?.toString();


    if (
    beforeId == null ||
        beforeId.isEmpty
    ) {
      return;
    }


    loadingOlder =
    true;


    // ========================================
    // KHOA PAGINATION TRONG LUC LOAD
    // ========================================

    paginationReady =
    false;


    try {

      final page =
      await backend
          .getConversationMessagesPage(
        groupId:
        widget.groupId,

        limit:
        pageSize,

        beforeId:
        beforeId,
      );


      if (!mounted) {
        return;
      }


      final older =
      _extractMessages(
        page['messages'],
      );

      debugPrint(
        'TARGET SEEK PAGE: '
            'older=${older.length} '
            'hasBefore=${page['hasBefore']} '
            'currentTotal=${messages.length} '
            'targetMsgId=${widget.targetMsgId} '
            'targetCliMsgId=${widget.targetCliMsgId}',
      );


      // ========================================
      // CHONG TRUNG MESSAGE
      // ========================================

      final uniqueOlder =
      older
          .where(
            (
            incoming,
            ) {

          return !messages.any(
                (
                existing,
                ) =>
                isSameMessage(
                  existing,
                  incoming,
                ),
          );
        },
      )
          .toList();


      setState(() {

        if (
        uniqueOlder.isNotEmpty
        ) {

          // ========================================
          // VAN GIU MESSAGES THEO THU TU:
          //
          // CU NHAT
          // ...
          // MOI NHAT
          // ========================================

          messages = [
            ...uniqueOlder,
            ...messages,
          ];


          // ========================================
          // TARGET INDEX TRONG MANG BI DICH
          // ========================================

          if (
          targetIndex != null
          ) {

            targetIndex =
                targetIndex! +
                    uniqueOlder.length;
          }
        }


        hasMoreOlder =
            page['hasBefore'] ==
                true;
      });


      // ========================================
      // QUAN TRONG:
      //
      // KHONG CON:
      // oldOffset
      // oldMaxExtent
      // newMaxExtent
      // addedExtent
      // jumpTo(...)
      //
      // reverse ListView SE TU GIU VI TRI
      // ========================================

    } catch (error) {

      debugPrint(
        'LOAD OLDER MESSAGES ERROR: $error',
      );

    } finally {

      loadingOlder =
      false;


      if (mounted) {

        paginationReady =
        true;
      }
    }
  }

  void _scrollToBottom() {

    if (
    !scrollController
        .hasClients
    ) {
      return;
    }


    scrollController.animateTo(
      scrollController
          .position
          .minScrollExtent,

      duration:
      const Duration(
        milliseconds:
        350,
      ),

      curve:
      Curves.easeOut,
    );
  }

  void _removeTargetHighlightLater() {

    // Neu user bam mot quote khac
    // trong luc target cu dang highlight,
    // huy timer cu.
    targetHighlightTimer
        ?.cancel();


    targetHighlightTimer =
        Timer(
          const Duration(
            seconds:
            2,
          ),

              () {

            if (!mounted) {
              return;
            }


            setState(() {

              highlightTarget =
              false;
            });
          },
        );
  }

  void _showTargetNotFound() {

    if (
    !mounted ||
        targetNoticeShown
    ) {
      return;
    }


    targetNoticeShown =
    true;


    String description;


    switch (
    targetErrorReason
    ) {

      case 'recalled':

        description =
        'Tin nhắn này đã được thu hồi.';

        break;


      case 'deleted_local':

        description =
        'Tin nhắn này đã bị xóa.';

        break;


      case 'not_found':

        description =
        'Tin nhắn không còn tồn tại hoặc chưa được lưu trong lịch sử hội thoại.';

        break;


      default:

        description =
        'Không thể tìm thấy tin nhắn gốc của cuốc này.';
    }


    showDialog<void>(
      context:
      context,

      builder:
          (
          dialogContext,
          ) {

        return AlertDialog(

          title:
          const Row(
            children: [

              Icon(
                Icons.search_off_outlined,
              ),

              SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                Text(
                  'Không tìm thấy tin nhắn',
                ),
              ),
            ],
          ),


          content:
          Text(
            description,
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

  void startRealtime() {

    realtimeSubscription
        ?.cancel();


    realtimeSubscription =
        backend
            .connectRealtime()
            .listen(
              (
              event,
              ) {

            if (!mounted) {
              return;
            }


            final type =
            event['type']
                ?.toString();


// ========================================
// BACKEND VUA YEU CAU AUTH
// ========================================

                if (
                type ==
                    'auth_required'
                ) {

                  return;
                }


// ========================================
// WEBSOCKET VUA KET NOI / KET NOI LAI
//
// CUC KY QUAN TRONG:
//
// Co the backend da sync old_messages
// TRUOC KHI Flutter WebSocket ket noi lai.
//
// Vi vay moi lan authenticated,
// ChatPage phai hoi backend lay latest.
//
// Nhu vay khong phu thuoc vao viec
// co nhan duoc conversation_history_synced
// hay khong.
// ========================================

                if (
                type ==
                    'authenticated'
                ) {

                  debugPrint(
                    'CHAT REALTIME AUTHENTICATED '
                        '-> reload latest messages',
                  );


                  scheduleRealtimeReload(
                    force:
                      true,
                  );

                  _scheduleMarkConversationRead();

                  return;
                }


// ========================================
// BACKEND VUA DONG BO TIN NHAN BI LO
// ========================================

                if (
                type ==
                    'conversation_history_synced'
                ) {

                  final rawSyncData =
                  event['data'];


                  if (
                  rawSyncData is Map
                  ) {

                    final syncData =
                    Map<String, dynamic>.from(
                      rawSyncData,
                    );


                    final syncGroupId =
                    syncData['groupId']
                        ?.toString();


                    // Chi reload neu history vua sync
                    // thuoc group dang mo.
                    if (
                    syncGroupId ==
                        widget.groupId
                    ) {

                      debugPrint(
                        'CHAT HISTORY SYNCED: '
                            'group=$syncGroupId '
                            'count=${syncData['count']}',
                      );


                      scheduleRealtimeReload(
                        force:
                        true,
                      );
                    }
                  }

                  _scheduleMarkConversationRead();

                  return;
                }


// ========================================
// AUTH LOI
// ========================================

                if (
                type ==
                    'auth_error'
                ) {

                  debugPrint(
                    'CHAT REALTIME AUTH ERROR',
                  );


                  return;
                }


// ========================================
// MESSAGE REALTIME BINH THUONG
// ========================================

                if (
                type !=
                    'conversation_message' &&
                    type !=
                        'conversation_message_updated'
                ) {

                  return;
                }


            final rawData =
            event['data'];


            if (
            rawData is! Map
            ) {
              return;
            }


            final data =
            Map<String, dynamic>.from(
              rawData,
            );


            final eventGroupId =
            data['groupId']
                ?.toString();


            // ========================================
            // CHI NHAN MESSAGE CUA GROUP DANG MO
            // ========================================

            if (
            eventGroupId !=
                widget.groupId
            ) {
              return;
            }


            final rawMessage =
            data['message'];


            if (
            rawMessage is! Map
            ) {

              scheduleRealtimeReload();

              return;
            }


            final incoming =
            Map<String, dynamic>.from(
              rawMessage,
            );


            upsertRealtimeMessage(
              incoming,
            );

                // ========================================
// DANG MO DUNG GROUP NAY
// + APP DANG FOREGROUND
// + TIN CUA NGUOI KHAC
//
// -> COI LA DA DOC.
// ========================================

                if (
                type ==
                    'conversation_message' &&
                    incoming['isSelf'] !=
                        true
                ) {

                  _scheduleMarkConversationRead();
                }
          },

          onError:
              (
              error,
              ) {

            debugPrint(
              'CHAT REALTIME ERROR: $error',
            );
          },
        );
  }

  Future<void>
  _ensureHistoryScrollable({
    int attempt = 0,
  }) async {

    if (
    !mounted ||
        !paginationReady ||
        loading ||
        loadingOlder ||
        !hasMoreOlder ||
        messages.isEmpty
    ) {
      return;
    }


    // ========================================
    // DOI LISTVIEW BUILD XONG
    // ========================================

    await WidgetsBinding
        .instance
        .endOfFrame;


    if (!mounted) {
      return;
    }


    // ========================================
    // DOI SCROLL CONTROLLER SAN SANG
    // ========================================

    if (
    !scrollController
        .hasClients
    ) {

      if (
      attempt >= 10
      ) {
        return;
      }


      await Future.delayed(
        const Duration(
          milliseconds:
          60,
        ),
      );


      return _ensureHistoryScrollable(
        attempt:
        attempt + 1,
      );
    }


    final position =
        scrollController
            .position;


    // ========================================
    // DA DU TIN DE CUON
    // ========================================

    if (
    position
        .maxScrollExtent >
        800
    ) {

      return;
    }


    // ========================================
    // MAN HINH CHUA DU TIN
    //
    // TU DONG LOAD THEM TIN CU
    // KHONG CAN USER PHAI KEO
    // ========================================

    debugPrint(
      'CHAT AUTO FILL OLDER: '
          'messages=${messages.length} '
          'hasMoreOlder=$hasMoreOlder',
    );


    await loadOlderMessages();


    if (
    !mounted ||
        !hasMoreOlder ||
        attempt >= 10
    ) {

      return;
    }


    // ========================================
    // NEU VAN CHUA DAY MAN HINH
    // LOAD THEM 1 PAGE NUA
    // ========================================

    await _ensureHistoryScrollable(
      attempt:
      attempt + 1,
    );
  }

  void scheduleRealtimeReload({
    bool force = false,
  }) {

    realtimeReloadTimer
        ?.cancel();


    realtimeReloadTimer =
        Timer(
          const Duration(
            milliseconds:
            250,
          ),

              () async {

            if (!mounted) {
              return;
            }


            // ========================================
            // DANG XEM HISTORY CU
            //
            // REALTIME BINH THUONG:
            // KHONG DUOC NHAY VE HIEN TAI.
            //
            // NHUNG NEU:
            // - websocket vua reconnect
            // - backend vua sync message bi lo
            //
            // force = true
            // THI PHAI LAY LATEST.
            // ========================================

            if (
            hasMoreNewer &&
                !force
            ) {

              return;
            }


            try {

              final page =
              await backend
                  .getConversationMessagesPage(
                groupId:
                widget.groupId,

                limit:
                pageSize,
              );


              if (!mounted) {
                return;
              }


              final latest =
              _extractMessages(
                page['messages'],
              );


              // ========================================
              // USER CO DANG O GAN CUOI CHAT KHONG?
              //
              // reverse:true
              // minScrollExtent = tin moi nhat.
              // ========================================

              final wasNearBottom =
                  !scrollController
                      .hasClients ||
                      (
                          scrollController
                              .position
                              .pixels -
                              scrollController
                                  .position
                                  .minScrollExtent
                      ) <
                          140;


              setState(() {

                for (
                final incoming
                in latest
                ) {

                  final existingIndex =
                  messages.indexWhere(
                        (
                        existing,
                        ) =>
                        isSameMessage(
                          existing,
                          incoming,
                        ),
                  );


                  if (
                  existingIndex >= 0
                  ) {

                    // ========================================
                    // MESSAGE DA CO
                    //
                    // UPDATE:
                    // - recall
                    // - thay doi server
                    // ========================================

                    messages[
                    existingIndex] =
                        incoming;

                  } else {

                    // ========================================
                    // MESSAGE MOI / MESSAGE VUA CATCH UP
                    // ========================================

                    messages.add(
                      incoming,
                    );
                  }
                }


                // ========================================
                // SAP XEP:
                // CU NHAT -> MOI NHAT
                // ========================================

                messages.sort(
                      (
                      a,
                      b,
                      ) {

                    final aTime =
                        int.tryParse(
                          a['timestamp']
                              ?.toString() ??
                              '',
                        ) ??
                            0;


                    final bTime =
                        int.tryParse(
                          b['timestamp']
                              ?.toString() ??
                              '',
                        ) ??
                            0;


                    return aTime.compareTo(
                      bTime,
                    );
                  },
                );


                // Sau khi force lay latest,
                // ta dang co dau moi nhat.
                if (force) {

                  hasMoreNewer =
                  false;
                }
              });


              // ========================================
              // NEU USER DANG O CUOI CHAT
              // THI GIU MAN HINH O CUOI.
              //
              // NEU USER DANG DOC TIN CU
              // THI KHONG KEo MAN HINH.
              // ========================================

              if (
              wasNearBottom
              ) {

                WidgetsBinding
                    .instance
                    .addPostFrameCallback(
                      (_) {

                    if (!mounted) {
                      return;
                    }


                    _scrollToBottom();
                  },
                );
              }


              debugPrint(
                'CHAT REALTIME RELOAD DONE: '
                    'latest=${latest.length} '
                    'total=${messages.length} '
                    'force=$force',
              );

            } catch (error) {

              debugPrint(
                'CHAT REALTIME RELOAD ERROR: '
                    '$error',
              );
            }
          },
        );
  }


  void upsertRealtimeMessage(
      Map<String, dynamic> incoming,
      ) {

    if (!mounted) {
      return;
    }


    final incomingStatus =
        incoming['status']
            ?.toString() ??
            'normal';


    // ========================================
    // MESSAGE DA XOA
    //
    // BIEN MAT HOAN TOAN KHOI UI.
    // ========================================

    if (
    incomingStatus ==
        'deleted_local'
    ) {

      _removeMessageFromUi(
        incoming,
      );

      return;
    }


    // ========================================
    // KHONG CHO EVENT RONG TRO THANH
    // BUBBLE [Tin nhắn]
    // ========================================

    if (
    !_shouldDisplayMessage(
      incoming,
    )
    ) {

      debugPrint(
        'CHAT SKIP NON-DISPLAY MESSAGE: '
            'msgId=${incoming['msgId']} '
            'cliMsgId=${incoming['cliMsgId']} '
            'msgType=${incoming['msgType']}',
      );


      return;
    }


    // ========================================
    // USER DANG O GAN CUOI CHAT?
    // ========================================

    final wasNearBottom =
        !scrollController
            .hasClients ||
            (
                scrollController
                    .position
                    .pixels -
                    scrollController
                        .position
                        .minScrollExtent
            ) <
                140;


    final index =
    messages.indexWhere(
          (
          item,
          ) =>
          isSameMessage(
            item,
            incoming,
          ),
    );


    // ========================================
    // DANG XEM MOT DOAN HISTORY CU
    //
    // NEU PHIA SAU VAN CON MESSAGE CHUA LOAD,
    // KHONG APPEND MOT MESSAGE REALTIME MOI VAO
    // GIUA HISTORY.
    // ========================================

    if (
    index < 0 &&
        hasMoreNewer
    ) {

      return;
    }


    setState(() {

      if (
      index >= 0
      ) {

        // ========================================
        // UPDATE MESSAGE DA CO
        // ========================================

        messages[index] =
            incoming;

      } else {

        // ========================================
        // MESSAGE MOI
        // ========================================

        messages.add(
          incoming,
        );
      }
    });


    // ========================================
    // MESSAGE MOI + USER DANG O CUOI CHAT
    // -> TU DONG CUON THEO
    // ========================================

    if (
    index < 0 &&
        wasNearBottom &&
        targetIndex == null
    ) {

      WidgetsBinding
          .instance
          .addPostFrameCallback(
            (_) {

          if (!mounted) {
            return;
          }


          _scrollToBottom();
        },
      );
    }
  }

  bool _handleScrollNotification(
      ScrollNotification notification,
      ) {

    if (
    !mounted ||
        !paginationReady ||
        seekingTarget ||
        loading ||
        loadingOlder ||
        messages.isEmpty ||
        !hasMoreOlder
    ) {
      return false;
    }


    // ========================================
    // USER DANG KEO TRONG LIST
    // ========================================

    if (
    notification
    is ScrollUpdateNotification
    ) {

      if (
      notification.dragDetails ==
          null
      ) {
        return false;
      }


      final delta =
          notification.scrollDelta ??
              0.0;


      final metrics =
          notification.metrics;


      final distanceToOlderEdge =
          metrics.maxScrollExtent -
              metrics.pixels;


      // reverse:true
      //
      // delta > 0 = di ve tin cu.
      if (
      delta > 0 &&
          distanceToOlderEdge <=
              500
      ) {

        loadOlderMessages();
      }


      return false;
    }


    // ========================================
    // USER DA O SAT MEP TIN CU
    // VAN CO KEo THEM
    // ========================================

    if (
    notification
    is OverscrollNotification
    ) {

      if (
      notification.dragDetails ==
          null
      ) {
        return false;
      }


      final metrics =
          notification.metrics;


      if (
      metrics.pixels >=
          metrics.maxScrollExtent -
              5
      ) {

        loadOlderMessages();
      }
    }


    return false;
  }

  bool _shouldDisplayMessage(
      Map<String, dynamic> message,
      ) {

    final status =
        message['status']
            ?.toString() ??
            'normal';


    if (
    status ==
        'deleted_local'
    ) {

      return false;
    }


    if (
    status ==
        'recalled'
    ) {

      return true;
    }


    final content =
        message['content']
            ?.toString()
            .trim() ??
            '';


    if (
    content.isNotEmpty
    ) {

      return true;
    }


    final msgType =
        message['msgType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    const stringAttachmentTypes =
    <String>{

      'chat.photo',

      'chat.sticker',

      'chat.video',
      'chat.video.msg',

      'share.file',
      'chat.file',
      'chat.file.msg',

      'chat.gif',

      'chat.voice',
      'chat.voice.msg',
      'chat.audio',
    };


    if (
    stringAttachmentTypes
        .contains(
      msgType,
    )
    ) {

      return true;
    }


    final numericType =
    int.tryParse(
      msgType,
    );


    const numericAttachmentTypes =
    <int>{
      31,
      32,
      44,
      46,
      49,
    };


    return numericType != null &&
        numericAttachmentTypes
            .contains(
          numericType,
        );
  }

  List<Map<String, dynamic>>
  _extractMessages(
      dynamic raw,
      ) {

    if (
    raw is! List
    ) {
      return [];
    }


    return raw
        .whereType<Map>()
        .map(
          (
          item,
          ) =>
      Map<String, dynamic>.from(
        item,
      ),
    )
        .where(
      _shouldDisplayMessage,
    )
        .toList();
  }

  Future<void>
  _jumpToBottomInitial({
    int attempt = 0,
  }) async {

    if (!mounted) {
      return;
    }


    if (
    !scrollController
        .hasClients
    ) {

      if (
      attempt >= 10
      ) {

        debugPrint(
          'JUMP TO LATEST FAILED',
        );

        return;
      }


      await Future.delayed(
        const Duration(
          milliseconds:
          80,
        ),
      );


      if (!mounted) {
        return;
      }


      return _jumpToBottomInitial(
        attempt:
        attempt + 1,
      );
    }


    scrollController.jumpTo(
      scrollController
          .position
          .minScrollExtent,
    );


    // Cho viewport on dinh
    // truoc khi bat dau seek.
    await WidgetsBinding
        .instance
        .endOfFrame;
  }

  // ========================================
  // TIME
  // ========================================

  String formatTime(
      dynamic timestamp,
      ) {

    final value =
    int.tryParse(
      timestamp
          ?.toString() ??
          '',
    );


    if (value == null) {
      return '';
    }


    final time =
    DateTime
        .fromMillisecondsSinceEpoch(
      value,
    )
        .toLocal();


    final hour =
    time.hour
        .toString()
        .padLeft(
      2,
      '0',
    );


    final minute =
    time.minute
        .toString()
        .padLeft(
      2,
      '0',
    );


    return '$hour:$minute';
  }

  Map<String, dynamic>?
  _extractQuote(
      Map<String, dynamic> message,
      ) {

    // ========================================
    // 1. rawData LA message.data TU zca-js
    // ========================================

    final raw =
    message['rawData'];


    if (
    raw is Map
    ) {

      final rawMap =
      Map<String, dynamic>.from(
        raw,
      );


      final quote =
      rawMap['quote'];


      if (
      quote is Map
      ) {

        return Map<String, dynamic>.from(
          quote,
        );
      }
    }


    // ========================================
    // 2. FALLBACK NEU SAU NAY BACKEND
    // DUA quote LEN CAP MESSAGE
    // ========================================

    final directQuote =
    message['quote'];


    if (
    directQuote is Map
    ) {

      return Map<String, dynamic>.from(
        directQuote,
      );
    }


    return null;
  }

  String _messageInitials(
      String? name,
      ) {

    final safeName =
    name
        ?.trim();


    if (
    safeName == null ||
        safeName.isEmpty
    ) {

      return '?';
    }


    final parts =
    safeName
        .split(
      RegExp(
        r'\s+',
      ),
    )
        .where(
          (
          part,
          ) =>
      part.isNotEmpty,
    )
        .toList();


    if (
    parts.isEmpty
    ) {

      return '?';
    }


    if (
    parts.length ==
        1
    ) {

      return parts.first
          .substring(
        0,
        1,
      )
          .toUpperCase();
    }


    return (
        parts.first.substring(
          0,
          1,
        ) +
            parts.last.substring(
              0,
              1,
            )
    ).toUpperCase();
  }

  Map<String, dynamic>?
  _extractPhotoContent(
      Map<String, dynamic> message,
      ) {

    final raw =
    message['rawData'];


    if (
    raw is! Map
    ) {

      return null;
    }


    final rawMap =
    Map<String, dynamic>.from(
      raw,
    );


    final content =
    rawMap['content'];


    if (
    content is! Map
    ) {

      return null;
    }


    return Map<String, dynamic>.from(
      content,
    );
  }

  String?
  _extractPhotoUrl(
      Map<String, dynamic> message,
      ) {

    final content =
    _extractPhotoContent(
      message,
    );


    if (
    content == null
    ) {

      return null;
    }


    // ========================================
    // 1. HREF
    //
    // Payload that cua Zalo:
    // content.href = URL anh.
    // ========================================

    final href =
    content['href']
        ?.toString()
        .trim();


    if (
    href != null &&
        href.isNotEmpty
    ) {

      return href;
    }


    // ========================================
    // 2. FALLBACK THUMB
    // ========================================

    final thumb =
    content['thumb']
        ?.toString()
        .trim();


    if (
    thumb != null &&
        thumb.isNotEmpty
    ) {

      return thumb;
    }


    return null;
  }

  String _photoHeroTag(
      Map<String, dynamic> message,
      ) {

    final id =
    message['id']
        ?.toString()
        .trim();


    if (
    id != null &&
        id.isNotEmpty
    ) {

      return 'chat-photo-$id';
    }


    final msgId =
    message['msgId']
        ?.toString()
        .trim();


    if (
    msgId != null &&
        msgId.isNotEmpty
    ) {

      return 'chat-photo-$msgId';
    }


    final cliMsgId =
    message['cliMsgId']
        ?.toString()
        .trim();


    if (
    cliMsgId != null &&
        cliMsgId.isNotEmpty
    ) {

      return 'chat-photo-$cliMsgId';
    }


    // ========================================
    // FALLBACK ON DINH TRONG PHIEN APP
    // ========================================

    return 'chat-photo-${identityHashCode(message)}';
  }

  List<Map<String, dynamic>>
  _allLoadedPhotoMessages() {

    final photos =
    messages
        .where(
          (
          item,
          ) {

        // ========================================
        // CHI LAY PHOTO DANG TON TAI
        // ========================================

        final status =
            item['status']
                ?.toString() ??
                'normal';


        if (
        status !=
            'normal'
        ) {

          return false;
        }


        if (
        !_isPhotoMessage(
          item,
        )
        ) {

          return false;
        }


        final url =
        _extractPhotoUrl(
          item,
        );


        return url !=
            null &&
            url.isNotEmpty;
      },
    )
        .toList();


    // ========================================
    // SAP XEP THEO THOI GIAN CHAT
    //
    // CU -> MOI
    //
    // KHONG QUAN TAM:
    // - album nao
    // - mediaGroupId nao
    // ========================================

    photos.sort(
          (
          a,
          b,
          ) {

        final aTime =
            int.tryParse(
              a['timestamp']
                  ?.toString() ??
                  '',
            ) ??
                0;


        final bTime =
            int.tryParse(
              b['timestamp']
                  ?.toString() ??
                  '',
            ) ??
                0;


        // ========================================
        // NEU CUNG TIMESTAMP
        // THI DUNG THU TU TRONG ALBUM
        // DE ANH KHONG BI DAO LON.
        // ========================================

        if (
        aTime ==
            bTime
        ) {

          final aGroupIndex =
              _mediaGroupIndex(
                a,
              ) ??
                  0;


          final bGroupIndex =
              _mediaGroupIndex(
                b,
              ) ??
                  0;


          return aGroupIndex
              .compareTo(
            bGroupIndex,
          );
        }


        return aTime
            .compareTo(
          bTime,
        );
      },
    );


    return photos;
  }

  List<_PhotoViewerItem>
  _buildPhotoViewerItems(
      List<Map<String, dynamic>>
      sourceMessages,
      ) {

    final result =
    <_PhotoViewerItem>[];


    for (
    final message
    in sourceMessages
    ) {

      final photoUrl =
      _extractPhotoUrl(
        message,
      );


      if (
      photoUrl == null ||
          photoUrl.isEmpty
      ) {

        continue;
      }


      result.add(

        _PhotoViewerItem(

          url:
          photoUrl,

          heroTag:
          _photoHeroTag(
            message,
          ),
        ),
      );
    }


    return result;
  }

  Future<_PhotoViewerLoadResult>
  _loadOlderPhotoViewerItems() async {

    // ========================================
    // SO ANH TRUOC KHI LOAD THEM HISTORY
    // ========================================

    final beforePhotos =
    _allLoadedPhotoMessages();


    final beforeCount =
        beforePhotos.length;


    var attempts =
    0;


    // ========================================
    // MOT PAGE HISTORY CO THE KHONG CO ANH.
    //
    // VI VAY CO THE LOAD LIEN TIEP TOI DA
    // 6 PAGE DE TIM ANH CU HON.
    //
    // KHONG LOAD TOAN BO HISTORY MOT LUC.
    // ========================================

    while (
    mounted &&
        hasMoreOlder &&
        attempts <
            6
    ) {

      attempts +=
      1;


      await loadOlderMessages();


      if (!mounted) {

        break;
      }


      final currentPhotos =
      _allLoadedPhotoMessages();


      // ========================================
      // DA TIM THAY IT NHAT MOT ANH CU HON
      // ========================================

      if (
      currentPhotos.length >
          beforeCount
      ) {

        return _PhotoViewerLoadResult(

          items:
          _buildPhotoViewerItems(
            currentPhotos,
          ),

          hasMoreOlder:
          hasMoreOlder,
        );
      }


      // ========================================
      // HET HISTORY
      // ========================================

      if (
      !hasMoreOlder
      ) {

        break;
      }
    }


    final photos =
    _allLoadedPhotoMessages();


    return _PhotoViewerLoadResult(

      items:
      _buildPhotoViewerItems(
        photos,
      ),

      hasMoreOlder:
      hasMoreOlder,
    );
  }

  Future<void> _openPhotoViewer(
      Map<String, dynamic> message,
      ) async {

    // ========================================
    // TAT CA PHOTO HIEN DA LOAD
    //
    // KHONG PHAN BIET ALBUM.
    // ========================================

    final sourceMessages =
    _allLoadedPhotoMessages();


    final viewerItems =
    _buildPhotoViewerItems(
      sourceMessages,
    );


    if (
    viewerItems.isEmpty
    ) {

      _showTopNotice(
        'Không có ảnh để xem',
      );


      return;
    }


    // ========================================
    // TIM DUNG ANH USER VUA BAM
    // ========================================

    final clickedHeroTag =
    _photoHeroTag(
      message,
    );


    var initialIndex =
    viewerItems.indexWhere(
          (
          item,
          ) =>
      item.heroTag ==
          clickedHeroTag,
    );


    if (
    initialIndex <
        0
    ) {

      initialIndex =
      0;
    }


    await Navigator.of(
      context,
    ).push(

      PageRouteBuilder<void>(

        opaque:
        true,


        transitionDuration:
        const Duration(
          milliseconds:
          250,
        ),


        reverseTransitionDuration:
        const Duration(
          milliseconds:
          220,
        ),


        pageBuilder:
            (
            context,
            animation,
            secondaryAnimation,
            ) {

          return _PhotoViewerPage(

            items:
            viewerItems,

            initialIndex:
            initialIndex,


            // ========================================
            // PAGINATION
            // ========================================

            initialHasMoreOlder:
            hasMoreOlder,

            onLoadOlder:
            _loadOlderPhotoViewerItems,
          );
        },


        transitionsBuilder:
            (
            context,
            animation,
            secondaryAnimation,
            child,
            ) {

          return FadeTransition(

            opacity:
            animation,

            child:
            child,
          );
        },
      ),
    );
  }

  bool _isPhotoMessage(
      Map<String, dynamic> message,
      ) {

    final msgType =
        message['msgType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    return msgType ==
        'chat.photo' ||
        msgType ==
            '32';
  }

  bool _isStickerMessage(
      Map<String, dynamic> message,
      ) {

    final mediaType =
        message['mediaType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    final msgType =
        message['msgType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    return mediaType ==
        'sticker' ||
        msgType ==
            'chat.sticker';
  }


  bool _isVideoMessage(
      Map<String, dynamic> message,
      ) {

    final mediaType =
        message['mediaType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    final msgType =
        message['msgType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    return mediaType ==
        'video' ||
        msgType ==
            'chat.video' ||
        msgType ==
            'chat.video.msg' ||
        msgType ==
            '44';
  }


  bool _isFileMessage(
      Map<String, dynamic> message,
      ) {

    final mediaType =
        message['mediaType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    final msgType =
        message['msgType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    return mediaType ==
        'file' ||
        msgType ==
            'share.file' ||
        msgType ==
            'chat.file' ||
        msgType ==
            'chat.file.msg' ||
        msgType ==
            '46';
  }


  String? _messageMediaUrl(
      Map<String, dynamic> message,
      ) {

    final value =
    message['mediaUrl']
        ?.toString()
        .trim();


    if (
    value == null ||
        value.isEmpty
    ) {

      return null;
    }


    return value;
  }


  String? _messageMediaThumbUrl(
      Map<String, dynamic> message,
      ) {

    final value =
    message['mediaThumbUrl']
        ?.toString()
        .trim();


    if (
    value == null ||
        value.isEmpty
    ) {

      return null;
    }


    return value;
  }


  String _formatFileSize(
      dynamic value,
      ) {

    final bytes =
    int.tryParse(
      value
          ?.toString() ??
          '',
    );


    if (
    bytes == null ||
        bytes <= 0
    ) {

      return '';
    }


    if (
    bytes <
        1024
    ) {

      return '$bytes B';
    }


    final kb =
        bytes /
            1024;


    if (
    kb <
        1024
    ) {

      return '${kb.toStringAsFixed(1)} KB';
    }


    final mb =
        kb /
            1024;


    if (
    mb <
        1024
    ) {

      return '${mb.toStringAsFixed(1)} MB';
    }


    final gb =
        mb /
            1024;


    return '${gb.toStringAsFixed(1)} GB';
  }

  Map<String, dynamic>
  _photoParams(
      Map<String, dynamic> message,
      ) {

    final raw =
    message['rawData'];


    if (
    raw is! Map
    ) {

      return {};
    }


    final rawMap =
    Map<String, dynamic>.from(
      raw,
    );


    final content =
    rawMap['content'];


    if (
    content is! Map
    ) {

      return {};
    }


    final contentMap =
    Map<String, dynamic>.from(
      content,
    );


    final params =
    contentMap['params'];


    if (
    params is Map
    ) {

      return Map<String, dynamic>.from(
        params,
      );
    }


    if (
    params is String &&
        params.trim().isNotEmpty
    ) {

      try {

        final decoded =
        jsonDecode(
          params,
        );


        if (
        decoded is Map
        ) {

          return Map<String, dynamic>.from(
            decoded,
          );
        }

      } catch (_) {
        // Ignore malformed params.
      }
    }


    return {};
  }

  String?
  _mediaGroupId(
      Map<String, dynamic> message,
      ) {

    final direct =
    message['mediaGroupId']
        ?.toString()
        .trim();


    if (
    direct != null &&
        direct.isNotEmpty
    ) {

      return direct;
    }


    final params =
    _photoParams(
      message,
    );


    final grouped =
        int.tryParse(
          (
              params[
              'is_group_layout'
              ] ??
                  params[
                  'isGroupLayout'
                  ] ??
                  0
          ).toString(),
        ) ==
            1;


    if (!grouped) {
      return null;
    }


    final id =
    (
        params[
        'group_layout_id'
        ] ??
            params[
            'groupLayoutId'
            ]
    )
        ?.toString()
        .trim();


    if (
    id == null ||
        id.isEmpty
    ) {

      return null;
    }


    return id;
  }

  int?
  _mediaGroupIndex(
      Map<String, dynamic> message,
      ) {

    final direct =
    int.tryParse(
      message[
      'mediaGroupIndex'
      ]
          ?.toString() ??
          '',
    );


    if (
    direct != null
    ) {

      return direct;
    }


    final params =
    _photoParams(
      message,
    );


    return int.tryParse(
      (
          params[
          'id_in_group'
          ] ??
              params[
              'idInGroup'
              ] ??
              ''
      ).toString(),
    );
  }

  List<Map<String, dynamic>>
  _albumMessagesFor(
      Map<String, dynamic> message,
      ) {

    final groupId =
    _mediaGroupId(
      message,
    );


    if (
    groupId == null
    ) {

      return [
        message,
      ];
    }


    final result =
    messages
        .where(
          (
          item,
          ) {

        if (
        item['status']
            ?.toString() !=
            'normal'
        ) {

          return false;
        }


        return _isPhotoMessage(
          item,
        ) &&
            _mediaGroupId(
              item,
            ) ==
                groupId;
      },
    )
        .toList();


    result.sort(
          (
          a,
          b,
          ) {

        final aIndex =
            _mediaGroupIndex(
              a,
            ) ??
                999999;


        final bIndex =
            _mediaGroupIndex(
              b,
            ) ??
                999999;


        if (
        aIndex !=
            bIndex
        ) {

          return aIndex
              .compareTo(
            bIndex,
          );
        }


        return (
            int.tryParse(
              a['timestamp']
                  ?.toString() ??
                  '',
            ) ??
                0
        ).compareTo(
          int.tryParse(
            b['timestamp']
                ?.toString() ??
                '',
          ) ??
              0,
        );
      },
    );


    return result;
  }

  int _albumRenderIndex(
      String groupId,
      ) {

    // ========================================
    // NEU DANG TARGET MOT PHOTO TRONG ALBUM
    // THI RENDER ALBUM TAI CHINH TARGET DO.
    // ========================================

    final target =
        targetIndex;


    if (
    target != null &&
        target >= 0 &&
        target <
            messages.length &&
        _mediaGroupId(
          messages[target],
        ) ==
            groupId
    ) {

      return target;
    }


    int bestIndex =
    -1;


    int bestOrder =
    999999;


    for (
    var index = 0;
    index <
        messages.length;
    index += 1
    ) {

      final item =
      messages[index];


      if (
      item['status']
          ?.toString() !=
          'normal' ||
          !_isPhotoMessage(
            item,
          ) ||
          _mediaGroupId(
            item,
          ) !=
              groupId
      ) {

        continue;
      }


      final order =
          _mediaGroupIndex(
            item,
          ) ??
              999998;


      if (
      bestIndex <
          0 ||
          order <
              bestOrder
      ) {

        bestIndex =
            index;

        bestOrder =
            order;
      }
    }


    return bestIndex;
  }

  Widget _buildPhotoMessage(
      Map<String, dynamic> message,
      ) {

    final photoUrl =
    _extractPhotoUrl(
      message,
    );


    if (
    photoUrl == null ||
        photoUrl.isEmpty
    ) {

      return const SizedBox(
        width:
        180,

        height:
        120,

        child:
        Center(
          child:
          Icon(
            Icons
                .broken_image_outlined,

            size:
            32,
          ),
        ),
      );
    }


    final params =
    _photoParams(
      message,
    );


    final width =
    double.tryParse(
      (
          message[
          'mediaWidth'
          ] ??
              params[
              'width'
              ] ??
              ''
      ).toString(),
    );


    final height =
    double.tryParse(
      (
          message[
          'mediaHeight'
          ] ??
              params[
              'height'
              ] ??
              ''
      ).toString(),
    );


    const maxWidth =
    290.0;


    const maxHeight =
    430.0;


    double displayWidth =
        maxWidth;


    double displayHeight =
    260;


    if (
    width != null &&
        height != null &&
        width > 0 &&
        height > 0
    ) {

      final scale =
      math.min(
        maxWidth /
            width,

        maxHeight /
            height,
      );


      displayWidth =
          width *
              scale;


      displayHeight =
          height *
              scale;
    }


    final heroTag =
    _photoHeroTag(
      message,
    );


    return GestureDetector(

      onTap:
          () {

        _openPhotoViewer(
          message,
        );
      },


      child:
      Hero(

        tag:
        heroTag,


        child:
        ClipRRect(

          borderRadius:
          BorderRadius.circular(
            10,
          ),


          child:
          SizedBox(

            width:
            displayWidth,

            height:
            displayHeight,


            child:
            Image.network(

              photoUrl,


              // QUAN TRONG:
              // KHONG CROP ANH DON.
              fit:
              BoxFit.contain,


              errorBuilder:
                  (
                  context,
                  error,
                  stackTrace,
                  ) {

                return const Center(
                  child:
                  Icon(
                    Icons
                        .broken_image_outlined,

                    size:
                    32,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerMessage(
      Map<String, dynamic> message,
      ) {

    final stickerUrl =
    _messageMediaUrl(
      message,
    );


    if (
    stickerUrl == null
    ) {

      return const SizedBox(
        width:
        130,

        height:
        130,

        child:
        Center(
          child:
          Icon(
            Icons
                .emoji_emotions_outlined,

            size:
            42,

            color:
            Color(
              0xFF87939D,
            ),
          ),
        ),
      );
    }


    return SizedBox(

      width:
      130,

      height:
      130,

      child:
      Image.network(

        stickerUrl,

        fit:
        BoxFit.contain,

        gaplessPlayback:
        true,

        loadingBuilder:
            (
            context,
            child,
            loadingProgress,
            ) {

          if (
          loadingProgress ==
              null
          ) {

            return child;
          }


          return const Center(

            child:
            SizedBox(

              width:
              24,

              height:
              24,

              child:
              CircularProgressIndicator(
                strokeWidth:
                2,
              ),
            ),
          );
        },

        errorBuilder:
            (
            context,
            error,
            stackTrace,
            ) {

          return const Center(

            child:
            Icon(

              Icons
                  .broken_image_outlined,

              size:
              36,

              color:
              Color(
                0xFF87939D,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoMessage(
      Map<String, dynamic> message,
      ) {

    final thumbUrl =
    _messageMediaThumbUrl(
      message,
    );


    final videoUrl =
    _messageMediaUrl(
      message,
    );


    final width =
    double.tryParse(
      message['mediaWidth']
          ?.toString() ??
          '',
    );


    final height =
    double.tryParse(
      message['mediaHeight']
          ?.toString() ??
          '',
    );


    const maxWidth =
    280.0;


    const maxHeight =
    390.0;


    double displayWidth =
    260;


    double displayHeight =
    200;


    if (
    width != null &&
        height != null &&
        width > 0 &&
        height > 0
    ) {

      final scale =
      math.min(
        maxWidth /
            width,

        maxHeight /
            height,
      );


      displayWidth =
          width *
              scale;


      displayHeight =
          height *
              scale;
    }


    return Material(

      color:
      Colors.transparent,


      child:
      InkWell(

        borderRadius:
        BorderRadius.circular(
          12,
        ),


        // ========================================
        // BAM VIDEO
        // ========================================

        onTap:
            () {

          debugPrint(
            'VIDEO TAP: '
                'url=$videoUrl',
          );


          _openVideo(
            message,
          );
        },


        child:
        ClipRRect(

          borderRadius:
          BorderRadius.circular(
            12,
          ),


          child:
          SizedBox(

            width:
            displayWidth,

            height:
            displayHeight,


            child:
            Stack(

              fit:
              StackFit.expand,


              children: [

                // ========================================
                // THUMBNAIL
                // ========================================

                if (
                thumbUrl !=
                    null
                )

                  Image.network(

                    thumbUrl,

                    fit:
                    BoxFit.cover,


                    errorBuilder:
                        (
                        context,
                        error,
                        stackTrace,
                        ) {

                      return Container(

                        color:
                        const Color(
                          0xFFE0E5E9,
                        ),

                        alignment:
                        Alignment.center,

                        child:
                        const Icon(
                          Icons
                              .videocam_outlined,

                          size:
                          46,
                        ),
                      );
                    },
                  )

                else

                  Container(

                    color:
                    const Color(
                      0xFFE0E5E9,
                    ),

                    alignment:
                    Alignment.center,

                    child:
                    const Icon(

                      Icons
                          .videocam_outlined,

                      size:
                      46,
                    ),
                  ),


                // ========================================
                // DARK OVERLAY
                // ========================================

                const ColoredBox(

                  color:
                  Color(
                    0x22000000,
                  ),
                ),


                // ========================================
                // PLAY BUTTON
                // ========================================

                const Center(

                  child:
                  IgnorePointer(

                    child:
                    DecoratedBox(

                      decoration:
                      BoxDecoration(

                        color:
                        Color(
                          0xCC000000,
                        ),

                        shape:
                        BoxShape.circle,
                      ),


                      child:
                      Padding(

                        padding:
                        EdgeInsets.all(
                          12,
                        ),


                        child:
                        Icon(

                          Icons
                              .play_arrow_rounded,

                          size:
                          36,

                          color:
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileMessage(
      Map<String, dynamic> message,
      ) {

    final fileName =
    message['fileName']
        ?.toString()
        .trim();


    final extension =
    message['fileExtension']
        ?.toString()
        .trim()
        .toUpperCase();


    final fileSize =
    _formatFileSize(
      message[
      'mediaFileSize'
      ],
    );


    final safeFileName =
    fileName != null &&
        fileName.isNotEmpty
        ? fileName
        : 'Tệp đính kèm';


    return Material(

      color:
      Colors.transparent,


      child:
      InkWell(

        borderRadius:
        BorderRadius.circular(
          12,
        ),


        onTap:
            () {

          _openFileMessage(
            message,
          );
        },


        child:
        Container(

          constraints:
          const BoxConstraints(
            maxWidth:
            285,
          ),

          padding:
          const EdgeInsets.all(
            11,
          ),

          decoration:
          BoxDecoration(

            color:
            Colors.white,

            borderRadius:
            BorderRadius.circular(
              12,
            ),

            boxShadow:
            const [

              BoxShadow(
                color:
                Color(
                  0x10000000,
                ),

                blurRadius:
                3,

                offset:
                Offset(
                  0,
                  1,
                ),
              ),
            ],
          ),

          child:
          Row(

            mainAxisSize:
            MainAxisSize.min,

            children: [

              Container(

                width:
                48,

                height:
                48,

                decoration:
                BoxDecoration(

                  color:
                  const Color(
                    0xFFE8F3FA,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),

                alignment:
                Alignment.center,

                child:
                extension !=
                    null &&
                    extension
                        .isNotEmpty

                    ? Text(

                  extension,

                  maxLines:
                  1,

                  style:
                  const TextStyle(

                    fontSize:
                    11,

                    fontWeight:
                    FontWeight.w700,

                    color:
                    Color(
                      0xFF1687C9,
                    ),
                  ),
                )

                    : const Icon(

                  Icons
                      .insert_drive_file_outlined,

                  color:
                  Color(
                    0xFF1687C9,
                  ),
                ),
              ),


              const SizedBox(
                width:
                10,
              ),


              Flexible(

                child:
                Column(

                  mainAxisSize:
                  MainAxisSize.min,

                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [

                    Text(

                      safeFileName,

                      maxLines:
                      2,

                      overflow:
                      TextOverflow.ellipsis,

                      style:
                      const TextStyle(

                        fontSize:
                        14,

                        fontWeight:
                        FontWeight.w600,

                        color:
                        Color(
                          0xFF26333D,
                        ),
                      ),
                    ),


                    if (
                    fileSize
                        .isNotEmpty
                    ) ...[

                      const SizedBox(
                        height:
                        4,
                      ),


                      Text(

                        fileSize,

                        style:
                        const TextStyle(

                          fontSize:
                          11,

                          color:
                          Color(
                            0xFF87939D,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),


              const SizedBox(
                width:
                6,
              ),


              const Icon(

                Icons
                    .open_in_new_rounded,

                size:
                21,

                color:
                Color(
                  0xFF1687C9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumPhotoTile(
      Map<String, dynamic> message, {
        required double width,
        required double height,
        int extraCount = 0,
      }) {

    final photoUrl =
    _extractPhotoUrl(
      message,
    );


    if (
    photoUrl == null ||
        photoUrl.isEmpty
    ) {

      return SizedBox(

        width:
        width,

        height:
        height,

        child:
        const Center(

          child:
          Icon(
            Icons
                .broken_image_outlined,
          ),
        ),
      );
    }


    return GestureDetector(

      behavior:
      HitTestBehavior.opaque,


      onTap:
          () {

        // ========================================
        // KHONG MO RIENG ALBUM NUA.
        //
        // MO GLOBAL PHOTO VIEWER.
        // ========================================

        _openPhotoViewer(
          message,
        );
      },


      child:
      Hero(

        tag:
        _photoHeroTag(
          message,
        ),


        child:
        ClipRRect(

          borderRadius:
          BorderRadius.circular(
            8,
          ),


          child:
          SizedBox(

            width:
            width,

            height:
            height,


            child:
            Stack(

              fit:
              StackFit.expand,


              children: [

                Image.network(

                  photoUrl,

                  fit:
                  BoxFit.cover,


                  errorBuilder:
                      (
                      context,
                      error,
                      stackTrace,
                      ) {

                    return const Center(

                      child:
                      Icon(
                        Icons
                            .broken_image_outlined,
                      ),
                    );
                  },
                ),


                if (
                extraCount >
                    0
                )
                  Container(

                    color:
                    const Color(
                      0x77000000,
                    ),


                    alignment:
                    Alignment.center,


                    child:
                    Text(

                      '+$extraCount',

                      style:
                      const TextStyle(

                        color:
                        Colors.white,

                        fontSize:
                        27,

                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoAlbum(
      List<Map<String, dynamic>>
      album,
      ) {

    if (
    album.isEmpty
    ) {

      return const SizedBox
          .shrink();
    }


    // ========================================
    // 1 PHOTO
    // ========================================

    if (
    album.length ==
        1
    ) {

      return _buildPhotoMessage(
        album.first,
      );
    }


    const width =
    300.0;


    const gap =
    4.0;


    // ========================================
    // 2 PHOTOS
    // ========================================

    if (
    album.length ==
        2
    ) {

      final itemWidth =
          (
              width -
                  gap
          ) /
              2;


      return Row(

        mainAxisSize:
        MainAxisSize.min,


        children: [

          _buildAlbumPhotoTile(

            album[0],

            width:
            itemWidth,

            height:
            190,
          ),


          const SizedBox(
            width:
            gap,
          ),


          _buildAlbumPhotoTile(

            album[1],

            width:
            itemWidth,

            height:
            190,
          ),
        ],
      );
    }


    // ========================================
    // 3 PHOTOS
    //
    // [      1      ][ 2 ]
    // [      1      ][ 3 ]
    // ========================================

    if (
    album.length ==
        3
    ) {

      const bigWidth =
      184.0;


      const smallWidth =
          width -
              bigWidth -
              gap;


      return Row(

        mainAxisSize:
        MainAxisSize.min,


        children: [

          _buildAlbumPhotoTile(

            album[0],

            width:
            bigWidth,

            height:
            224,
          ),


          const SizedBox(
            width:
            gap,
          ),


          Column(

            children: [

              _buildAlbumPhotoTile(

                album[1],

                width:
                smallWidth,

                height:
                110,
              ),


              const SizedBox(
                height:
                gap,
              ),


              _buildAlbumPhotoTile(

                album[2],

                width:
                smallWidth,

                height:
                110,
              ),
            ],
          ),
        ],
      );
    }


    // ========================================
    // 4+ PHOTOS
    //
    // [          PHOTO 1          ]
    //
    // [ PHOTO2 ][ PHOTO3 ][ PHOTO4 ]
    // ========================================

    final smallWidth =
        (
            width -
                gap *
                    2
        ) /
            3;


    final extra =
    album.length >
        4
        ? album.length -
        4
        : 0;


    return Column(

      mainAxisSize:
      MainAxisSize.min,


      children: [

        _buildAlbumPhotoTile(

          album[0],

          width:
          width,

          height:
          225,
        ),


        const SizedBox(
          height:
          gap,
        ),


        Row(

          mainAxisSize:
          MainAxisSize.min,


          children: [

            _buildAlbumPhotoTile(

              album[1],

              width:
              smallWidth,

              height:
              105,
            ),


            const SizedBox(
              width:
              gap,
            ),


            _buildAlbumPhotoTile(

              album[2],

              width:
              smallWidth,

              height:
              105,
            ),


            const SizedBox(
              width:
              gap,
            ),


            _buildAlbumPhotoTile(

              album[3],

              width:
              smallWidth,

              height:
              105,

              extraCount:
              extra,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoMediaRow(
      Map<String, dynamic> message,
      int index,
      ) {

    final isSelf =
        message['isSelf'] ==
            true;


    final senderName =
        message['senderName']
            ?.toString() ??
            'Thành viên';


    final mediaGroupId =
    _mediaGroupId(
      message,
    );


    final album =
    mediaGroupId !=
        null
        ? _albumMessagesFor(
      message,
    )
        : [
      message,
    ];


    final media =
    album.length >
        1
        ? _buildPhotoAlbum(
      album,
    )
        : _buildPhotoMessage(
      message,
    );


    final stableKey =
        mediaGroupId ??
            message['id']
                ?.toString() ??
            message['msgId']
                ?.toString() ??
            message['cliMsgId']
                ?.toString() ??
            index.toString();


    final isTarget =
        index ==
            targetIndex;


    final timestampMessage =
    album.isNotEmpty
        ? album.last
        : message;


    final content =
    Container(

      key:
      isTarget
          ? targetMessageKey
          : ValueKey(
        'chat-media-$stableKey',
      ),


      color:
      isTarget &&
          highlightTarget
          ? const Color(
        0x332197F3,
      )
          : Colors.transparent,


      padding:
      const EdgeInsets.fromLTRB(
        10,
        4,
        10,
        4,
      ),


      child:
      Row(

        mainAxisAlignment:
        isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,


        crossAxisAlignment:
        CrossAxisAlignment.start,


        children: [

          // ========================================
          // AVATAR NGUOI KHAC
          // ========================================

          if (
          !isSelf
          ) ...[

            CircleAvatar(

              radius:
              17,

              backgroundColor:
              const Color(
                0xFF76D770,
              ),

              child:
              Text(

                _messageInitials(
                  senderName,
                ),

                style:
                const TextStyle(

                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.w500,

                  color:
                  Colors.white,
                ),
              ),
            ),


            const SizedBox(
              width:
              7,
            ),
          ],


          Flexible(

            child:
            Column(

              crossAxisAlignment:
              isSelf
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,


              children: [

                // ========================================
                // TEN NGUOI GUI
                // KHONG NAM TRONG BUBBLE
                // ========================================

                if (
                !isSelf
                ) ...[

                  Padding(

                    padding:
                    const EdgeInsets.only(
                      left:
                      2,

                      bottom:
                      4,
                    ),

                    child:
                    Text(

                      senderName,

                      style:
                      const TextStyle(

                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.w600,

                        color:
                        Color(
                          0xFF1579AF,
                        ),
                      ),
                    ),
                  ),
                ],


                // ========================================
                // PHOTO / ALBUM
                // KHONG CON CONTAINER BUBBLE
                // ========================================

                media,


                const SizedBox(
                  height:
                  3,
                ),


                Text(

                  formatTime(
                    timestampMessage[
                    'timestamp'
                    ],
                  ),

                  style:
                  const TextStyle(

                    fontSize:
                    10,

                    color:
                    Color(
                      0xFF87939D,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );


    return _SwipeReplyWrapper(

      enabled:
      true,


      onReply:
          () {

        _startReply(
          message,
        );
      },


      onLongPress:
          () {

        _showMessageActions(
          message,
        );
      },


      child:
      content,
    );
  }

  Widget _buildSimpleMediaRow(
      Map<String, dynamic> message,
      int index,
      Widget media,
      ) {

    final isSelf =
        message['isSelf'] ==
            true;


    final senderName =
        message['senderName']
            ?.toString() ??
            'Thành viên';


    final isTarget =
        index ==
            targetIndex;


    final stableKey =
        message['id']
            ?.toString() ??
            message['msgId']
                ?.toString() ??
            message['cliMsgId']
                ?.toString() ??
            index.toString();


    final content =
    Container(

      key:
      isTarget
          ? targetMessageKey
          : ValueKey(
        'chat-media-$stableKey',
      ),

      color:
      isTarget &&
          highlightTarget
          ? const Color(
        0x332197F3,
      )
          : Colors.transparent,

      padding:
      const EdgeInsets.fromLTRB(
        10,
        4,
        10,
        4,
      ),

      child:
      Row(

        mainAxisAlignment:
        isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          if (
          !isSelf
          ) ...[

            CircleAvatar(

              radius:
              17,

              backgroundColor:
              const Color(
                0xFF76D770,
              ),

              child:
              Text(

                _messageInitials(
                  senderName,
                ),

                style:
                const TextStyle(

                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.w500,

                  color:
                  Colors.white,
                ),
              ),
            ),


            const SizedBox(
              width:
              7,
            ),
          ],


          Flexible(

            child:
            Column(

              crossAxisAlignment:
              isSelf
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,

              children: [

                if (
                !isSelf
                ) ...[

                  Padding(

                    padding:
                    const EdgeInsets.only(
                      left:
                      2,

                      bottom:
                      4,
                    ),

                    child:
                    Text(

                      senderName,

                      style:
                      const TextStyle(

                        fontSize:
                        12,

                        fontWeight:
                        FontWeight.w600,

                        color:
                        Color(
                          0xFF1579AF,
                        ),
                      ),
                    ),
                  ),
                ],


                media,


                const SizedBox(
                  height:
                  3,
                ),


                Text(

                  formatTime(
                    message[
                    'timestamp'
                    ],
                  ),

                  style:
                  const TextStyle(

                    fontSize:
                    10,

                    color:
                    Color(
                      0xFF87939D,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );


    return _SwipeReplyWrapper(

      enabled:
      true,

      onReply:
          () {

        _startReply(
          message,
        );
      },

      onLongPress:
          () {

        _showMessageActions(
          message,
        );
      },

      child:
      content,
    );
  }

  // ========================================
  // MESSAGE BUBBLE
  // ========================================

  Widget buildMessage(
      Map<String, dynamic> message,
      int index,
      ) {

    final isSelf =
        message['isSelf'] ==
            true;


    final status =
        message['status']
            ?.toString() ??
            'normal';

    final msgType =
        message['msgType']
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';


    final isPhoto =
        msgType ==
            'chat.photo' ||
            msgType ==
                '32';

    // ========================================
    // MESSAGE DA XOA KHONG DUOC RENDER
    // ========================================

    if (
    status ==
        'deleted_local'
    ) {

      return const SizedBox
          .shrink();
    }

    // ========================================
// PHOTO / PHOTO ALBUM
//
// KHONG CHAY VAO TEXT BUBBLE.
//
// 1 PHOTO
// -> PHOTO DOC LAP.
//
// PHOTO ALBUM
// -> GRID DOC LAP.
// ========================================

    if (
    status ==
        'normal' &&
        _isPhotoMessage(
          message,
        )
    ) {

      final mediaGroupId =
      _mediaGroupId(
        message,
      );


      // ========================================
      // ALBUM:
      // CHI RENDER MOT LAN.
      // ========================================

      if (
      mediaGroupId !=
          null
      ) {

        final renderIndex =
        _albumRenderIndex(
          mediaGroupId,
        );


        if (
        renderIndex !=
            index
        ) {

          return const SizedBox
              .shrink();
        }
      }


      return _buildPhotoMediaRow(
        message,
        index,
      );
    }

    // ========================================
// STICKER
// ========================================

    if (
    status ==
        'normal' &&
        _isStickerMessage(
          message,
        )
    ) {

      return _buildSimpleMediaRow(

        message,

        index,

        _buildStickerMessage(
          message,
        ),
      );
    }


// ========================================
// VIDEO
// ========================================

    if (
    status ==
        'normal' &&
        _isVideoMessage(
          message,
        )
    ) {

      return _buildSimpleMediaRow(

        message,

        index,

        _buildVideoMessage(
          message,
        ),
      );
    }


// ========================================
// FILE
// ========================================

    if (
    status ==
        'normal' &&
        _isFileMessage(
          message,
        )
    ) {

      return _buildSimpleMediaRow(

        message,

        index,

        _buildFileMessage(
          message,
        ),
      );
    }

    final senderName =
        message['senderName']
            ?.toString() ??
            'Thành viên';


    String content;


    if (
    status ==
        'recalled'
    ) {

      content =
      'Tin nhắn đã được thu hồi';

    } else if (
    isPhoto
    ) {

      content =
      '[Hình ảnh]';

    } else {

      content =
          message['content']
              ?.toString() ??
              message['preview']
                  ?.toString() ??
              '[Tin nhắn]';
    }


    // ========================================
    // TARGET
    // ========================================

    final isTarget =
        index ==
            targetIndex;


    final stableMessageId =
        message['id']
            ?.toString() ??
            message['msgId']
                ?.toString() ??
            message['cliMsgId']
                ?.toString() ??
            index.toString();


    // ========================================
    // QUOTE CUA ZALO
    //
    // zca-js:
    // fromD = ten nguoi gui tin goc
    // msg   = noi dung tin goc
    // ========================================

    final quote =
    _extractQuote(
      message,
    );


    final quoteSender =
        quote?['fromD']
            ?.toString()
            .trim() ??
            '';


    final quoteMessage =
        quote?['msg']
            ?.toString()
            .trim() ??
            '';


    final safeQuoteSender =
    quoteSender.isNotEmpty
        ? quoteSender
        : 'Tin nhắn được trả lời';


    final safeQuoteMessage =
    quoteMessage.isNotEmpty
        ? quoteMessage
        : '[Tin nhắn]';


    // ========================================
    // MAU GIONG ZALO
    // ========================================

    const incomingBubble =
    Color(
      0xFFFFFFFF,
    );


    const outgoingBubble =
    Color(
      0xFFCDEFFF,
    );


    const normalText =
    Color(
      0xFF26333D,
    );


    const secondaryText =
    Color(
      0xFF87939D,
    );


    const nameColor =
    Color(
      0xFF1579AF,
    );


    const quoteLineColor =
    Color(
      0xFF00A8F3,
    );


    final bubble =
    Container(
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


        boxShadow:
        const [

          BoxShadow(
            color:
            Color(
              0x12000000,
            ),

            blurRadius:
            3,

            offset:
            Offset(
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
              TextOverflow.ellipsis,

              style:
              const TextStyle(
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
          // QUOTE GIONG ZALO
          // ========================================

          if (
          quote != null
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
                    () {

                  _jumpToQuotedMessage(
                    quote,
                  );
                },

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
                        ? const Color(
                      0x99FFFFFF,
                    )
                        : const Color(
                      0xFFF3F5F7,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      6,
                    ),

                    border:
                    const Border(
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
                        TextOverflow.ellipsis,

                        style:
                        const TextStyle(
                          fontSize:
                          12,

                          fontWeight:
                          FontWeight.w700,

                          color:
                          Color(
                            0xFF34444F,
                          ),
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
                        TextOverflow.ellipsis,

                        style:
                        const TextStyle(
                          fontSize:
                          13,

                          color:
                          Color(
                            0xFF7F8B94,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],


          // ========================================
          // NOI DUNG MESSAGE
          // ========================================

          if (
          status ==
              'recalled'
          )
            Text(
              content,

              style:
              const TextStyle(
                fontSize:
                15,

                height:
                1.25,

                color:
                normalText,

                fontStyle:
                FontStyle.italic,
              ),
            )

          else if (
          isPhoto
          )
            _buildPhotoMessage(
              message,
            )

          else
            Text(
              content,

              style:
              const TextStyle(
                fontSize:
                15,

                height:
                1.25,

                color:
                normalText,
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
              formatTime(
                message[
                'timestamp'
                ],
              ),

              style:
              const TextStyle(
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


    // ========================================
    // AVATAR + BUBBLE
    // ========================================

    final messageRow =
    Container(

      key:
      isTarget
          ? targetMessageKey
          : ValueKey(
        'chat-message-$stableMessageId',
      ),


      color:
      isTarget &&
          highlightTarget
          ? const Color(
        0x332197F3,
      )
          : Colors.transparent,


      padding:
      const EdgeInsets
          .fromLTRB(
        10,
        4,
        10,
        4,
      ),


      child:
      Row(

        mainAxisAlignment:
        isSelf
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,


        crossAxisAlignment:
        CrossAxisAlignment.start,


        children: [

          // ========================================
          // AVATAR CHO NGUOI KHAC
          // ========================================

          if (
          !isSelf
          ) ...[

            CircleAvatar(
              radius:
              17,

              backgroundColor:
              const Color(
                0xFF76D770,
              ),

              child:
              Text(
                _messageInitials(
                  senderName,
                ),

                style:
                const TextStyle(
                  fontSize:
                  11,

                  fontWeight:
                  FontWeight.w500,

                  color:
                  Colors.white,
                ),
              ),
            ),


            const SizedBox(
              width:
              7,
            ),
          ],
          Flexible(
            child:
            bubble,
          ),
        ],
      ),
    );


    // ========================================
    // SWIPE LEFT = REPLY
    //
    // NHAN GIU VAN MO ACTION SHEET.
    // ========================================

    return _SwipeReplyWrapper(

      enabled:
      status ==
          'normal',


      onReply:
          () {

        _startReply(
          message,
        );
      },


      onLongPress:
          () {

        _showMessageActions(
          message,
        );
      },


      child:
      messageRow,
    );
  }

  Widget _buildMessageComposer() {

    final colorScheme =
        Theme.of(context)
            .colorScheme;


    final disabled =
        loading ||
            seekingTarget;


    final reply =
        replyingToMessage;


    String replySender =
        'Tin nhắn';


    String replyContent =
        '';


    if (
    reply != null
    ) {

      final isSelf =
          reply['isSelf'] ==
              true;


      replySender =
      isSelf
          ? 'Bạn'
          : (
          reply['senderName']
              ?.toString() ??
              'Thành viên'
      );


      replyContent =
          reply['content']
              ?.toString() ??
              reply['preview']
                  ?.toString() ??
              '[Tin nhắn]';
    }


    return SafeArea(
      top:
      false,

      child:
      Material(
        color:
        colorScheme.surface,

        elevation:
        6,

        child:
        Padding(
          padding:
          const EdgeInsets
              .fromLTRB(
            10,
            7,
            8,
            8,
          ),

          child:
          Column(
            mainAxisSize:
            MainAxisSize.min,

            children: [

              // ========================================
              // REPLY PREVIEW
              // ========================================

              if (
              reply != null
              ) ...[

                Container(
                  width:
                  double.infinity,

                  margin:
                  const EdgeInsets.only(
                    bottom:
                    6,
                  ),

                  padding:
                  const EdgeInsets
                      .fromLTRB(
                    12,
                    8,
                    6,
                    8,
                  ),

                  decoration:
                  BoxDecoration(
                    color:
                    colorScheme
                        .surfaceContainerHighest,

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),

                  child:
                  Row(
                    children: [

                      Container(
                        width:
                        3,

                        height:
                        38,

                        decoration:
                        BoxDecoration(
                          color:
                          colorScheme
                              .primary,

                          borderRadius:
                          BorderRadius.circular(
                            3,
                          ),
                        ),
                      ),


                      const SizedBox(
                        width:
                        10,
                      ),


                      Expanded(
                        child:
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [

                            Text(
                              replySender,

                              maxLines:
                              1,

                              overflow:
                              TextOverflow.ellipsis,

                              style:
                              TextStyle(
                                fontSize:
                                12,

                                fontWeight:
                                FontWeight.w700,

                                color:
                                colorScheme.primary,
                              ),
                            ),


                            const SizedBox(
                              height:
                              2,
                            ),


                            Text(
                              replyContent,

                              maxLines:
                              1,

                              overflow:
                              TextOverflow.ellipsis,

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


                      IconButton(
                        tooltip:
                        'Hủy trả lời',

                        visualDensity:
                        VisualDensity.compact,

                        onPressed:
                        _cancelReply,

                        icon:
                        const Icon(
                          Icons.close_rounded,

                          size:
                          20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],


              // ========================================
              // TEXT FIELD + SEND
              // ========================================

              Row(
                crossAxisAlignment:
                CrossAxisAlignment.end,

                children: [
                  SizedBox(
                    width:
                    42,

                    height:
                    46,

                    child:
                    IconButton(

                      tooltip:
                      'Gửi ảnh',


                      onPressed:
                      disabled ||
                          sendingMessage ||
                          sendingPhoto
                          ? null
                          : _pickAndSendPhoto,


                      icon:
                      sendingPhoto
                          ? const SizedBox(
                        width:
                        20,

                        height:
                        20,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )

                          : const Icon(
                        Icons
                            .photo_outlined,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width:
                    2,
                  ),

                  Expanded(
                    child:
                    TextField(
                      controller:
                      messageController,

                      focusNode:
                      messageFocusNode,

                      enabled:
                      !disabled,

                      minLines:
                      1,

                      maxLines:
                      5,

                      keyboardType:
                      TextInputType.multiline,

                      textCapitalization:
                      TextCapitalization.sentences,

                      decoration:
                      InputDecoration(
                        hintText:
                        disabled
                            ? 'Đang tải hội thoại...'
                            : (
                            reply != null
                                ? 'Trả lời tin nhắn'
                                : 'Tin nhắn'
                        ),

                        filled:
                        true,

                        fillColor:
                        colorScheme
                            .surfaceContainerHighest,

                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal:
                          16,

                          vertical:
                          11,
                        ),

                        border:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            24,
                          ),

                          borderSide:
                          BorderSide.none,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            24,
                          ),

                          borderSide:
                          BorderSide.none,
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            24,
                          ),

                          borderSide:
                          BorderSide(
                            color:
                            colorScheme.primary,

                            width:
                            1.2,
                          ),
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(
                    width:
                    6,
                  ),


                  SizedBox(
                    width:
                    46,

                    height:
                    46,

                    child:
                    IconButton.filled(
                      onPressed:
                      disabled ||
                          sendingMessage ||
                          sendingPhoto ||
                          !canSendMessage
                          ? null
                          : _sendChatMessage,

                      icon:
                      sendingMessage
                          ? const SizedBox(
                        width:
                        20,

                        height:
                        20,

                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                        ),
                      )

                          : const Icon(
                        Icons.send_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {

    WidgetsBinding
        .instance
        .removeObserver(
      this,
    );


    markReadTimer
        ?.cancel();

    realtimeSubscription
        ?.cancel();

    realtimeReloadTimer
        ?.cancel();

    targetHighlightTimer
        ?.cancel();

    topNoticeTimer
        ?.cancel();

    backend.disconnect();

    messageController
        .removeListener(
      _handleComposerChanged,
    );

    messageController
        .dispose();

    messageFocusNode
        .dispose();

    scrollController
        .dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {

    return Scaffold(

      backgroundColor:
      const Color(
        0xFFE9EDF7,
      ),

      appBar:
      AppBar(
        title:
        Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [

            Text(
              widget.groupName,

              maxLines:
              1,

              overflow:
              TextOverflow
                  .ellipsis,
            ),

            const Text(
              'Nhóm Zalo',

              style:
              TextStyle(
                fontSize:
                12,

                fontWeight:
                FontWeight.normal,
              ),
            ),
          ],
        ),
      ),


      body:
      Column(
        children: [

          // ========================================
          // KHU VUC NOI DUNG CHAT
          // ========================================

          Expanded(
            child:
            ColoredBox(
              color:
                const Color(
                  0xFFE9EDF7,
                ),

              child:
                loading
                ? const Center(
              child:
              CircularProgressIndicator(),
            )

                : messages.isEmpty
                ? ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),

              children:
              const [

                SizedBox(
                  height:
                  250,
                ),

                Icon(
                  Icons
                      .chat_bubble_outline,

                  size:
                  64,
                ),

                SizedBox(
                  height:
                  14,
                ),

                Text(
                  'Chưa có tin nhắn',

                  textAlign:
                  TextAlign.center,

                  style:
                  TextStyle(
                    fontSize:
                    19,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            )

                : NotificationListener<
                ScrollNotification>(

              onNotification:
              _handleScrollNotification,

              child:
              ListView(
                controller:
                scrollController,


                // ========================================
                // REVERSE CHAT
                //
                // OFFSET 0 = TIN MOI NHAT
                // ========================================

                reverse:
                true,


                // Khi keo danh sach chat
                // thi dong ban phim.
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,


                padding:
                const EdgeInsets.symmetric(
                  vertical:
                  12,
                ),


                physics:
                const AlwaysScrollableScrollPhysics(),


                children:
                List.generate(
                  messages.length,

                      (
                      displayIndex,
                      ) {

                    // ========================================
                    // DATA:
                    //
                    // CU NHAT -> MOI NHAT
                    //
                    // HIEN THI:
                    //
                    // MOI NHAT -> CU NHAT
                    // ========================================

                    final messageIndex =
                        messages.length -
                            1 -
                            displayIndex;


                    return buildMessage(
                      messages[
                      messageIndex],

                      messageIndex,
                    );
                  },
                ),
              ),
            ),
          ),
          ),


          // ========================================
          // O NHAP TIN NHAN
          //
          // LUON NAM CO DINH DUOI MAN HINH.
          // ========================================

          _buildMessageComposer(),
        ],
      ),
    );
  }
}