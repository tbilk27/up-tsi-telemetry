import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';

class DynoPowerView extends StatelessWidget {
  final bool isLandscape;

  const DynoPowerView({
    Key? key,
    this.isLandscape = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final data = obd.data;

    return Container(
      color: const Color(0xFF0A0D14),
      child: isLandscape
          ? _buildLandscapeLayout(context, obd, data)
          : _buildPortraitLayout(context, obd, data),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, ObdBluetoothService obd, dynamic data) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Dinamômetro Virtual: Potência (CV) e Torque (kgfm)
          _buildDynoPowerCards(context, obd, data),

          const SizedBox(height: 12),

          // 2. Injeção Direta TSI (Pressão no Rail) & Mistura Lambda/AFR
          _buildFuelAndLambdaSection(context, data),

          const SizedBox(height: 12),

          // 3. Temperaturas Térmicas Críticas (Óleo do Motor & EGT Gases de Escape)
          _buildThermalSection(context, data),

          const SizedBox(height: 12),

          // 4. G-Force Meter 2D (Círculo de Aderência e Dinâmica)
          _buildGMeterCard(context, data),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, ObdBluetoothService obd, dynamic data) {
    return Row(
      children: [
        // Lado Esquerdo: Dinamômetro (Potência e Torque)
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildDynoPowerCards(context, obd, data, compact: true),
                const SizedBox(height: 8),
                _buildFuelAndLambdaSection(context, data, compact: true),
              ],
            ),
          ),
        ),

