import 'dart:math';
import 'package:flutter/material.dart';

class BoostGauge extends StatelessWidget {
  final double boostBar;
  final double boostPsi;
  final double peakBoostBar;
  final double size;

  const BoostGauge({
    Key? key,
    required this.boostBar,
    required this.boostPsi,
    required this.peakBoostBar,
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
            painter: _BoostPainter(
              boostBar: boostBar,
              peakBoostBar: peakBoostBar,
            ),
          ),
          Positioned(
            bottom: size * 0.22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${boostBar >= 0 ? '+' : ''}${boostBar.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${boostPsi.toStringAsFixed(1)} PSI',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00A8FF),
                    letterSpacing: 1.0,
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

class _BoostPainter extends CustomPainter {
  final double boostBar;
  final double peakBoostBar;

  _BoostPainter({
    required this.boostBar,
    required this.peakBoostBar,
  });

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

    // Vacuum Zone (-1.0 to 0.0 bar) is 1/3 of the 3.0 bar range
    const zeroAngle = startAngle + (1.0 / 3.0) * totalSweep;
    final vacuumPaint = Paint()
      ..color = const Color(0xFF00A8FF).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      zeroAngle - startAngle,
      false,
      vacuumPaint,
    );

    // Active sweep arc
    final clampedBoost = boostBar.clamp(-1.0, 2.0);
    final boostPos = (clampedBoost + 1.0) / 3.0;
    final activeSweep = boostPos * totalSweep;

    if (activeSweep > 0) {
      final activePaint = Paint()
        ..shader = const SweepGradient(
          startAngle: startAngle,
          endAngle: endAngle,
          colors: [
            Color(0xFF00A8FF),
            Color(0xFF00E676),
            Color(0xFFFF9100),
            Color(0xFFFF1744),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
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

    // Ticks & Labels: -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    const ticks = [-1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0];
    for (final val in ticks) {
      final pos = (val + 1.0) / 3.0;
      final angle = startAngle + pos * totalSweep;
      final isZero = val == 0.0;
      final isHigh = val >= 1.5;

      final p1 = Offset(
        center.dx + (radius - 14) * cos(angle),
        center.dy + (radius - 14) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - (isZero ? 26 : 22)) * cos(angle),
        center.dy + (radius - (isZero ? 26 : 22)) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = isZero
            ? const Color(0xFF00E676)
            : (isHigh ? const Color(0xFFFF5252) : const Color(0xFF7387A8))
        ..strokeWidth = isZero ? 3.0 : 2.0;

      canvas.drawLine(p1, p2, tickPaint);

      // Labels
      final tx = center.dx + (radius - 38) * cos(angle);
      final ty = center.dy + (radius - 38) * sin(angle);

      textPainter.text = TextSpan(
        text: val.toStringAsFixed(1),
        style: TextStyle(
          fontSize: isZero ? 12 : 10,
          fontWeight: isZero ? FontWeight.bold : FontWeight.normal,
          color: isZero
              ? const Color(0xFF00E676)
              : (isHigh ? const Color(0xFFFF5252) : const Color(0xFF9CB1D4)),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(tx - textPainter.width / 2, ty - textPainter.height / 2),
      );
    }

    // Peak Marker
    if (peakBoostBar > 0) {
      final peakPos = ((peakBoostBar + 1.0) / 3.0).clamp(0.0, 1.0);
      final peakAngle = startAngle + peakPos * totalSweep;

      final px1 = Offset(
        center.dx + (radius + 2) * cos(peakAngle),
        center.dy + (radius + 2) * sin(peakAngle),
      );
      final px2 = Offset(
        center.dx + (radius + 10) * cos(peakAngle),
        center.dy + (radius + 10) * sin(peakAngle),
      );

      canvas.drawLine(
        px1,
        px2,
        Paint()
          ..color = const Color(0xFFFFD600)
          ..strokeWidth = 3.5,
      );
    }

    // Needle
    final needleAngle = startAngle + boostPos * totalSweep;
    final needlePaint = Paint()
      ..color = const Color(0xFF00A8FF)
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
        ..color = const Color(0xFF00A8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BoostPainter oldDelegate) {
    return oldDelegate.boostBar != boostBar ||
        oldDelegate.peakBoostBar != peakBoostBar;
  }
}
