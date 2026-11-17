import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';

class HealthDiagnosticsView extends StatefulWidget {
  final bool isLandscape;
  final List<Map<String, dynamic>> liveAlerts;
  final VoidCallback? onScanDtc;
  final VoidCallback? onClearDtc;

  const HealthDiagnosticsView({
    Key? key,
    this.isLandscape = false,
    this.liveAlerts = const [],
    this.onScanDtc,
    this.onClearDtc,
  }) : super(key: key);

  @override
  State<HealthDiagnosticsView> createState() => _HealthDiagnosticsViewState();
}

class _HealthDiagnosticsViewState extends State<HealthDiagnosticsView> {
  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final data = obd.data;

    return Container(
      color: const Color(0xFF0A0D14),
      child: widget.isLandscape
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
          // 1. Monitor Individual dos Cilindros & Falhas de Ignição (Misfire Counter)
          _buildCylinderMisfireCard(context, obd, data),

          const SizedBox(height: 12),

          // 2. Monitor de Batida de Pino / Recuo de Ponto (Knock Retard)
          _buildKnockMonitorCard(context, data),

          const SizedBox(height: 12),

          // 3. Scanner de Códigos de Falha da Injeção (DTCs)
          _buildDtcScannerCard(context, obd, data),

          const SizedBox(height: 12),

          // 4. Alertas dos Sensores em Tempo Real
          _buildLiveSensorAlertsCard(context, widget.liveAlerts),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, ObdBluetoothService obd, dynamic data) {
    return Row(
      children: [
        // Lado Esquerdo: Cilindros e Knock
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildCylinderMisfireCard(context, obd, data, compact: true),
                const SizedBox(height: 8),
                _buildKnockMonitorCard(context, data),
              ],
            ),
          ),
        ),

        // Lado Direito: Scanner DTC e Alertas
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildDtcScannerCard(context, obd, data),
                const SizedBox(height: 8),
                _buildLiveSensorAlertsCard(context, widget.liveAlerts),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Monitor de Cilindros e Falhas de Ignição (Misfire Counters)
  Widget _buildCylinderMisfireCard(BuildContext context, ObdBluetoothService obd, dynamic data, {bool compact = false}) {
    final bool isThreeCyl = obd.vehicleProfile.contains('1.0 TSI');
    final int cylCount = isThreeCyl ? 3 : 4;

    final misfires = [
      data.misfiresCyl1 as int,
      data.misfiresCyl2 as int,
      data.misfiresCyl3 as int,
      if (!isThreeCyl) data.misfiresCyl4 as int,
    ];

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
                children: [
                  const Icon(Icons.flash_on, color: Color(0xFF00A8FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'MONITOR DE CILINDROS ($cylCount CILINDROS)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => obd.clearMisfires(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E283B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Zerar', style: TextStyle(fontSize: 10, color: Color(0xFF8B9BB4))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Monitora falhas de queima/faísca por cilindro em tempo real para detectar velas ou bobinas gastas.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF8B9BB4)),
          ),
          const SizedBox(height: 12),

          // Cards de cada cilindro
          Row(
            children: List.generate(cylCount, (index) {
              final cylNumber = index + 1;
              final count = misfires[index];
              final bool hasFault = count > 0;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < cylCount - 1 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: hasFault ? const Color(0xFF2D1418) : const Color(0xFF121722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasFault ? const Color(0xFFFF5252) : const Color(0xFF242E42),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'CIL $cylNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: hasFault ? const Color(0xFFFF5252) : const Color(0xFF8B9BB4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        hasFault ? Icons.warning : Icons.check_circle,
                        size: 18,
                        color: hasFault ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasFault ? '$count falhas' : '0 falhas',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasFault ? const Color(0xFFFF5252) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Monitor de Batida de Pino / Recuo de Ponto (Knock Retard)
  Widget _buildKnockMonitorCard(BuildContext context, dynamic data) {
    final double knock = data.knockRetard;
    final bool hasKnock = knock > 0.5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasKnock ? const Color(0xFFFFD600) : const Color(0xFF202B3D),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.hearing,
                color: hasKnock ? const Color(0xFFFFD600) : const Color(0xFF00E676),
                size: 24,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECUO DE PONTO (KNOCK RETARD)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasKnock ? 'ECU recuando avanço (Combustível ruim)' : 'Avanço de ignição ótimo (Sem detonação)',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: hasKnock ? const Color(0xFFFFD600) : const Color(0xFF8B9BB4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: hasKnock ? const Color(0xFF2B200C) : const Color(0xFF14241B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hasKnock ? const Color(0xFFFFD600) : const Color(0xFF00E676)),
            ),
            child: Text(
              '${knock.toStringAsFixed(1)}°',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: hasKnock ? const Color(0xFFFFD600) : const Color(0xFF00E676),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Scanner de Falhas da Injeção (DTCs)
  Widget _buildDtcScannerCard(BuildContext context, ObdBluetoothService obd, dynamic data) {
    final dtcs = data.dtcs as List<String>;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dtcs.isNotEmpty ? const Color(0xFFE51A24) : const Color(0xFF202B3D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFE51A24), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'MEMÓRIA DE FALHAS (DTC)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: widget.onScanDtc,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E283B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Escanear', style: TextStyle(fontSize: 11)),
                  ),
                  if (dtcs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: widget.onClearDtc,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE51A24),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Limpar', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (dtcs.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1E16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zero falhas registradas na ECU do veículo.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF88D8B0)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...dtcs.map((code) {
              final desc = ObdBluetoothService.tsiDtcDatabase[code] ?? 'Falha específica VAG / Fabricante';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF281014),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE51A24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE51A24),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        desc,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFFFCDD2)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // Alertas dos Sensores em Tempo Real
  Widget _buildLiveSensorAlertsCard(BuildContext context, List<Map<String, dynamic>> alerts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, color: Color(0xFF00E676), size: 18),
              SizedBox(width: 8),
              Text(
                'MONITORAMENTO DE SENSORES EM TEMPO REAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1E16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arrefecimento, IAT, Fuel Trims e Tensão dentro da faixa ideal.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF88D8B0)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...alerts.map((alert) {
              final isCritical = alert['severity'] == 'critical';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFF2D1012) : const Color(0xFF281E0C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isCritical ? const Color(0xFFE51A24) : const Color(0xFFFFD600),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      alert['icon'] as IconData,
                      color: isCritical ? const Color(0xFFFF4D58) : const Color(0xFFFFD600),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert['title'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCritical ? const Color(0xFFFF6B72) : const Color(0xFFFFE57F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert['desc'],
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFFC0CDE0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
