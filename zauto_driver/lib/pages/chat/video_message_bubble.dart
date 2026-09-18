import 'dart:math' as math;

import 'package:flutter/material.dart';

class VideoMessageBubble extends StatelessWidget {
  final String? thumbnailUrl;

  final double? mediaWidth;

  final double? mediaHeight;

  final VoidCallback onTap;

  const VideoMessageBubble({
    super.key,
    required this.thumbnailUrl,
    required this.mediaWidth,
    required this.mediaHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const maxWidth = 280.0;

    const maxHeight = 390.0;

    double displayWidth = 260;

    double displayHeight = 200;

    // ========================================
    // GIU TY LE VIDEO
    // ========================================

    if (mediaWidth != null &&
        mediaHeight != null &&
        mediaWidth! > 0 &&
        mediaHeight! > 0) {
      final scale = math.min(maxWidth / mediaWidth!, maxHeight / mediaHeight!);

      displayWidth = mediaWidth! * scale;

      displayHeight = mediaHeight! * scale;
    }

    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(12),

        onTap: onTap,

        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),

          child: SizedBox(
            width: displayWidth,

            height: displayHeight,

            child: Stack(
              fit: StackFit.expand,

              children: [
                // ========================================
                // THUMBNAIL
                // ========================================

                if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
                  Image.network(
                    thumbnailUrl!,

                    fit: BoxFit.cover,

                    errorBuilder: (context, error, stackTrace) {
                      return const _VideoFallback();
                    },
                  )
                else
                  const _VideoFallback(),

                // ========================================
                // DARK OVERLAY
                // ========================================
                const ColoredBox(color: Color(0x22000000)),

                // ========================================
                // PLAY BUTTON
                // ========================================
                const Center(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xCC000000),

                        shape: BoxShape.circle,
                      ),

                      child: Padding(
                        padding: EdgeInsets.all(12),

                        child: Icon(
                          Icons.play_arrow_rounded,

                          size: 36,

                          color: Colors.white,
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
}

// ========================================
// VIDEO FALLBACK
// ========================================

class _VideoFallback extends StatelessWidget {
  const _VideoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE0E5E9),

      alignment: Alignment.center,

      child: const Icon(Icons.videocam_outlined, size: 46),
    );
  }
}
