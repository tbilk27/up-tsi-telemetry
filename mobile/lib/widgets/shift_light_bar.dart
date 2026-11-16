import 'package:flutter/material.dart';

class ShiftLightBar extends StatelessWidget {
  final int rpm;
  final int shiftRpm;

  const ShiftLightBar({
    Key? key,
    required this.rpm,
    this.shiftRpm = 5200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 8 LEDs com escala adaptativa calculada a partir de shiftRpm
    final target = shiftRpm;
    final thresholds = [
      target - 1500, // LED 1 (Verde)
      target - 1200, // LED 2 (Verde)
      target - 900,  // LED 3 (Amarelo)
      target - 650,  // LED 4 (Amarelo)
      target - 400,  // LED 5 (Laranja/Vermelho)
      target - 200,  // LED 6 (Vermelho)
      target - 100,  // LED 7 (Ciano)
      target,        // LED 8 (Flash / Shift Up!)
    ];
    final isFlashing = rpm >= target;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D121C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(8, (index) {
          final active = rpm >= thresholds[index];
          Color ledColor;

          if (index < 2) {
            ledColor = active ? const Color(0xFF00E676) : const Color(0xFF1E283B);
          } else if (index < 4) {
            ledColor = active ? const Color(0xFFFFD600) : const Color(0xFF1E283B);
          } else if (index < 6) {
            ledColor = active ? const Color(0xFFFF3D00) : const Color(0xFF1E283B);
          } else {
            ledColor = active ? const Color(0xFF00E5FF) : const Color(0xFF1E283B);
          }

          if (isFlashing && active) {
            ledColor = const Color(0xFF00E5FF);
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 16,
            height: 7,
            decoration: BoxDecoration(
              color: ledColor,
              borderRadius: BorderRadius.circular(3),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.8),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
