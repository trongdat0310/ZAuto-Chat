import 'package:flutter/material.dart';

import 'voice_waveform_painter.dart';

class VoiceMessageBubble extends StatelessWidget {
  final List<dynamic> samples;

  final Duration duration;

  final double progress;

  final bool isPlaying;

  final VoidCallback onToggle;

  final String? transcript;

  final String? transcriptionStatus;

  const VoiceMessageBubble({
    super.key,
    required this.samples,
    required this.duration,
    required this.progress,
    required this.isPlaying,
    required this.onToggle,
    this.transcript,
    this.transcriptionStatus,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(1, '0');

    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 300),

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisSize: MainAxisSize.min,

            children: [
          // ========================================
          // PLAY / PAUSE
          // ========================================

          IconButton(
            padding: EdgeInsets.zero,

            constraints: const BoxConstraints(minWidth: 42, minHeight: 42),

            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,

              size: 30,

              color: colorScheme.primary,
            ),

            onPressed: onToggle,
          ),

          const SizedBox(width: 7),

          // ========================================
          // WAVEFORM
          // ========================================
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                SizedBox(
                  height: 32,

                  width: double.infinity,

                  child: samples.isEmpty
                      ? LinearProgressIndicator(value: progress)
                      : CustomPaint(
                          painter: VoiceWaveformPainter(
                            samples: samples,

                            progress: progress,

                            activeColor: colorScheme.primary,

                            inactiveColor: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                ),

                const SizedBox(height: 2),

                Text(
                  _formatDuration(duration),

                  style: TextStyle(
                    fontSize: 11,

                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
            ],
          ),

          if (
            transcript != null &&
            transcript!.trim().isNotEmpty
          ) ...[
            const SizedBox(height: 8),

            Divider(
              height: 1,
              color: colorScheme.outlineVariant,
            ),

            const SizedBox(height: 8),

            Text(
              transcript!.trim(),

              style: TextStyle(
                fontSize: 13,

                height: 1.35,

                color: colorScheme.onSurface,
              ),
            ),
          ] else if (
            transcriptionStatus ==
            'processing'
          ) ...[
            const SizedBox(height: 6),

            Text(
              'Đang phiên âm…',

              style: TextStyle(
                fontSize: 12,

                fontStyle: FontStyle.italic,

                color:
                    colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
