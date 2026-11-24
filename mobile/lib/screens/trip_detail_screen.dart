import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/trip_log_record.dart';
import '../services/trip_logger_service.dart';

class TripDetailScreen extends StatefulWidget {
  final TripLogRecord trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<TripTelemetrySample> _samples = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    final logger = Provider.of<TripLoggerService>(context, listen: false);
    final loaded = await logger.loadTripSamples(widget.trip.id);
    if (mounted) {
      setState(() {
        _samples = loaded;
        _isLoading = false;
        _selectedIndex = loaded.isNotEmpty ? (loaded.length - 1) : 0;
      });
    }
  }

  Future<void> _exportCsv() async {
    final logger = Provider.of<TripLoggerService>(context, listen: false);
    final csv = await logger.buildCsvContent(widget.trip.id);
    final filePath = await logger.exportTripCsvFile(widget.trip.id);
    await Clipboard.setData(ClipboardData(text: csv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00E676),
          duration: const Duration(seconds: 4),
          content: Text(
            filePath != null
                ? 'CSV copiado para a área de transferência e salvo em:\n$filePath'
                : 'CSV completo copiado para a área de transferência!',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final dateStr =
        '${t.startTime.day.toString().padLeft(2, '0')}/${t.startTime.month.toString().padLeft(2, '0')}/${t.startTime.year} '
        '${t.startTime.hour.toString().padLeft(2, '0')}:${t.startTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101522),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DATALOGGER DE VIAGEM',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
            Text(
              '$dateStr • ${t.vehicleProfile}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF8B9BB4)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.download, color: Color(0xFF00E676)),
            onPressed: _samples.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A8FF)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Resumo de Picos e Médias da Viagem
                  _buildSummaryGrid(t),

                  const SizedBox(height: 14),

                  // 2. Gráfico Interativo Multi-Canal (RPM, Velocidade, Boost, Potência)
                  if (_samples.isNotEmpty) ...[
                    _buildInteractiveChartCard(),
                    const SizedBox(height: 14),

                    // 3. Inspetor Completo de Todos os Sensores no Instante Selecionado
                    _buildSampleInspectorCard(_samples[_selectedIndex]),
                    const SizedBox(height: 14),

                    // 4. Tabela / Log das Amostras Gravadas
                    _buildSamplesLogList(),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E131D),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF202B3D)),
                      ),
                      child: const Text(
                        'Nenhuma amostra detalhada encontrada para esta viagem.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryGrid(TripLogRecord t) {
    final items = [
      {'label': 'DISTÂNCIA', 'val': '${t.distanceKm.toStringAsFixed(1)} km', 'color': const Color(0xFF00A8FF)},
      {'label': 'DURAÇÃO', 'val': '${t.durationMinutes.toStringAsFixed(1)} min', 'color': const Color(0xFFFFD600)},
      {'label': 'CONSUMO MÉDIO', 'val': '${t.avgConsumptionKml.toStringAsFixed(1)} km/L', 'color': const Color(0xFF00E676)},
      {'label': 'VEL. MÁXIMA', 'val': '${t.maxSpeedKmh} km/h', 'color': const Color(0xFF00E5FF)},
      {'label': 'RPM MÁXIMO', 'val': '${t.maxRpm}', 'color': const Color(0xFFFF5252)},
      {'label': 'TURBO MÁX', 'val': '${t.maxBoostBar.toStringAsFixed(2)} bar', 'color': const Color(0xFFFF9100)},
      {'label': 'POTÊNCIA MÁX', 'val': '${t.maxHp.toStringAsFixed(0)} CV', 'color': const Color(0xFF00E676)},
      {'label': 'TORQUE MÁX', 'val': '${t.maxTorqueKgfm.toStringAsFixed(1)} kgfm', 'color': const Color(0xFF8EB1E5)},
      {'label': 'ÁGUA / ÓLEO MÁX', 'val': '${t.maxCoolantTemp}° / ${t.maxOilTemp}°C', 'color': const Color(0xFFFFAB00)},
      {'label': 'EGT / IAT MÁX', 'val': '${t.maxEgtTemp}° / ${t.maxIatTemp}°C', 'color': const Color(0xFFFF5252)},
      {'label': 'KNOCK / MISFIRE', 'val': '${t.maxKnockRetard}° / ${t.totalMisfires}', 'color': t.totalMisfires > 0 ? const Color(0xFFFF5252) : const Color(0xFF00E676)},
      {'label': 'AMOSTRAS (1Hz)', 'val': '${t.sampleCount} pts', 'color': Colors.white},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.1,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (ctx, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF131926),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1F2A3D)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['label'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF7387A8)),
                ),
                const SizedBox(height: 2),
                Text(
                  item['val'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: item['color'] as Color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveChartCard() {
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
            children: const [
              Text(
                'GRÁFICO DO DATALOGGER (TOQUE PARA INSPECIONAR)',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot('RPM', const Color(0xFFFF5252)),
              const SizedBox(width: 10),
              _buildLegendDot('Velocidade', const Color(0xFF00E5FF)),
              const SizedBox(width: 10),
              _buildLegendDot('Turbo (bar)', const Color(0xFFFFD600)),
              const SizedBox(width: 10),
              _buildLegendDot('Potência (CV)', const Color(0xFF00E676)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, constraints) {
              return GestureDetector(
                onTapDown: (d) => _updateSelectedFromOffset(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (d) => _updateSelectedFromOffset(d.localPosition.dx, constraints.maxWidth),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TripTelemetryChartPainter(
                      samples: _samples,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateSelectedFromOffset(double dx, double width) {
    if (_samples.isEmpty || width <= 0) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    final idx = (ratio * (_samples.length - 1)).round().clamp(0, _samples.length - 1);
    if (idx != _selectedIndex) {
      setState(() => _selectedIndex = idx);
    }
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B9BB4))),
      ],
    );
  }

  Widget _buildSampleInspectorCard(TripTelemetrySample s) {
    final sec = (s.offsetMs / 1000.0).toStringAsFixed(1);
    final fields = [
      ['RPM / Marcha', '${s.rpm} • ${s.gear}'],
      ['Velocidade', '${s.speed} km/h'],
      ['Turbo / MAP', '${s.boostBar.toStringAsFixed(2)} bar / ${s.mapKpa} kPa'],
      ['TPS / Carga', '${s.tps}% / ${s.engineLoad}%'],
      ['Potência / Torque', '${s.estimatedHp.toStringAsFixed(0)} CV / ${s.estimatedTorqueKgfm.toStringAsFixed(1)} kgfm'],
      ['Água / Óleo', '${s.coolant}°C / ${s.oilTemp}°C'],
      ['Admissão / EGT', '${s.iat}°C / ${s.egt}°C'],
      ['Ignição / Knock', '${s.timingAdvance.toStringAsFixed(1)}° / ${s.knockRetard.toStringAsFixed(1)}°'],
      ['Lambda / AFR', '${s.lambda.toStringAsFixed(2)} / ${s.afr.toStringAsFixed(1)}'],
      ['STFT / LTFT', '${s.stft.toStringAsFixed(1)}% / ${s.ltft.toStringAsFixed(1)}%'],
      ['Linha HPFP / Bat', '${s.fuelRailBar.toStringAsFixed(0)} bar / ${s.voltage.toStringAsFixed(1)}V'],
      ['Consumo / Força G', '${s.fuelKml.toStringAsFixed(1)} km/L / ${s.gLong.toStringAsFixed(2)}G'],
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0066FF).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TELEMETRIA NO INSTANTE ${sec}s (AMOSTRA #${_selectedIndex + 1}/${_samples.length})',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF00E5FF)),
              ),
              Text(
                'Misfires: ${s.totalMisfires}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: s.totalMisfires > 0 ? const Color(0xFFFF5252) : const Color(0xFF00E676),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fields.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (ctx, i) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131926),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fields[i][0], style: const TextStyle(fontSize: 8.5, color: Color(0xFF7387A8))),
                    Text(
                      fields[i][1],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSamplesLogList() {
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
              const Text(
                'REGISTRO COMPLETO (LOG SEGUNDO A SEGUNDO)',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${_samples.length} linhas',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8B9BB4)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF080B10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1C2536)),
            ),
            child: ListView.builder(
              itemCount: _samples.length,
              itemBuilder: (ctx, i) {
                final s = _samples[i];
                final isSelected = i == _selectedIndex;
                final sec = (s.offsetMs / 1000.0).toStringAsFixed(0).padLeft(3, ' ');
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    color: isSelected ? const Color(0xFF0066FF).withValues(alpha: 0.25) : Colors.transparent,
                    child: Text(
                      '[${sec}s] ${s.speed.toString().padLeft(3)}km/h | ${s.rpm.toString().padLeft(4)}rpm | ${s.boostBar.toStringAsFixed(2)}bar | ${s.estimatedHp.toStringAsFixed(0)}cv | ${s.coolant}°C | AFR:${s.afr.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFFA0B0C8),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TripTelemetryChartPainter extends CustomPainter {
  final List<TripTelemetrySample> samples;
  final int selectedIndex;

  _TripTelemetryChartPainter({required this.samples, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    // Fundo e grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1F2A3D)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final int count = samples.length;
    final double stepX = count > 1 ? size.width / (count - 1) : size.width;

    void drawChannel(Color color, double Function(TripTelemetrySample s) normVal) {
      final path = Path();
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < count; i++) {
        final x = i * stepX;
        final val = normVal(samples[i]).clamp(0.0, 1.0);
        final y = size.height - (val * (size.height - 12)) - 6;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    // RPM (0 - 7000)
    drawChannel(const Color(0xFFFF5252), (s) => s.rpm / 7000.0);
    // Velocidade (0 - 220 km/h)
    drawChannel(const Color(0xFF00E5FF), (s) => s.speed / 220.0);
    // Boost (-0.8 a 1.8 bar)
    drawChannel(const Color(0xFFFFD600), (s) => (s.boostBar + 0.8) / 2.6);
    // Potência (0 - maxHp)
    final double maxHp = max(120.0, samples.map((e) => e.estimatedHp).reduce(max));
    drawChannel(const Color(0xFF00E676), (s) => s.estimatedHp / maxHp);

    // Linha vertical do cursor selecionado
    final selX = (selectedIndex * stepX).clamp(0.0, size.width);
    final cursorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(selX, 0), Offset(selX, size.height), cursorPaint);
  }

  @override
  bool shouldRepaint(covariant _TripTelemetryChartPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.selectedIndex != selectedIndex;
  }
}
