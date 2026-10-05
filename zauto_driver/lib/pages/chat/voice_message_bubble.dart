import 'package:flutter/material.dart';

import 'voice_waveform_painter.dart';

class VoiceMessageBubble extends StatefulWidget {
  final List<dynamic> samples;

  final Duration duration;

  final double progress;

  final bool isPlaying;

  final VoidCallback onToggle;

  final String? transcript;

  final String? transcriptionStatus;

  final Future<void> Function()? onTranscribe;

  const VoiceMessageBubble({
    super.key,
    required this.samples,
    required this.duration,
    required this.progress,
    required this.isPlaying,
    required this.onToggle,
    this.transcript,
    this.transcriptionStatus,
    this.onTranscribe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _expanded = true;

  bool _requesting = false;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(1, '0');

    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  bool get _hasTranscript {
    return widget.transcript != null && widget.transcript!.trim().isNotEmpty;
  }

  bool get _isProcessing {
    return _requesting || widget.transcriptionStatus == 'processing';
  }

  Future<void> _handleTranscriptButton() async {
    if (_hasTranscript) {
      setState(() {
        // Neu dang mo thi thu gon.
        // Neu da thu gon thi icon phien am se mo lai
        // transcript da co, khong goi Whisper lan nua.
        _expanded = !_expanded;
      });

      return;
    }

    if (_isProcessing || widget.onTranscribe == null) {
      return;
    }

    setState(() {
      _requesting = true;
    });

    try {
      await widget.onTranscribe!();
    } finally {
      if (mounted) {
        setState(() {
          _requesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 330),

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
            children: [
              IconButton(
                padding: EdgeInsets.zero,

                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),

                icon: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,

                  size: 30,

                  color: colorScheme.primary,
                ),

                onPressed: widget.onToggle,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    SizedBox(
                      height: 32,

                      width: double.infinity,

                      child: widget.samples.isEmpty
                          ? LinearProgressIndicator(value: widget.progress)
                          : CustomPaint(
                              painter: VoiceWaveformPainter(
                                samples: widget.samples,

                                progress: widget.progress,

                                activeColor: colorScheme.primary,

                                inactiveColor: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _formatDuration(widget.duration),

                      style: TextStyle(
                        fontSize: 11,

                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: 44,
                height: 44,

                child: Material(
                  color: colorScheme.surfaceContainerHigh,

                  borderRadius: BorderRadius.circular(12),

                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),

                    onTap: _isProcessing && !_hasTranscript
                        ? null
                        : _handleTranscriptButton,

                    child: Center(
                      child: _isProcessing && !_hasTranscript
                          ? SizedBox(
                              width: 19,
                              height: 19,

                              child: CircularProgressIndicator(
                                strokeWidth: 2,

                                color: colorScheme.primary,
                              ),
                            )
                          : Icon(
                              _hasTranscript && _expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.translate_rounded,

                              size: 24,

                              color: _hasTranscript || widget.onTranscribe != null
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.35,
                                    ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_hasTranscript && _expanded) ...[
            const SizedBox(height: 8),

            Divider(
              height: 1,

              color: colorScheme.outlineVariant,
            ),

            const SizedBox(height: 8),

            Text(
              widget.transcript!.trim(),

              style: TextStyle(
                fontSize: 13,

                height: 1.35,

                color: colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
