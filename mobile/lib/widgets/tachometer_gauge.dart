import 'dart:math';
import 'package:flutter/material.dart';

class TachometerGauge extends StatelessWidget {
  final int rpm;
  final double size;

  const TachometerGauge({
    Key? key,
    required this.rpm,
    this.size = 260,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _TachometerPainter(rpm: rpm),
          ),
          Positioned(
            bottom: size * 0.22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rpm.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'RPM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B9BB4),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TachometerPainter extends CustomPainter {
  final int rpm;

  _TachometerPainter({required this.rpm});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    const startAngle = 135 * (pi / 180);
    const endAngle = 405 * (pi / 180);
    const totalSweep = endAngle - startAngle;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFF182133)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
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
      ..color = const Color(0xFFE51A24).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
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
        ..strokeWidth = 12
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

    for (int i = 0; i <= 7; i++) {
      final angle = startAngle + (i / 7) * totalSweep;
      final isRedline = i >= 6;

      final p1 = Offset(
        center.dx + (radius - 14) * cos(angle),
        center.dy + (radius - 14) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 24) * cos(angle),
        center.dy + (radius - 24) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = isRedline ? const Color(0xFFFF5252) : const Color(0xFF7387A8)
        ..strokeWidth = 2.5;

      canvas.drawLine(p1, p2, tickPaint);

      // Minor ticks
      if (i < 7) {
        for (int m = 1; m < 5; m++) {
          final minorAngle = angle + (m / 5) * (totalSweep / 7);
          final mp1 = Offset(
            center.dx + (radius - 14) * cos(minorAngle),
            center.dy + (radius - 14) * sin(minorAngle),
          );
          final mp2 = Offset(
            center.dx + (radius - 19) * cos(minorAngle),
            center.dy + (radius - 19) * sin(minorAngle),
          );

          final minorPaint = Paint()
            ..color = const Color(0xFF344563)
            ..strokeWidth = 1.2;

          canvas.drawLine(mp1, mp2, minorPaint);
        }
      }

      // Numbers
      final tx = center.dx + (radius - 38) * cos(angle);
      final ty = center.dy + (radius - 38) * sin(angle);

      textPainter.text = TextSpan(
        text: i.toString(),
        style: TextStyle(
          fontSize: 12,
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
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final needleTip = Offset(
      center.dx + (radius - 16) * cos(needleAngle),
      center.dy + (radius - 16) * sin(needleAngle),
    );

    canvas.drawLine(center, needleTip, needlePaint);

    // Center cap
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFF0A0E17));
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = const Color(0xFFE51A24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TachometerPainter oldDelegate) {
    return oldDelegate.rpm != rpm;
  }
}