        // Lado Direito: Térmico e G-Meter
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildThermalSection(context, data),
                const SizedBox(height: 8),
                _buildGMeterCard(context, data, compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Cards de Potência (CV) e Torque (kgfm)
  Widget _buildDynoPowerCards(BuildContext context, ObdBluetoothService obd, dynamic data, {bool compact = false}) {
    final double maxHpScale = obd.vehicleProfile.contains('2.0 TSI')
        ? 260.0
        : (obd.vehicleProfile.contains('1.4 TSI') ? 180.0 : 140.0);
    final double maxTorqueScale = maxHpScale * 0.22; // ~30.8 para 140 CV (~22 kgfm)

    final double hpRatio = (data.estimatedHp / maxHpScale).clamp(0.0, 1.0);
    final double torqueRatio = (data.estimatedTorqueKgfm / maxTorqueScale).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.electric_bolt, color: Color(0xFFFFEA00), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'DINAMÔMETRO EM TEMPO REAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => obd.resetPowerPeaks(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162030),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF243248)),
                  ),
                  child: const Text(
                    'Zerar Picos',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8B9BB4)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Medidor de Potência
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        data.estimatedHp.toStringAsFixed(0),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFEA00),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'CV',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8B9BB4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${(data.estimatedHp * 0.7355).toStringAsFixed(0)} kW)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF677B99),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'PICO: ${data.peakHp.toStringAsFixed(0)} CV',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9100),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: hpRatio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF1B2332),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFEA00)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Medidor de Torque
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        data.estimatedTorqueKgfm.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E676),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'kgfm',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8B9BB4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${data.estimatedTorqueNm.toStringAsFixed(0)} Nm)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFF677B99),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'PICO: ${data.peakTorqueKgfm.toStringAsFixed(1)} kgfm',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E676),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: torqueRatio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF1B2332),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Injeção Direta (Rail) & Sonda Lambda
  Widget _buildFuelAndLambdaSection(BuildContext context, dynamic data, {bool compact = false}) {
    final double railPressure = data.fuelRailPressureBar;
    final double lambda = data.lambda;
    final double afr = data.afr;

    // Status da mistura
    final bool isRich = lambda < 0.90;
    final bool isLean = lambda > 1.05;
    final Color mixColor = isRich
        ? const Color(0xFFFF9100) // Laranja / Rica (potência)
        : (isLean ? const Color(0xFFFF5252) : const Color(0xFF00E676)); // Verde (estequiométrica)
    final String mixLabel = isRich ? 'RICA (WOT)' : (isLean ? 'POBRE (CUT-OFF)' : 'ESTEQUIOMÉTRICA');

    return Row(
      children: [
        // Card: Pressão de Combustível de Injeção Direta (Rail HPFP)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF202B3D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.local_gas_station, size: 14, color: Color(0xFF00A8FF)),
                    SizedBox(width: 6),
                    Text(
                      'RAIL INJEÇÃO (HPFP)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF8B9BB4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      railPressure.toStringAsFixed(0),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'bar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00A8FF)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (railPressure / 200.0).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1B2332),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A8FF)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '40 - 200 bar (Alta Linha)',
                  style: const TextStyle(fontSize: 9, color: Color(0xFF677B99)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Card: Sonda Lambda & AFR
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF202B3D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.air, size: 14, color: Color(0xFF00E676)),
                    SizedBox(width: 6),
                    Text(
                      'MISTURA (SONDA λ)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF8B9BB4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      lambda.toStringAsFixed(2),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: mixColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'λ',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8B9BB4)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${afr.toStringAsFixed(1)}:1',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF677B99)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ((lambda - 0.75) / 0.60).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1B2332),
                    valueColor: AlwaysStoppedAnimation<Color>(mixColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mixLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: mixColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Seção Térmica (Temperatura do Óleo & EGT)
  Widget _buildThermalSection(BuildContext context, dynamic data) {
    final int oilTemp = data.oilTemperature;
    final int egt = data.egt;

    final bool oilWarning = oilTemp > 115;
    final bool egtWarning = egt > 900;

    return Row(
      children: [
        // Temperatura do Óleo
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: oilWarning ? const Color(0xFFFF5252) : const Color(0xFF202B3D),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.oil_barrel,
                  color: oilWarning ? const Color(0xFFFF5252) : const Color(0xFFFF9100),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ÓLEO DO MOTOR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF8B9BB4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$oilTemp',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: oilWarning ? const Color(0xFFFF5252) : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text('°C', style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4))),
                        ],
                      ),
                      Text(
                        oilTemp < 85 ? 'Aquecendo' : (oilWarning ? 'Atenção Térmica!' : 'Ideal (85-110°C)'),
                        style: TextStyle(
                          fontSize: 8.5,
                          color: oilWarning ? const Color(0xFFFF5252) : const Color(0xFF677B99),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Gases de Escape (EGT)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: egtWarning ? const Color(0xFFFF5252) : const Color(0xFF202B3D),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.whatshot,
                  color: egtWarning ? const Color(0xFFFF5252) : const Color(0xFFFF3D00),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESCAPE (EGT TURBO)',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Color(0xFF8B9BB4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$egt',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: egtWarning ? const Color(0xFFFF5252) : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Text('°C', style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4))),
                        ],
                      ),
                      Text(
                        egtWarning ? 'Proteção Térmica' : 'Caracol Turbina',
                        style: TextStyle(
                          fontSize: 8.5,
                          color: egtWarning ? const Color(0xFFFF5252) : const Color(0xFF677B99),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // G-Force Meter 2D (Círculo de Aderência)
  Widget _buildGMeterCard(BuildContext context, dynamic data, {bool compact = false}) {
    final double gLong = data.longitudinalGForce;
    final double gLat = data.lateralGForce;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.radar, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'G-METER (DINÂMICA DE ADERÊNCIA)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                'Long: ${gLong >= 0 ? "+" : ""}${gLong.toStringAsFixed(2)}G  •  Lat: ${gLat >= 0 ? "+" : ""}${gLat.toStringAsFixed(2)}G',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visualizador circular de G-Force
          Center(
            child: SizedBox(
              width: compact ? 120 : 150,
              height: compact ? 120 : 150,
              child: CustomPaint(
                painter: _GMeterPainter(
                  gLong: gLong,
                  gLat: gLat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GMeterPainter extends CustomPainter {
  final double gLong;
  final double gLat;

  _GMeterPainter({required this.gLong, required this.gLat});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = const Color(0xFF202B3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Círculos concêntricos: 0.5G e 1.0G
    canvas.drawCircle(center, radius * 0.5, circlePaint);
    canvas.drawCircle(center, radius * 0.95, circlePaint);

    // Eixos X e Y
    final axisPaint = Paint()
      ..color = const Color(0xFF1B2332)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);

    // Ponto móvel de G-Force
    final dotX = (center.dx + (gLat * radius * 0.8)).clamp(5.0, size.width - 5.0);
    // gLong positivo é aceleração (pra cima), negativo frenagem (pra baixo)
    final dotY = (center.dy - (gLong * radius * 0.8)).clamp(5.0, size.height - 5.0);

    final dotPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.fill;

    final dotGlowPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), 10, dotGlowPaint);
    canvas.drawCircle(Offset(dotX, dotY), 4.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GMeterPainter oldDelegate) {
    return oldDelegate.gLong != gLong || oldDelegate.gLat != gLat;
  }
}
