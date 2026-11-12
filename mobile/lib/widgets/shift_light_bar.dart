import 'package:flutter/material.dart';

class ShiftLightBar extends StatelessWidget {
  final int rpm;

  const ShiftLightBar({Key? key, required this.rpm}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 8 LEDs thresholds: 3800, 4400 (Green), 4900, 5300 (Yellow), 5600, 5800 (Red), 6000, 6200 (Shift Flash)
    final thresholds = [3800, 4400, 4900, 5300, 5600, 5800, 6000, 6200];
    final isFlashing = rpm >= 5900;

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
                        color: ledColor.withOpacity(0.8),
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
