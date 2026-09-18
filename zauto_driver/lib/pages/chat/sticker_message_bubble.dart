import 'package:flutter/material.dart';

class StickerMessageBubble extends StatelessWidget {
  final String? stickerUrl;

  const StickerMessageBubble({super.key, required this.stickerUrl});

  @override
  Widget build(BuildContext context) {
    // ========================================
    // KHONG CO URL
    // ========================================

    if (stickerUrl == null || stickerUrl!.trim().isEmpty) {
      return const SizedBox(
        width: 130,

        height: 130,

        child: Center(
          child: Icon(
            Icons.emoji_emotions_outlined,

            size: 42,

            color: Color(0xFF87939D),
          ),
        ),
      );
    }

    // ========================================
    // STICKER
    // ========================================

    return SizedBox(
      width: 130,

      height: 130,

      child: Image.network(
        stickerUrl!,

        fit: BoxFit.contain,

        gaplessPlayback: true,

        // ========================================
        // LOADING
        // ========================================
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }

          return const Center(
            child: SizedBox(
              width: 24,

              height: 24,

              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },

        // ========================================
        // ERROR
        // ========================================
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image_outlined,

              size: 36,

              color: Color(0xFF87939D),
            ),
          );
        },
      ),
    );
  }
}
