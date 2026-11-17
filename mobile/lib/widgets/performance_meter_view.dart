import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/performance_meter_service.dart';
import '../services/obd_bluetooth_service.dart';

class PerformanceMeterView extends StatefulWidget {
  final bool isLandscape;

  const PerformanceMeterView({
    Key? key,
    this.isLandscape = false,
  }) : super(key: key);

  @override
  State<PerformanceMeterView> createState() => _PerformanceMeterViewState();
}

class _PerformanceMeterViewState extends State<PerformanceMeterView> {
  @override
  Widget build(BuildContext context) {
    final meter = Provider.of<PerformanceMeterService>(context);
    final obd = Provider.of<ObdBluetoothService>(context, listen: false);

    return Container(
      color: const Color(0xFF0A0D14),
      child: widget.isLandscape
          ? _buildLandscapeLayout(meter, obd)
          : _buildPortraitLayout(meter, obd),
    );
  }

  Widget _buildPortraitLayout(PerformanceMeterService meter, ObdBluetoothService obd) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Selector de Faixas de Prova
          _buildPresetSelector(meter),

          const SizedBox(height: 12),

          // 2. Painel Central da Prova (Cronômetro + Status + Progresso)
          _buildMainTimerCard(meter),

          const SizedBox(height: 12),

          // 3. Telemetria da Puxada (Velocidade, Boost, RPM, G-Force, Distância)
          _buildTelemetryStrip(meter, obd),

          const SizedBox(height: 12),

          // 4. Parciais e Splits
          if (meter.currentSplits.isNotEmpty || meter.state == PerformanceState.finished)
            _buildSplitsCard(meter),

          const SizedBox(height: 12),

          // 5. Botões de Ação (Armar/Desarmar, Simular)
          _buildActionButtons(meter),

          const SizedBox(height: 16),

