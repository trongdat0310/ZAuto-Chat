import 'dart:math' as math;

import 'package:flutter/material.dart';

class PhotoViewerItem {
  final String url;

  final String heroTag;

  const PhotoViewerItem({required this.url, required this.heroTag});
}

class PhotoViewerLoadResult {
  final List<PhotoViewerItem> items;

  final bool hasMoreOlder;

  const PhotoViewerLoadResult({
    required this.items,
    required this.hasMoreOlder,
  });
}

class PhotoViewerPage extends StatefulWidget {
  final List<PhotoViewerItem> items;

  final int initialIndex;

  final bool initialHasMoreOlder;

  final Future<PhotoViewerLoadResult> Function()? onLoadOlder;

  const PhotoViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.initialHasMoreOlder,
    this.onLoadOlder,
  });

  @override
  State<PhotoViewerPage> createState() => PhotoViewerPageState();
}

class PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController pageController;

  late List<PhotoViewerItem> viewerItems;

  int currentIndex = 0;

  bool currentPageZoomed = false;

  // ========================================
  // VIEWER CONTROLS
  // ========================================

  bool controlsVisible = true;

  // ========================================
  // SWIPE DOWN TO DISMISS
  // ========================================

  double dismissOffsetY = 0.0;

  bool draggingToDismiss = false;

  bool controlsVisibleBeforeDrag = true;

  bool loadingOlderPhotos = false;

  late bool hasMoreOlder;

  @override
  void initState() {
    super.initState();

    viewerItems = List<PhotoViewerItem>.from(widget.items);

    hasMoreOlder = widget.initialHasMoreOlder;

    if (viewerItems.isEmpty) {
      currentIndex = 0;
    } else {
      currentIndex = widget.initialIndex.clamp(0, viewerItems.length - 1);
    }

    pageController = PageController(initialPage: currentIndex);

    // ========================================
    // NEU USER MO MOT ANH GAN DAU HISTORY
    // THI PREFETCH LUON ANH CU HON.
    // ========================================

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentIndex <= 1) {
        _loadOlderIfNeeded();
      }
    });
  }

  // ========================================
  // LOAD THEM PHOTO CU
  // ========================================

  Future<void> _loadOlderIfNeeded() async {
    if (loadingOlderPhotos ||
        !hasMoreOlder ||
        widget.onLoadOlder == null ||
        viewerItems.isEmpty) {
      return;
    }

    final currentTag = viewerItems[currentIndex].heroTag;

    setState(() {
      loadingOlderPhotos = true;
    });

    try {
      final result = await widget.onLoadOlder!();

      if (!mounted) {
        return;
      }

      final newItems = result.items;

      // ========================================
      // TIM LAI ANH DANG XEM
      //
      // VI ANH CU VUA DUOC CHEN VAO DAU LIST,
      // INDEX CUA ANH HIEN TAI SE THAY DOI.
      // ========================================

      var newCurrentIndex = newItems.indexWhere(
        (item) => item.heroTag == currentTag,
      );

      if (newCurrentIndex < 0) {
        newCurrentIndex = currentIndex.clamp(
          0,
          math.max(0, newItems.length - 1),
        );
      }

      final changed = newItems.length != viewerItems.length;

      setState(() {
        viewerItems = newItems;

        currentIndex = newCurrentIndex;

        hasMoreOlder = result.hasMoreOlder;

        loadingOlderPhotos = false;
      });

      // ========================================
      // GIU NGUYEN DUNG ANH USER DANG XEM
      // SAU KHI PREPEND ANH CU.
      // ========================================

      if (changed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !pageController.hasClients) {
            return;
          }

          pageController.jumpToPage(newCurrentIndex);
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingOlderPhotos = false;
      });

      debugPrint(
        'PHOTO VIEWER LOAD OLDER ERROR: '
        '$error',
      );
    }
  }

  void _toggleControls() {
    if (draggingToDismiss) {
      return;
    }

    setState(() {
      controlsVisible = !controlsVisible;
    });
  }

  void _handleDismissDragStart(DragStartDetails details) {
    if (currentPageZoomed) {
      return;
    }

    controlsVisibleBeforeDrag = controlsVisible;

    setState(() {
      draggingToDismiss = true;

      // Khi bắt đầu kéo ảnh xuống,
      // ẩn controls cho giống photo viewer.
      controlsVisible = false;
    });
  }

  void _handleDismissDragUpdate(DragUpdateDetails details) {
    if (currentPageZoomed || !draggingToDismiss) {
      return;
    }

    // ========================================
    // CHI CHO PHEP KEO XUONG
    //
    // Neu user keo nguoc len trong luc dang
    // keo xuong thi offset se giam dan ve 0.
    // ========================================

    final next = math.max(0.0, dismissOffsetY + details.delta.dy);

    setState(() {
      dismissOffsetY = next;
    });
  }

  void _handleDismissDragEnd(DragEndDetails details) {
    if (currentPageZoomed || !draggingToDismiss) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0.0;

    // ========================================
    // DONG VIEWER NEU:
    //
    // - keo xuong >= 120px
    // HOAC
    // - vuot nhanh xuong
    // ========================================

    final shouldDismiss = dismissOffsetY >= 120 || velocity > 900;

    if (shouldDismiss) {
      Navigator.of(context).pop();

      return;
    }

    // ========================================
    // KHONG DU XA
    // -> TRA ANH VE GIUA
    // ========================================

    setState(() {
      draggingToDismiss = false;

      dismissOffsetY = 0.0;

      controlsVisible = controlsVisibleBeforeDrag;
    });
  }

  void _handleDismissDragCancel() {
    if (!draggingToDismiss) {
      return;
    }

    setState(() {
      draggingToDismiss = false;

      dismissOffsetY = 0.0;

      controlsVisible = controlsVisibleBeforeDrag;
    });
  }

  // ========================================
  // ZOOM STATE
  // ========================================

  void _handleZoomChanged(int pageIndex, bool zoomed) {
    if (pageIndex != currentIndex) {
      return;
    }

    if (currentPageZoomed == zoomed) {
      return;
    }

    setState(() {
      currentPageZoomed = zoomed;
    });
  }

  // ========================================
  // PAGE CHANGED
  // ========================================

  void _handlePageChanged(int index) {
    setState(() {
      currentIndex = index;

      currentPageZoomed = false;
    });

    // ========================================
    // CON 1 ANH NUA LA DEN DAU HISTORY
    // -> PREFETCH THEM.
    // ========================================

    if (index <= 1) {
      _loadOlderIfNeeded();
    }
  }

  @override
  void dispose() {
    pageController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (viewerItems.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,

        body: Center(
          child: Text('Không có ảnh', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final dismissProgress = (dismissOffsetY / 300).clamp(0.0, 1.0).toDouble();

    final backgroundOpacity = (1.0 - dismissProgress * 0.70)
        .clamp(0.0, 1.0)
        .toDouble();

    return Scaffold(
      backgroundColor: Color.fromRGBO(0, 0, 0, backgroundOpacity),

      body: SafeArea(
        child: Stack(
          children: [
            // ========================================
            // PHOTO PAGES
            // ========================================

            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,

                // ========================================
                // CHI BAT SWIPE DOWN KHI ANH DANG 1X
                //
                // Neu dang zoom:
                // InteractiveViewer se xu ly pan.
                // ========================================
                onVerticalDragStart: currentPageZoomed
                    ? null
                    : _handleDismissDragStart,

                onVerticalDragUpdate: currentPageZoomed
                    ? null
                    : _handleDismissDragUpdate,

                onVerticalDragEnd: currentPageZoomed
                    ? null
                    : _handleDismissDragEnd,

                onVerticalDragCancel: currentPageZoomed
                    ? null
                    : _handleDismissDragCancel,

                child: AnimatedContainer(
                  duration: draggingToDismiss
                      ? Duration.zero
                      : const Duration(milliseconds: 180),

                  curve: Curves.easeOutCubic,

                  // ========================================
                  // ANH DI THEO NGON TAY
                  // ========================================
                  transform: Matrix4.translationValues(
                    0.0,
                    dismissOffsetY,
                    0.0,
                  ),

                  child: NotificationListener<OverscrollNotification>(
                    onNotification: (notification) {
                      if (!currentPageZoomed &&
                          currentIndex == 0 &&
                          notification.overscroll < 0) {
                        _loadOlderIfNeeded();
                      }

                      return false;
                    },

                    child: PageView.builder(
                      controller: pageController,

                      physics: currentPageZoomed
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),

                      itemCount: viewerItems.length,

                      onPageChanged: _handlePageChanged,

                      itemBuilder: (context, index) {
                        return _PhotoViewerSlide(
                          item: viewerItems[index],

                          heroEnabled: index == currentIndex,

                          onTap: _toggleControls,

                          onZoomChanged: (zoomed) {
                            _handleZoomChanged(index, zoomed);
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
              top: 8,

              left: 8,

              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),

                opacity: controlsVisible && !draggingToDismiss ? 1.0 : 0.0,

                child: IgnorePointer(
                  ignoring: !controlsVisible || draggingToDismiss,

                  child: Material(
                    color: const Color(0x66000000),

                    shape: const CircleBorder(),

                    child: IconButton(
                      tooltip: 'Quay lại',

                      onPressed: () {
                        Navigator.of(context).pop();
                      },

                      icon: const Icon(
                        Icons.arrow_back_rounded,

                        color: Colors.white,

                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ========================================
            // LOADING HISTORY
            // ========================================
            if (loadingOlderPhotos && !draggingToDismiss)
              const Positioned(
                left: 18,

                top: 0,

                bottom: 0,

                child: Center(
                  child: SizedBox(
                    width: 22,

                    height: 22,

                    child: CircularProgressIndicator(
                      strokeWidth: 2,

                      color: Colors.white70,
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

class _PhotoViewerSlide extends StatefulWidget {
  final PhotoViewerItem item;

  final bool heroEnabled;

  final ValueChanged<bool> onZoomChanged;

  final VoidCallback onTap;

  const _PhotoViewerSlide({
    required this.item,
    required this.heroEnabled,
    required this.onZoomChanged,
    required this.onTap,
  });

  @override
  State<_PhotoViewerSlide> createState() => _PhotoViewerSlideState();
}

class _PhotoViewerSlideState extends State<_PhotoViewerSlide>
    with SingleTickerProviderStateMixin {
  final TransformationController transformationController =
      TransformationController();

  late final AnimationController animationController;

  Animation<Matrix4>? zoomAnimation;

  Offset doubleTapPosition = Offset.zero;

  bool zoomed = false;

  static const double doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 220),
    );

    animationController.addListener(_handleZoomAnimation);

    transformationController.addListener(_handleTransformationChanged);
  }

  // ========================================
  // CHECK DANG ZOOM HAY KHONG
  // ========================================

  void _handleTransformationChanged() {
    final scale = transformationController.value.getMaxScaleOnAxis();

    final nextZoomed = scale > 1.01;

    if (nextZoomed == zoomed) {
      return;
    }

    zoomed = nextZoomed;

    if (mounted) {
      setState(() {
        // Update panEnabled.
      });
    }

    widget.onZoomChanged(nextZoomed);
  }

  // ========================================
  // ANIMATION
  // ========================================

  void _handleZoomAnimation() {
    final animation = zoomAnimation;

    if (animation == null) {
      return;
    }

    transformationController.value = animation.value;
  }

  void _animateTransformation(Matrix4 target) {
    animationController.stop();

    zoomAnimation =
        Matrix4Tween(
          begin: Matrix4.copy(transformationController.value),

          end: target,
        ).animate(
          CurvedAnimation(
            parent: animationController,

            curve: Curves.easeOutCubic,
          ),
        );

    animationController.forward(from: 0);
  }

  // ========================================
  // DOUBLE TAP POSITION
  // ========================================

  void _handleDoubleTapDown(TapDownDetails details) {
    doubleTapPosition = details.localPosition;
  }

  // ========================================
  // DOUBLE TAP
  //
  // 1X -> 2.5X
  // >1X -> 1X
  // ========================================

  void _handleDoubleTap() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();

    if (currentScale > 1.05) {
      _animateTransformation(Matrix4.identity());

      return;
    }

    final x = -doubleTapPosition.dx * (doubleTapScale - 1);

    final y = -doubleTapPosition.dy * (doubleTapScale - 1);

    final target = Matrix4.identity()
      ..translateByDouble(x, y, 0.0, 1.0)
      ..scaleByDouble(doubleTapScale, doubleTapScale, doubleTapScale, 1.0);

    _animateTransformation(target);
  }

  @override
  void dispose() {
    transformationController.removeListener(_handleTransformationChanged);

    animationController.removeListener(_handleZoomAnimation);

    animationController.dispose();

    transformationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      // ========================================
      // SINGLE TAP
      // -> an / hien controls
      // ========================================
      onTap: widget.onTap,

      onDoubleTapDown: _handleDoubleTapDown,

      onDoubleTap: _handleDoubleTap,

      child: InteractiveViewer(
        transformationController: transformationController,

        minScale: 1.0,

        maxScale: 5.0,

        // ========================================
        // CHI PAN KHI DANG ZOOM.
        //
        // KHI 1X:
        // VUOT NGANG DUOC NHUONG CHO PAGEVIEW.
        // ========================================
        panEnabled: zoomed,

        scaleEnabled: true,

        boundaryMargin: const EdgeInsets.all(100),

        clipBehavior: Clip.none,

        onInteractionStart: (details) {
          if (animationController.isAnimating) {
            animationController.stop();
          }
        },

        child: Center(
          child: HeroMode(
            enabled: widget.heroEnabled,

            child: Hero(
              tag: widget.item.heroTag,

              child: Image.network(
                widget.item.url,

                fit: BoxFit.contain,

                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return const SizedBox(
                    width: 42,

                    height: 42,

                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,

                      color: Colors.white,
                    ),
                  );
                },

                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Icon(
                        Icons.broken_image_outlined,

                        size: 48,

                        color: Colors.white70,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Không thể tải ảnh',

                        style: TextStyle(color: Colors.white70, fontSize: 14),
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
