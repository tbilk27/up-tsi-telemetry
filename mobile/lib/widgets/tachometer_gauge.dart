import 'dart:math';
import 'package:flutter/material.dart';

class TachometerGauge extends StatelessWidget {
  final int rpm;
  final double size;
  final VoidCallback? onDoubleTap;
  final bool isShiftPoint;

  const TachometerGauge({
    Key? key,
    required this.rpm,
    this.size = 260,
    this.onDoubleTap,
    this.isShiftPoint = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _TachometerPainter(
                rpm: rpm,
                isShiftPoint: isShiftPoint,
              ),
            ),
            Positioned(
              bottom: size * 0.20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rpm.toString(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: (size * 0.13).clamp(20.0, 56.0),
                      fontWeight: FontWeight.w900,
                      color: isShiftPoint ? Colors.black : Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'RPM',
                    style: TextStyle(
                      fontSize: (size * 0.05).clamp(9.0, 18.0),
                      fontWeight: FontWeight.w700,
                      color: isShiftPoint ? const Color(0xFF1E283B) : const Color(0xFF8B9BB4),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TachometerPainter extends CustomPainter {
  final int rpm;
  final bool isShiftPoint;

  _TachometerPainter({required this.rpm, this.isShiftPoint = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    final scale = size.width / 220.0;
    final trackStroke = (12.0 * scale).clamp(8.0, 22.0);

    const startAngle = 135 * (pi / 180);
    const endAngle = 405 * (pi / 180);
    const totalSweep = endAngle - startAngle;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFF182133)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    // Redline arc (6000 to 7000 RPM)
    final redlineStart = startAngle + (6000 / 7000) * totalSweep;
    final redlinePaint = Paint()
      ..color = const Color(0xFFE51A24).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      redlineStart,
      endAngle - redlineStart,
      false,
      redlinePaint,
    );

    // Active RPM Sweep Arc
    final clampedRpm = rpm.clamp(0, 7000);
    final activeSweep = (clampedRpm / 7000) * totalSweep;

    if (activeSweep > 0) {
      final activePaint = Paint()
        ..shader = const SweepGradient(
          startAngle: startAngle,
          endAngle: endAngle,
          colors: [
            Color(0xFF00E676),
            Color(0xFFFFD600),
            Color(0xFFE51A24),
          ],
          stops: [0.0, 0.65, 0.9],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackStroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }

    // Ticks & Numbers (0 to 7)
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final tickOffset1 = 14.0 * scale;
    final tickOffset2 = 24.0 * scale;
    final tickOffsetMinor = 19.0 * scale;
    final textOffset = 38.0 * scale;

    for (int i = 0; i <= 7; i++) {
      final angle = startAngle + (i / 7) * totalSweep;
      final isRedline = i >= 6;

      final p1 = Offset(
        center.dx + (radius - tickOffset1) * cos(angle),
        center.dy + (radius - tickOffset1) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - tickOffset2) * cos(angle),
        center.dy + (radius - tickOffset2) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = isRedline ? const Color(0xFFFF5252) : const Color(0xFF7387A8)
        ..strokeWidth = (2.5 * scale).clamp(1.5, 4.0);

      canvas.drawLine(p1, p2, tickPaint);

      // Minor ticks
      if (i < 7) {
        for (int m = 1; m < 5; m++) {
          final minorAngle = angle + (m / 5) * (totalSweep / 7);
          final mp1 = Offset(
            center.dx + (radius - tickOffset1) * cos(minorAngle),
            center.dy + (radius - tickOffset1) * sin(minorAngle),
          );
          final mp2 = Offset(
            center.dx + (radius - tickOffsetMinor) * cos(minorAngle),
            center.dy + (radius - tickOffsetMinor) * sin(minorAngle),
          );

          final minorPaint = Paint()
            ..color = const Color(0xFF344563)
            ..strokeWidth = (1.2 * scale).clamp(1.0, 2.5);

          canvas.drawLine(mp1, mp2, minorPaint);
        }
      }

      // Numbers
      final tx = center.dx + (radius - textOffset) * cos(angle);
      final ty = center.dy + (radius - textOffset) * sin(angle);

      textPainter.text = TextSpan(
        text: i.toString(),
        style: TextStyle(
          fontSize: (12.0 * scale).clamp(9.0, 22.0),
          fontWeight: FontWeight.bold,
          color: isRedline ? const Color(0xFFFF5252) : const Color(0xFFA0B3D1),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(tx - textPainter.width / 2, ty - textPainter.height / 2),
      );
    }

    // Needle
    final needleAngle = startAngle + (clampedRpm / 7000) * totalSweep;
    final needlePaint = Paint()
      ..color = const Color(0xFFE51A24)
      ..strokeWidth = (3.5 * scale).clamp(2.5, 6.0)
      ..strokeCap = StrokeCap.round;

    final needleTip = Offset(
      center.dx + (radius - 16 * scale) * cos(needleAngle),
      center.dy + (radius - 16 * scale) * sin(needleAngle),
    );

    canvas.drawLine(center, needleTip, needlePaint);

    // Center cap
    final capRadius = (10.0 * scale).clamp(7.0, 18.0);
    canvas.drawCircle(center, capRadius, Paint()..color = const Color(0xFF0A0E17));
    canvas.drawCircle(
      center,
      capRadius,
      Paint()
        ..color = const Color(0xFFE51A24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.5 * scale).clamp(1.8, 4.5),
    );
    canvas.drawCircle(center, (4.0 * scale).clamp(2.5, 7.0), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TachometerPainter oldDelegate) {
    return oldDelegate.rpm != rpm || oldDelegate.isShiftPoint != isShiftPoint;
  }
}
