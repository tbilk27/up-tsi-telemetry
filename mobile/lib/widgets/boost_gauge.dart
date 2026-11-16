import 'dart:math';
import 'package:flutter/material.dart';

class BoostGauge extends StatelessWidget {
  final double boostBar;
  final double boostPsi;
  final double peakBoostBar;
  final double dynamicPeakBar;
  final double size;
  final VoidCallback? onDoubleTap;
  final bool isShiftPoint;

  const BoostGauge({
    Key? key,
    required this.boostBar,
    required this.boostPsi,
    required this.peakBoostBar,
    this.dynamicPeakBar = 0.0,
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
              painter: _BoostPainter(
                boostBar: boostBar,
                peakBoostBar: peakBoostBar,
                dynamicPeakBar: dynamicPeakBar,
                isShiftPoint: isShiftPoint,
              ),
            ),
            Positioned(
              bottom: size * 0.20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${boostBar >= 0 ? '+' : ''}${boostBar.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: (size * 0.12).clamp(20.0, 52.0),
                      fontWeight: FontWeight.w900,
                      color: isShiftPoint ? Colors.black : Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${boostPsi.toStringAsFixed(1)} PSI',
                    style: TextStyle(
                      fontSize: (size * 0.045).clamp(9.0, 18.0),
                      fontWeight: FontWeight.w700,
                      color: isShiftPoint ? const Color(0xFF1E283B) : const Color(0xFF00A8FF),
                      letterSpacing: 1.0,
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

class _BoostPainter extends CustomPainter {
  final double boostBar;
  final double peakBoostBar;
  final double dynamicPeakBar;
  final bool isShiftPoint;

  _BoostPainter({
    required this.boostBar,
    required this.peakBoostBar,
    required this.dynamicPeakBar,
    required this.isShiftPoint,
  });

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

    // Vacuum Zone (-1.0 to 0.0 bar) is 1/3 of the 3.0 bar range
    const zeroAngle = startAngle + (1.0 / 3.0) * totalSweep;
    final vacuumPaint = Paint()
      ..color = const Color(0xFF00A8FF).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackStroke;

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

    // Ticks & Labels: -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final tickOffset1 = 14.0 * scale;
    final tickOffset2 = 22.0 * scale;
    final tickOffsetZero = 26.0 * scale;
    final textOffset = 38.0 * scale;

    const ticks = [-1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 2.0];
    for (final val in ticks) {
      final pos = (val + 1.0) / 3.0;
      final angle = startAngle + pos * totalSweep;
      final isZero = val == 0.0;
      final isHigh = val >= 1.5;

      final p1 = Offset(
        center.dx + (radius - tickOffset1) * cos(angle),
        center.dy + (radius - tickOffset1) * sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - (isZero ? tickOffsetZero : tickOffset2)) * cos(angle),
        center.dy + (radius - (isZero ? tickOffsetZero : tickOffset2)) * sin(angle),
      );

      final tickPaint = Paint()
        ..color = isZero
            ? const Color(0xFF00E676)
            : (isHigh ? const Color(0xFFFF5252) : const Color(0xFF7387A8))
        ..strokeWidth = (isZero ? 3.0 : 2.0) * scale;

      canvas.drawLine(p1, p2, tickPaint);

      // Labels
      final tx = center.dx + (radius - textOffset) * cos(angle);
      final ty = center.dy + (radius - textOffset) * sin(angle);

      textPainter.text = TextSpan(
        text: val.toStringAsFixed(1),
        style: TextStyle(
          fontSize: ((isZero ? 12.0 : 10.0) * scale).clamp(8.5, 20.0),
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

    // Dynamic Peak Red Line (Linha vermelha que acompanha o ponteiro e segura o pico por até 2 min)
    final effectivePeakBar = max(boostBar, dynamicPeakBar);
    final dynamicPeakPos = ((effectivePeakBar.clamp(-1.0, 2.0) + 1.0) / 3.0).clamp(0.0, 1.0);
    final dynamicPeakAngle = startAngle + dynamicPeakPos * totalSweep;

    // Linha vermelha que acompanha o ponteiro e para no pico
    final redNeedlePaint = Paint()
      ..color = const Color(0xFFFF1744) // Vermelho vivo esportivo
      ..strokeWidth = (3.2 * scale).clamp(2.2, 5.5)
      ..strokeCap = StrokeCap.round;

    final redNeedleStart = Offset(
      center.dx + (radius * 0.35) * cos(dynamicPeakAngle),
      center.dy + (radius * 0.35) * sin(dynamicPeakAngle),
    );
    final redNeedleTip = Offset(
      center.dx + (radius - 10 * scale) * cos(dynamicPeakAngle),
      center.dy + (radius - 10 * scale) * sin(dynamicPeakAngle),
    );
    canvas.drawLine(redNeedleStart, redNeedleTip, redNeedlePaint);

    // Marcador vermelho no aro da escala
    final redMarkerPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..strokeWidth = (4.0 * scale).clamp(3.0, 7.0)
      ..strokeCap = StrokeCap.round;

    final rm1 = Offset(
      center.dx + (radius - 2 * scale) * cos(dynamicPeakAngle),
      center.dy + (radius - 2 * scale) * sin(dynamicPeakAngle),
    );
    final rm2 = Offset(
      center.dx + (radius + 9 * scale) * cos(dynamicPeakAngle),
      center.dy + (radius + 9 * scale) * sin(dynamicPeakAngle),
    );
    canvas.drawLine(rm1, rm2, redMarkerPaint);

    // Absolute Session Peak Marker (Amarelo, discreto)
    if (peakBoostBar > 0) {
      final absPeakPos = ((peakBoostBar.clamp(-1.0, 2.0) + 1.0) / 3.0).clamp(0.0, 1.0);
      final absPeakAngle = startAngle + absPeakPos * totalSweep;

      final px1 = Offset(
        center.dx + (radius + 2 * scale) * cos(absPeakAngle),
        center.dy + (radius + 2 * scale) * sin(absPeakAngle),
      );
      final px2 = Offset(
        center.dx + (radius + 8 * scale) * cos(absPeakAngle),
        center.dy + (radius + 8 * scale) * sin(absPeakAngle),
      );

      canvas.drawLine(
        px1,
        px2,
        Paint()
          ..color = const Color(0xFFFFD600).withValues(alpha: 0.7)
          ..strokeWidth = (2.5 * scale).clamp(2.0, 5.0),
      );
    }

    // Live Pointer Needle (Azul)
    final needleAngle = startAngle + boostPos * totalSweep;
    final needlePaint = Paint()
      ..color = const Color(0xFF00A8FF)
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
        ..color = const Color(0xFF00A8FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.5 * scale).clamp(1.8, 4.5),
    );
    canvas.drawCircle(center, (4.0 * scale).clamp(2.5, 7.0), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BoostPainter oldDelegate) {
    return oldDelegate.boostBar != boostBar ||
        oldDelegate.peakBoostBar != peakBoostBar ||
        oldDelegate.dynamicPeakBar != dynamicPeakBar ||
        oldDelegate.isShiftPoint != isShiftPoint;
  }
}