          // 6. Histórico de Puxadas & Recordes
          _buildHistorySection(meter),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(PerformanceMeterService meter, ObdBluetoothService obd) {
    return Row(
      children: [
        // Lado Esquerdo: Cronômetro e Status Principal
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildPresetSelector(meter, compact: true),
                const SizedBox(height: 8),
                _buildMainTimerCard(meter, isLandscape: true),
                const SizedBox(height: 8),
                _buildActionButtons(meter, compact: true),
              ],
            ),
          ),
        ),

        // Lado Direito: Telemetria, Parciais e Histórico
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildTelemetryStrip(meter, obd),
                const SizedBox(height: 8),
                if (meter.currentSplits.isNotEmpty || meter.state == PerformanceState.finished) ...[
                  _buildSplitsCard(meter),
                  const SizedBox(height: 8),
                ],
                _buildHistorySection(meter),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Seletor horizontal de provas
  Widget _buildPresetSelector(PerformanceMeterService meter, {bool compact = false}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: PerformanceMeterService.defaultPresets.map((preset) {
          final isSelected = meter.selectedPreset.id == preset.id;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                if (preset.id == 'custom') {
                  _showCustomRangeDialog(meter);
                } else {
                  meter.selectPreset(preset);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE51A24) : const Color(0xFF121722),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF5252) : const Color(0xFF242E42),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      preset.isFromZero ? Icons.timer : Icons.speed,
                      size: compact ? 12 : 14,
                      color: isSelected ? Colors.white : const Color(0xFF8B9BB4),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      preset.label,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF8B9BB4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Card do Cronômetro Principal
  Widget _buildMainTimerCard(PerformanceMeterService meter, {bool isLandscape = false}) {
    final statusColor = _getStatusColor(meter.state);
    final statusText = _getStatusText(meter.state, meter);

    return Container(
      padding: EdgeInsets.all(isLandscape ? 12 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: meter.state == PerformanceState.running
              ? const Color(0xFF00E676)
              : (meter.state == PerformanceState.armed
                  ? const Color(0xFFFFD600)
                  : const Color(0xFF202B3D)),
          width: 1.8,
        ),
        boxShadow: [
          if (meter.state == PerformanceState.running)
            BoxShadow(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          if (meter.state == PerformanceState.armed)
            BoxShadow(
              color: const Color(0xFFFFD600).withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        children: [
          // Banner de Status da Prova
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _getStatusIcon(meter.state, statusColor),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: isLandscape ? 11 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isLandscape ? 6 : 12),

          // Mostrador Digital do Cronômetro
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                meter.currentElapsedSeconds.toStringAsFixed(2),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: isLandscape ? 52 : 72,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: meter.state == PerformanceState.finished
                      ? const Color(0xFF00E676)
                      : (meter.state == PerformanceState.running
                          ? const Color(0xFFFFEA00)
                          : Colors.white),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                's',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: isLandscape ? 22 : 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF8B9BB4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            meter.activeLabel.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8,
              color: Color(0xFF8B9BB4),
            ),
          ),

          SizedBox(height: isLandscape ? 8 : 14),

          // Barra de Progresso de Velocidade
          Consumer<ObdBluetoothService>(
            builder: (context, obd, child) {
              final currentSpeed = obd.data.speed.toDouble();
              final vStart = meter.activeVStart.toDouble();
              final vEnd = meter.activeVEnd.toDouble();
              final span = max(1.0, vEnd - vStart);
              final progress = ((currentSpeed - vStart) / span).clamp(0.0, 1.0);

              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: isLandscape ? 6 : 8,
                      backgroundColor: const Color(0xFF1E283B),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        meter.state == PerformanceState.running
                            ? const Color(0xFF00E676)
                            : const Color(0xFFE51A24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${meter.activeVStart} km/h',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF677B99)),
                      ),
                      Text(
                        'ATUAL: ${currentSpeed.round()} KM/H',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC0CDE0),
                        ),
                      ),
                      Text(
                        '${meter.activeVEnd} km/h',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF677B99)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Faixa de Telemetria instantânea da puxada
  Widget _buildTelemetryStrip(PerformanceMeterService meter, ObdBluetoothService obd) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTelemetryMetric(
            label: 'PICO TURBO',
            value: '${meter.peakBoost >= 0 ? "+" : ""}${meter.peakBoost.toStringAsFixed(2)}b',
            color: const Color(0xFFFF9100),
          ),
          _buildVerticalDivider(),
          _buildTelemetryMetric(
            label: 'MAX RPM',
            value: '${meter.peakRpm}',
            color: const Color(0xFFFFEA00),
          ),
          _buildVerticalDivider(),
          _buildTelemetryMetric(
            label: 'ACELERAÇÃO',
            value: '${meter.peakGForce.toStringAsFixed(2)} G',
            color: const Color(0xFF00E676),
          ),
          _buildVerticalDivider(),
          _buildTelemetryMetric(
            label: 'DISTÂNCIA',
            value: '${meter.distanceMeters.toStringAsFixed(0)} m',
            color: const Color(0xFF40C4FF),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Color(0xFF7387A8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 26, color: const Color(0xFF202B3D));
  }

  // Parciais (Splits)
  Widget _buildSplitsCard(PerformanceMeterService meter) {
    return Container(
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
              Icon(Icons.flag_outlined, size: 14, color: Color(0xFF00E676)),
              SizedBox(width: 6),
              Text(
                'PARCIAIS (SPLITS):',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF8B9BB4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: meter.currentSplits.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF242E42)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B9BB4)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.value.toStringAsFixed(2)}s',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Botões de Ação
  Widget _buildActionButtons(PerformanceMeterService meter, {bool compact = false}) {
    final isArmed = meter.state == PerformanceState.armed || meter.state == PerformanceState.waitingToArm;

    return Row(
      children: [
        // Botão Armar / Desarmar
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isArmed ? const Color(0xFF451E20) : const Color(0xFFE51A24),
              foregroundColor: isArmed ? const Color(0xFFFF5252) : Colors.white,
              padding: EdgeInsets.symmetric(vertical: compact ? 10 : 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isArmed ? const Color(0xFFFF5252) : Colors.transparent,
                  width: 1.2,
                ),
              ),
            ),
            icon: Icon(isArmed ? Icons.stop_circle_outlined : Icons.play_arrow_rounded, size: 20),
            label: Text(
              isArmed ? 'DESARMAR' : 'ARMAR PROVA',
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
            onPressed: () {
              if (isArmed) {
                meter.disarm();
              } else {
                meter.arm();
              }
            },
          ),
        ),

        const SizedBox(width: 8),

        // Botão Simular Puxada VW TSI (Demo bancada)
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00E676),
              side: const BorderSide(color: Color(0xFF00E676), width: 1.2),
              padding: EdgeInsets.symmetric(vertical: compact ? 10 : 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.flash_on, size: 16),
            label: Text(
              compact ? 'SIMULAR' : 'SIMULAR PUXADA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            onPressed: () => meter.simulateRun(),
          ),
        ),
      ],
    );
  }

  // Histórico de Resultados
  Widget _buildHistorySection(PerformanceMeterService meter) {
    final runs = meter.history;
    final bestRun = meter.bestRunForCurrentPreset;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: Color(0xFFE51A24), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'HISTÓRICO DE MEDIÇÕES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  if (runs.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E283B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${runs.length}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8B9BB4)),
                      ),
                    ),
                  ],
                ],
              ),
              if (runs.isNotEmpty)
                TextButton(
                  onPressed: () => meter.clearHistory(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFFFF5252),
                  ),
                  child: const Text('Limpar', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),

          // Badge de Melhor Tempo (Recorde Pessoal)
          if (bestRun != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MELHOR TEMPO (${bestRun.presetLabel}):',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Color(0xFF88D8B0),
                          ),
                        ),
                        Text(
                          '${bestRun.elapsedSeconds.toStringAsFixed(2)}s  •  Pico: +${bestRun.peakBoostBar.toStringAsFixed(2)}b  •  ${bestRun.peakRpm} RPM',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          if (runs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Nenhuma prova registrada ainda.\nArme a prova e acelere!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF677B99)),
              ),
            )
          else
            ...runs.take(5).map((run) {
              final isBest = bestRun != null && run.id == bestRun.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF121722),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBest ? const Color(0xFFFFD700).withValues(alpha: 0.6) : const Color(0xFF202A3D),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isBest) ...[
                              const Icon(Icons.star, size: 13, color: Color(0xFFFFD700)),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              run.presetLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Turbo: +${run.peakBoostBar.toStringAsFixed(2)}b • ${run.peakGForce.toStringAsFixed(2)}G • ${run.peakRpm} RPM',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF8B9BB4),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${run.elapsedSeconds.toStringAsFixed(2)}s',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isBest ? const Color(0xFFFFD700) : const Color(0xFF00E676),
                          ),
                        ),
                        Text(
                          _formatTime(run.timestamp),
                          style: const TextStyle(fontSize: 9, color: Color(0xFF677B99)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // Dialog para faixa customizada
  void _showCustomRangeDialog(PerformanceMeterService meter) {
    int startVal = meter.activeVStart;
    int endVal = meter.activeVEnd;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E131D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF202B3D)),
              ),
              title: const Text(
                'Faixa Personalizada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$startVal km/h  até  $endVal km/h',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Início: ', style: TextStyle(fontSize: 12, color: Color(0xFF8B9BB4))),
                      Expanded(
                        child: Slider(
                          value: startVal.toDouble(),
                          min: 0,
                          max: 180,
                          divisions: 18,
                          label: '$startVal km/h',
                          onChanged: (val) {
                            setDialogState(() {
                              startVal = val.round();
                              if (startVal >= endVal) endVal = startVal + 20;
                            });
                          },
                        ),
                      ),
                      Text('$startVal', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Fim:    ', style: TextStyle(fontSize: 12, color: Color(0xFF8B9BB4))),
                      Expanded(
                        child: Slider(
                          value: endVal.toDouble().clamp(startVal + 10, 250),
                          min: 20,
                          max: 250,
                          divisions: 23,
                          label: '$endVal km/h',
                          onChanged: (val) {
                            setDialogState(() {
                              endVal = val.round();
                              if (endVal <= startVal) startVal = max(0, endVal - 20);
                            });
                          },
                        ),
                      ),
                      Text('$endVal', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8B9BB4))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE51A24)),
                  onPressed: () {
                    meter.setCustomRange(startVal, endVal);
                    Navigator.pop(context);
                  },
                  child: const Text('Salvar & Armar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(PerformanceState state) {
    switch (state) {
      case PerformanceState.disarmed:
        return const Color(0xFF8B9BB4);
      case PerformanceState.waitingToArm:
        return const Color(0xFFFF9100);
      case PerformanceState.armed:
        return const Color(0xFFFFD600);
      case PerformanceState.running:
        return const Color(0xFF00E676);
      case PerformanceState.finished:
        return const Color(0xFF00E676);
      case PerformanceState.aborted:
        return const Color(0xFFFF5252);
    }
  }

  String _getStatusText(PerformanceState state, PerformanceMeterService meter) {
    switch (state) {
      case PerformanceState.disarmed:
        return 'DESARMADO';
      case PerformanceState.waitingToArm:
        return meter.activeVStart == 0
            ? 'PARE O CARRO (0 KM/H) PARA ARMAR'
            : 'REDUZA ABAIXO DE ${meter.activeVStart} KM/H';
      case PerformanceState.armed:
        return meter.activeVStart == 0
            ? 'ARMADO • ACELERE PARA LARGADA!'
            : 'ARMADO • ACELERE E CRUZE ${meter.activeVStart} KM/H!';
      case PerformanceState.running:
        return '🚀 ACELERANDO • PÉ NO FUNDO!';
      case PerformanceState.finished:
        return '🏁 PROVA CONCLUÍDA!';
      case PerformanceState.aborted:
        return 'PROVA ABORTADA';
    }
  }

  Widget _getStatusIcon(PerformanceState state, Color color) {
    switch (state) {
      case PerformanceState.disarmed:
        return Icon(Icons.pause_circle_outline, size: 14, color: color);
      case PerformanceState.waitingToArm:
        return Icon(Icons.hourglass_empty, size: 14, color: color);
      case PerformanceState.armed:
        return Icon(Icons.flash_on, size: 14, color: color);
      case PerformanceState.running:
        return Icon(Icons.speed, size: 14, color: color);
      case PerformanceState.finished:
        return Icon(Icons.check_circle_outline, size: 14, color: color);
      case PerformanceState.aborted:
        return Icon(Icons.cancel_outlined, size: 14, color: color);
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
