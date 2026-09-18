import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoViewerPage extends StatefulWidget {
  final String videoUrl;

  const VideoViewerPage({super.key, required this.videoUrl});

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late final VideoPlayerController controller;

  bool initialized = false;

  bool failed = false;

  bool controlsVisible = true;

  Timer? hideControlsTimer;

  @override
  void initState() {
    super.initState();

    controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

    controller.addListener(_handleVideoChanged);

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await controller.initialize();

      if (!mounted) {
        return;
      }

      await controller.setLooping(false);

      setState(() {
        initialized = true;
      });

      await controller.play();

      _scheduleHideControls();
    } catch (error) {
      debugPrint('VIDEO INIT ERROR: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        failed = true;
      });
    }
  }

  void _handleVideoChanged() {
    if (!mounted) {
      return;
    }

    if (!initialized) {
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
    hideControlsTimer?.cancel();

    if (!controller.value.isPlaying) {
      return;
    }

    hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      setState(() {
        controlsVisible = false;
      });
    });
  }

  void _toggleControls() {
    setState(() {
      controlsVisible = !controlsVisible;
    });

    if (controlsVisible) {
      _scheduleHideControls();
    }
  }

  Future<void> _togglePlay() async {
    if (!initialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      hideControlsTimer?.cancel();

      if (mounted) {
        setState(() {
          controlsVisible = true;
        });
      }
    } else {
      await controller.play();

      if (mounted) {
        setState(() {
          controlsVisible = true;
        });
      }

      _scheduleHideControls();
    }
  }

  String _formatVideoTime(Duration duration) {
    final totalSeconds = duration.inSeconds;

    final hours = totalSeconds ~/ 3600;

    final minutes = (totalSeconds % 3600) ~/ 60;

    final seconds = totalSeconds % 60;

    final minuteText = minutes.toString().padLeft(2, '0');

    final secondText = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minuteText:$secondText';
    }

    return '$minuteText:$secondText';
  }

  Future<void> _seekTo(double value) async {
    if (!initialized) {
      return;
    }

    final duration = controller.value.duration;

    if (duration.inMilliseconds <= 0) {
      return;
    }

    final targetMs = (duration.inMilliseconds * value).round();

    await controller.seekTo(Duration(milliseconds: targetMs));

    _scheduleHideControls();
  }

  @override
  void dispose() {
    hideControlsTimer?.cancel();

    controller.removeListener(_handleVideoChanged);

    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: failed
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.error_outline_rounded,

                      color: Colors.white70,

                      size: 48,
                    ),

                    SizedBox(height: 12),

                    Text(
                      'Không thể phát video',

                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            : !initialized
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,

                onTap: _toggleControls,

                child: Stack(
                  children: [
                    // ========================================
                    // VIDEO
                    // ========================================

                    Positioned.fill(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio > 0
                              ? controller.value.aspectRatio
                              : 16 / 9,

                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),

                    // ========================================
                    // CONTROLS OVERLAY
                    // ========================================
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),

                        opacity: controlsVisible ? 1 : 0,

                        child: IgnorePointer(
                          ignoring: !controlsVisible,

                          child: Stack(
                            children: [
                              // ========================================
                              // DARK OVERLAY
                              // ========================================

                              const Positioned.fill(
                                child: ColoredBox(color: Color(0x33000000)),
                              ),

                              // ========================================
                              // BACK
                              // ========================================
                              Positioned(
                                top: 8,

                                left: 8,

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

                              // ========================================
                              // PLAY / PAUSE
                              // ========================================
                              Center(
                                child: Material(
                                  color: const Color(0xAA000000),

                                  shape: const CircleBorder(),

                                  child: InkWell(
                                    customBorder: const CircleBorder(),

                                    onTap: _togglePlay,

                                    child: SizedBox(
                                      width: 72,

                                      height: 72,

                                      child: Icon(
                                        controller.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,

                                        size: 46,

                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ========================================
                              // BOTTOM CONTROLS
                              // ========================================
                              Positioned(
                                left: 14,

                                right: 14,

                                bottom: 14,

                                child: _buildVideoBottomControls(),
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
    final position = controller.value.position;

    final duration = controller.value.duration;

    final durationMs = duration.inMilliseconds;

    final positionMs = position.inMilliseconds;

    final progress = durationMs > 0
        ? (positionMs / durationMs).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),

      decoration: BoxDecoration(
        color: const Color(0x99000000),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          // ========================================
          // SEEK BAR
          // ========================================

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,

              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),

              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),

            child: Slider(
              value: progress,

              min: 0,

              max: 1,

              onChanged: (value) {
                _seekTo(value);
              },
            ),
          ),

          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,

                padding: EdgeInsets.zero,

                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),

                onPressed: _togglePlay,

                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,

                  color: Colors.white,

                  size: 24,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                '${_formatVideoTime(position)} / '
                '${_formatVideoTime(duration)}',

                style: const TextStyle(
                  color: Colors.white,

                  fontSize: 12,

                  fontWeight: FontWeight.w500,
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
