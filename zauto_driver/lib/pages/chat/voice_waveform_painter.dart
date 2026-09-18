import 'package:flutter/material.dart';

class VoiceWaveformPainter extends CustomPainter {
  final List<dynamic> samples;

  final double progress;

  final Color activeColor;

  final Color inactiveColor;

  VoiceWaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) {
      return;
    }

    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final count = samples.length;

    final spacing = size.width / count;

    for (int i = 0; i < count; i++) {
      final value = samples[i] is num ? (samples[i] as num).toDouble() : 0.0;

      final normalized = (value / 5000).clamp(0.12, 1.0);

      final barHeight = size.height * normalized;

      final x = spacing * i + spacing / 2;

      final centerY = size.height / 2;

      paint.color = (i / count) <= progress ? activeColor : inactiveColor;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.samples != samples ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
