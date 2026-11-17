import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';
import '../services/performance_meter_service.dart';
import '../widgets/tachometer_gauge.dart';
import '../widgets/boost_gauge.dart';
import '../widgets/shift_light_bar.dart';
import '../widgets/sensor_card.dart';
import '../widgets/performance_meter_view.dart';
import 'bluetooth_connect_screen.dart';
import 'obd_terminal_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum FullscreenGauge { none, tachometer, boost, center }

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isScanning = false;
  FullscreenGauge _fullscreenGauge = FullscreenGauge.none;
  VoidCallback? _obdListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final obd = Provider.of<ObdBluetoothService>(context, listen: false);
      final meter = Provider.of<PerformanceMeterService>(context, listen: false);
      _obdListener = () {
        meter.updateTelemetry(obd.data.speed, obd.data.boostBar, obd.data.rpm);
      };
      obd.addListener(_obdListener!);
    });
  }

  @override
  void dispose() {
    if (_obdListener != null) {
      final obd = Provider.of<ObdBluetoothService>(context, listen: false);
      obd.removeListener(_obdListener!);
    }
    _pageController.dispose();
    super.dispose();
  }

  // Calculate live telemetry alerts
  List<Map<String, dynamic>> _getLiveAlerts(data) {
    final alerts = <Map<String, dynamic>>[];

    // 1. Coolant Overheat
    if (data.coolant > 102) {
      alerts.add({
        'title': 'Superaquecimento do Motor',
        'desc': 'Temperatura do arrefecimento em ${data.coolant}°C (Alerta > 102°C).',
        'severity': 'critical',
        'icon': Icons.thermostat,
      });
    }

    // 2. High Intake Air Temp (IAT / Intercooler)
    if (data.iat > 55) {
      alerts.add({
        'title': 'Admissão Aquecida (IAT Alta)',
        'desc': 'Ar admitido em ${data.iat}°C. Intercooler pode estar saturado, reduzindo potência.',
        'severity': 'warning',
        'icon': Icons.air,
      });
    }

    // 3. Fuel Trim Out of Bounds
    if (data.stft.abs() > 18 || data.ltft.abs() > 15) {
      alerts.add({
        'title': 'Ajuste de Mistura Fora da Faixa',
        'desc': 'STFT: ${data.stft}% | LTFT: ${data.ltft}%. Injeção compensando falta ou excesso de combustível.',
        'severity': 'warning',
        'icon': Icons.local_gas_station,
      });
    }

    // 4. Battery / Alternator Voltage
    if (data.voltage > 0 && data.voltage < 11.8) {
      alerts.add({
        'title': 'Tensão da Bateria Baixa',
        'desc': 'Tensão em ${data.voltage.toStringAsFixed(1)}V (Abaixo de 11.8V). Risco de descarga.',
        'severity': 'warning',
        'icon': Icons.battery_alert,
      });
    } else if (data.voltage > 15.0) {
      alerts.add({
        'title': 'Sobretensão no Alternador',
        'desc': 'Tensão em ${data.voltage.toStringAsFixed(1)}V (Acima de 15.0V). Verifique o regulador.',
        'severity': 'critical',
        'icon': Icons.bolt,
      });
    }

    // 5. Overboost warning
    if (data.boostBar > 1.6) {
      alerts.add({
        'title': 'Pressão de Turbo Excessiva (Overboost)',
        'desc': 'Pressão atingiu ${data.boostBar.toStringAsFixed(2)} bar. Verifique a válvula wastegate.',
        'severity': 'critical',
        'icon': Icons.speed,
      });
    }

    return alerts;
  }

  Future<void> _scanDtcs(ObdBluetoothService obd) async {
    setState(() => _isScanning = true);
    try {
      await obd.scanDTCs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF5252),
            content: Text('Erro ao escanear: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _clearErrors(ObdBluetoothService obd) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181F2E),
        title: const Text(
          'Apagar Erros da Injeção?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Isso enviará o comando Modo 04 para a central Bosch MED17, limpando a memória de erros e apagando a luz espia da injeção (MIL).',
          style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE51A24),
              foregroundColor: Colors.white,
            ),
            child: const Text('Apagar Erros'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await obd.clearDTCs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF00E676),
              content: Text('Comando de limpeza enviado! Memória de erros zerada.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFFF5252),
              content: Text('Erro ao apagar: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final data = obd.data;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (_fullscreenGauge != FullscreenGauge.none) {
      return _buildFullscreenView(obd, data, isLandscape);
    }

    final liveAlerts = _getLiveAlerts(data);
    final totalIssues = liveAlerts.length + data.dtcs.length;

    // Shift light ativo no momento configurado de trocar de marcha
    final isShiftPoint = data.rpm >= obd.shiftRpm;
    const shiftYellow = Color(0xFFFFEA00); // Tom de amarelo elétrico mais vivo
    const defaultBg = Color(0xFF0A0D14);
    final currentBg = isShiftPoint ? shiftYellow : defaultBg;

    return Scaffold(
      backgroundColor: currentBg,
      body: SafeArea(
        child: Column(
          children: [
            // Alerta visual de Shift Light quando RPM atinge o ponto de troca
            if (isShiftPoint)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: shiftYellow,
                child: const Center(
                  child: Text(
                    '⚡ SHIFT UP • TROQUE DE MARCHA ⚡',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),

            // Top Bar with Navigation Tabs (ocultada automaticamente quando o celular estiver na horizontal)
            if (!isLandscape)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF121722),
                  border: Border(bottom: BorderSide(color: Color(0xFF242E42))),
                ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF5A739B), width: 1.5),
                        ),
                        child: const Center(
                          child: Text(
                            'VW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7B98C5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'up!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'TSI',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFE51A24)),
                      ),
                    ],
                  ),

                  // Swipe Tabs Indicator (Telemetria vs Arrancada vs Ajustes)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D121C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF202B3D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabButton(
                          title: 'Painel',
                          icon: Icons.speed,
                          index: 0,
                          isActive: _currentPage == 0,
                        ),
                        _buildTabButton(
                          title: 'Arrancada',
                          icon: Icons.timer,
                          index: 1,
                          isActive: _currentPage == 1,
                        ),
                        _buildTabButton(
                          title: 'Ajustes',
                          icon: Icons.tune,
                          index: 2,
                          isActive: _currentPage == 2,
                          badgeCount: totalIssues,
                        ),
                      ],
                    ),
                  ),

                  // Actions: Terminal OBD & Bluetooth Status Pill
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Terminal & Logs OBDII',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.terminal, color: Color(0xFF8B9BB4), size: 18),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ObdTerminalScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BluetoothConnectScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F131A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF242E42)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: obd.isConnected
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFFFF5252),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                obd.isSimulating
                                    ? 'MOCK'
                                    : (obd.isConnected ? 'OBDII ON' : 'CONECTAR'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC0CDE0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // PageView allowing horizontal swipe
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  // PAGE 0: Main Telemetry Dashboard
                  _buildTelemetryDashboardPage(obd, data, isLandscape, isShiftPoint),

                  // PAGE 1: Drag Race Performance Meter
                  PerformanceMeterView(isLandscape: isLandscape),

                  // PAGE 2: Alerts, DTC Errors & Settings (Shift-light & Peak Hold)
                  _buildAlertsAndErrorsPage(obd, data, liveAlerts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab button in top bar
  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
    required bool isActive,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E283B) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive
                  ? (index == 2 && badgeCount > 0 ? const Color(0xFFFF5252) : const Color(0xFF00E676))
                  : const Color(0xFF7387A8),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF8B9BB4),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE51A24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PAGE 0: Telemetry Dashboard
  // =========================================================================
  Widget _buildTelemetryDashboardPage(
    ObdBluetoothService obd,
    dynamic data,
    bool isLandscape,
    bool isShiftPoint,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          // Shift Light Bar adaptativa
          ShiftLightBar(rpm: data.rpm, shiftRpm: obd.shiftRpm),
          const SizedBox(height: 8),

          // Gauges Row (com duplo toque para tela cheia)
          if (isLandscape)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TachometerGauge(
                  rpm: data.rpm,
                  size: 230,
                  isShiftPoint: isShiftPoint,
                  onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.tachometer),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.center),
                  child: _buildCenterCluster(data, isShiftPoint: isShiftPoint),
                ),
                BoostGauge(
                  boostBar: data.boostBar,
                  boostPsi: data.boostPsi,
                  peakBoostBar: data.peakBoostBar,
                  dynamicPeakBar: data.dynamicPeakBoostBar,
                  size: 230,
                  isShiftPoint: isShiftPoint,
                  onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.boost),
                ),
              ],
            )
          else ...[
            // Layout Vertical (Portrait):
            // 1. No topo: Marcha e Velocidade um ao lado do outro
            _buildPortraitSpeedAndGearBar(data, isShiftPoint: isShiftPoint),
            const SizedBox(height: 12),

            // 2. Os 2 gauges um acima do outro (Conta-giros e Pressão do Turbo)
            TachometerGauge(
              rpm: data.rpm,
              size: 215,
              isShiftPoint: isShiftPoint,
              onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.tachometer),
            ),
            const SizedBox(height: 14),
            BoostGauge(
              boostBar: data.boostBar,
              boostPsi: data.boostPsi,
              peakBoostBar: data.peakBoostBar,
              dynamicPeakBar: data.dynamicPeakBoostBar,
              size: 215,
              isShiftPoint: isShiftPoint,
              onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.boost),
            ),
          ],

          const SizedBox(height: 14),

          // Sensor Cards Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isLandscape ? 4 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                SensorCard(
                  title: 'Arrefecimento',
                  value: '${data.coolant} °C',
                  subtitle: 'Ideal: 85°C - 95°C',
                  progress: data.coolant / 120.0,
                  isAlert: data.coolant > 102,
                  gradientColors: const [Color(0xFF0070F3), Color(0xFF00E676)],
                ),
                SensorCard(
                  title: 'Ar Admitido (IAT)',
                  value: '${data.iat} °C',
                  subtitle: 'Intercooler ar/água',
                  progress: data.iat / 70.0,
                  isAlert: data.iat > 55,
                  gradientColors: const [Color(0xFF00BCD4), Color(0xFFFF9800)],
                ),
                SensorCard(
                  title: 'Coletor (MAP)',
                  value: '${data.mapKpa} kPa',
                  subtitle: 'Pressão absoluta',
                  progress: data.mapKpa / 250.0,
                  gradientColors: const [Color(0xFF3F51B5), Color(0xFFE91E63)],
                ),
                SensorCard(
                  title: 'Borboleta (TPS)',
                  value: '${data.tps} %',
                  subtitle: 'Acelerador eletrônico',
                  progress: data.tps / 100.0,
                  gradientColors: const [Color(0xFF9C27B0), Color(0xFFFF3D00)],
                ),
                SensorCard(
                  title: 'Carga do Motor',
                  value: '${data.engineLoad} %',
                  subtitle: 'Calculada pela ECU',
                  progress: data.engineLoad / 100.0,
                  gradientColors: const [Color(0xFF00E676), Color(0xFFFFD600)],
                ),
                SensorCard(
                  title: 'Ponto de Ignição',
                  value: '${data.timingAdvance >= 0 ? '+' : ''}${data.timingAdvance.toStringAsFixed(1)} °',
                  subtitle: 'Graus APMS',
                  progress: (data.timingAdvance + 10) / 50.0,
                  gradientColors: const [Color(0xFF2196F3), Color(0xFF00E676)],
                ),
                SensorCard(
                  title: 'Ajuste Combustível',
                  value: 'S: ${data.stft}% | L: ${data.ltft}%',
                  subtitle: 'STFT / LTFT Mistura',
                  progress: (data.stft.abs() / 25.0),
                  isAlert: data.stft.abs() > 18,
                  gradientColors: const [Color(0xFFFF9800), Color(0xFF4CAF50)],
                ),
                SensorCard(
                  title: 'Bateria / Alternador',
                  value: '${data.voltage.toStringAsFixed(1)} V',
                  subtitle: data.voltage >= 13.5 ? 'Alternador OK' : 'Ignição ligada',
                  progress: (data.voltage - 10) / 5.0,
                  isAlert: data.voltage < 11.8,
                  gradientColors: const [Color(0xFF03A9F4), Color(0xFF8BC34A)],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Swipe Hint Bar
          InkWell(
            onTap: () {
              _pageController.animateToPage(
                1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121722),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF202A3D)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Arraste para o lado para ver Alertas e Erros da Injeção',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7387A8)),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFF7387A8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PAGE 1: Alerts, Messages & DTC Errors Page
  // =========================================================================
  Widget _buildAlertsAndErrorsPage(
    ObdBluetoothService obd,
    dynamic data,
    List<Map<String, dynamic>> liveAlerts,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF181F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF242E42)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      data.dtcs.isNotEmpty
                          ? Icons.warning_rounded
                          : Icons.check_circle_rounded,
                      size: 28,
                      color: data.dtcs.isNotEmpty
                          ? const Color(0xFFFF5252)
                          : const Color(0xFF00E676),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.dtcs.isNotEmpty
                              ? '${data.dtcs.length} Falha(s) na Injeção'
                              : 'Luz da Injeção (MIL): Apagada',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'ECU: Bosch MED17 • Plataforma PQ12',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8B9BB4)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D121C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF202B3D)),
                  ),
                  child: Text(
                    data.protocol,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFF7387A8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons: Scan & Clear
          Row(
            children: [
              // Scan Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0070F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_isScanning ? 'Escanenado...' : 'Escanear Falhas'),
                  onPressed: _isScanning ? null : () => _scanDtcs(obd),
                ),
              ),
              const SizedBox(width: 12),

              // Clear DTCs Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE51A24),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text(
                    'Apagar Erros (MIL)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _clearErrors(obd),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Card de Configuração do Shift-Light RPM
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141A28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFEA00).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.flash_on, color: Color(0xFFFFEA00), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'PONTO DE TROCA (SHIFT LIGHT)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEA00).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFEA00)),
                      ),
                      child: Text(
                        '${obd.shiftRpm} RPM',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFEA00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ajuste em passos de 100 RPM quando o alerta amarelo e os LEDs disparam. Faixa ideal de rendimento do Up! TSI: ~5.200 RPM.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4), height: 1.3),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFFEA00),
                    inactiveTrackColor: const Color(0xFF263248),
                    thumbColor: const Color(0xFFFFEA00),
                    overlayColor: const Color(0xFFFFEA00).withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    trackHeight: 6,
                    valueIndicatorColor: const Color(0xFF0D121C),
                    valueIndicatorTextStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFEA00),
                    ),
                  ),
                  child: Slider(
                    value: obd.shiftRpm.toDouble().clamp(4000.0, 6500.0),
                    min: 4000.0,
                    max: 6500.0,
                    divisions: 25, // 25 divisões = passos de exatamente 100 RPM
                    label: '${obd.shiftRpm} RPM',
                    onChanged: (newVal) {
                      obd.setShiftRpm(newVal.round());
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('4.000 RPM', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
                      Text(
                        '5.200 (Recomendado TSI)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFEA00),
                        ),
                      ),
                      Text('6.500 RPM', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Card: Retenção de Pico de Pressão de Turbo (Peak Hold)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E131D),
              borderRadius: BorderRadius.circular(14),
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
                        Icon(Icons.timer_outlined, color: Color(0xFFFF1744), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'RETENÇÃO DO PICO DE TURBO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF1744)),
                      ),
                      child: Text(
                        '${obd.peakHoldSeconds}s',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF1744),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tempo em que a linha vermelha congela no valor máximo atingido antes de iniciar a descida gradual. Padrão: 10 segundos.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4), height: 1.3),
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFF1744),
                    inactiveTrackColor: const Color(0xFF263248),
                    thumbColor: const Color(0xFFFF1744),
                    overlayColor: const Color(0xFFFF1744).withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    trackHeight: 6,
                    valueIndicatorColor: const Color(0xFF0D121C),
                    valueIndicatorTextStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF1744),
                    ),
                  ),
                  child: Slider(
                    value: obd.peakHoldSeconds.toDouble().clamp(3.0, 60.0),
                    min: 3.0,
                    max: 60.0,
                    divisions: 57, // passos de 1 em 1 segundo
                    label: '${obd.peakHoldSeconds}s',
                    onChanged: (newVal) {
                      obd.setPeakHoldSeconds(newVal.round());
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('3s', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
                      Text(
                        '10s (Padrão Recomendado)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF1744),
                        ),
                      ),
                      Text('60s', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Section 1: Live Telemetry Alerts
          const Text(
            'ALERTAS EM TEMPO REAL (SENSORES):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFF8B9BB4),
            ),
          ),
          const SizedBox(height: 8),

          if (liveAlerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1E16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle_outline, color: Color(0xFF00E676), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Todos os sensores operando dentro das faixas normais.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF88D8B0)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...liveAlerts.map((alert) {
              final isCritical = alert['severity'] == 'critical';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
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
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert['title'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isCritical ? const Color(0xFFFF6B72) : const Color(0xFFFFE57F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert['desc'],
                            style: const TextStyle(fontSize: 11, color: Color(0xFFC0CDE0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

          const SizedBox(height: 22),

          // Section 2: Active DTC Codes
          const Text(
            'CÓDIGOS DE FALHA DA INJEÇÃO (DTCs):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Color(0xFF8B9BB4),
            ),
          ),
          const SizedBox(height: 8),

          if (data.dtcs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121722),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF242E42)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified, color: Color(0xFF00E676), size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nenhuma falha ativa registrada',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'A central não reportou códigos de erro (Resposta 43 00).',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...data.dtcs.map((code) {
              final desc = ObdBluetoothService.tsiDtcDatabase[code] ??
                  'Código específico do fabricante / plataforma VAG';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1417),
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: Color(0xFFE51A24), width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5252),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A0B0D),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF701B20)),
                          ),
                          child: const Text(
                            'CONFIRMADO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF4D58),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFC0CDE0)),
                    ),
                  ],
                ),
              );
            }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Vertical / Portrait Top Bar: Velocidade e Marcha um ao lado do outro
  Widget _buildPortraitSpeedAndGearBar(
    dynamic data, {
    bool isFullscreen = false,
    VoidCallback? onExit,
    bool isShiftPoint = false,
  }) {
    final bgColor = isShiftPoint ? const Color(0xFFFFEA00) : const Color(0xFF0E131D);
    final borderColor = isShiftPoint
        ? Colors.black
        : (isFullscreen ? const Color(0xFFE51A24) : const Color(0xFF202B3D));
    final primaryTextColor = isShiftPoint ? Colors.black : Colors.white;
    final secondaryTextColor = isShiftPoint ? const Color(0xFF212121) : const Color(0xFF8B9BB4);
    final gearBorderColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);
    final gearTextColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        if (isFullscreen) {
          if (onExit != null) onExit();
        } else {
          setState(() => _fullscreenGauge = FullscreenGauge.center);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isShiftPoint ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Velocidade
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${data.speed}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'KM/H',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),

            // Divisor vertical
            Container(
              height: 36,
              width: 1.5,
              color: isShiftPoint ? Colors.black26 : const Color(0xFF242E42),
            ),

            // Marcha
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MARCHA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isShiftPoint
                        ? Colors.black.withValues(alpha: 0.08)
                        : const Color(0xFFE51A24).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gearBorderColor, width: 2.0),
                  ),
                  child: Center(
                    child: Text(
                      data.gear,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: gearTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Divisor vertical
            Container(
              height: 36,
              width: 1.5,
              color: isShiftPoint ? Colors.black26 : const Color(0xFF242E42),
            ),

            // Pico Turbo
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PICO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: secondaryTextColor,
                  ),
                ),
                Text(
                  '${data.peakBoostBar >= 0 ? "+" : ""}${data.peakBoostBar.toStringAsFixed(2)}b',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isShiftPoint ? Colors.black : const Color(0xFFFF9100),
                  ),
                ),
              ],
            ),

            if (isFullscreen) ...[
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Sair da tela cheia',
                icon: Icon(Icons.fullscreen_exit, color: primaryTextColor, size: 26),
                onPressed: onExit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Lateral Esquerda (Vertical) quando em orientação Paisagem (Horizontal) com Gauge Destacado
  Widget _buildLandscapeSpeedAndGearSidebar(
    dynamic data, {
    VoidCallback? onExit,
    bool isShiftPoint = false,
  }) {
    final bgColor = isShiftPoint ? const Color(0xFFFFEA00) : const Color(0xFF0E131D);
    final borderColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);
    final primaryTextColor = isShiftPoint ? Colors.black : Colors.white;
    final secondaryTextColor = isShiftPoint ? const Color(0xFF212121) : const Color(0xFF8B9BB4);
    final gearBorderColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);
    final gearTextColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onExit,
      child: Container(
        width: 125,
        margin: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Velocidade
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data.speed}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'KM/H',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),

            Container(
              width: 44,
              height: 1.5,
              color: isShiftPoint ? Colors.black26 : const Color(0xFF242E42),
            ),

            // Marcha
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MARCHA',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isShiftPoint
                        ? Colors.black.withValues(alpha: 0.08)
                        : const Color(0xFFE51A24).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gearBorderColor, width: 2.2),
                  ),
                  child: Center(
                    child: Text(
                      data.gear,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: gearTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Container(
              width: 44,
              height: 1.5,
              color: isShiftPoint ? Colors.black26 : const Color(0xFF242E42),
            ),

            // Pico Turbo
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PICO TURBO',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.peakBoostBar >= 0 ? "+" : ""}${data.peakBoostBar.toStringAsFixed(2)}b',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isShiftPoint ? Colors.black : const Color(0xFFFF9100),
                  ),
                ),
              ],
            ),

            // Botão sair do destaque
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Sair da tela cheia',
              icon: Icon(
                Icons.fullscreen_exit,
                color: primaryTextColor,
                size: 26,
              ),
              onPressed: onExit,
            ),
          ],
        ),
      ),
    );
  }

  // Center Speed & Gear Cluster
  Widget _buildCenterCluster(dynamic data, {bool isFullscreen = false, bool isShiftPoint = false}) {
    final primaryTextColor = isShiftPoint ? Colors.black : Colors.white;
    final secondaryTextColor = isShiftPoint ? Colors.black87 : const Color(0xFF8B9BB4);
    final cardBgColor = isShiftPoint ? Colors.black.withValues(alpha: 0.08) : const Color(0xFF0E131D);
    final cardBorderColor = isShiftPoint ? Colors.black45 : const Color(0xFF202B3D);
    final gearBorderColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);
    final gearTextColor = isShiftPoint ? Colors.black : const Color(0xFFE51A24);
    final gearBgColor = isShiftPoint ? Colors.black.withValues(alpha: 0.08) : const Color(0xFFE51A24).withValues(alpha: 0.12);
    final peakColor = isShiftPoint ? Colors.black : const Color(0xFFFF9100);

    if (isFullscreen) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  '${data.speed}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'VELOCIDADE (KM/H)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: gearBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: gearBorderColor, width: 3.0),
            ),
            child: Center(
              child: Text(
                data.gear,
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  color: gearTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'PICO DE TURBO: ${data.peakBoostBar >= 0 ? "+" : ""}${data.peakBoostBar.toStringAsFixed(2)} bar',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: peakColor,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            children: [
              Text(
                '${data.speed}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  height: 1.0,
                ),
              ),
              Text(
                'KM/H',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: gearBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: gearBorderColor, width: 1.8),
          ),
          child: Center(
            child: Text(
              data.gear,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: gearTextColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PICO: ${data.peakBoostBar >= 0 ? "+" : ""}${data.peakBoostBar.toStringAsFixed(2)} bar',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: peakColor,
          ),
        ),
      ],
    );
  }

  // Fullscreen Gauge View
  Widget _buildFullscreenView(ObdBluetoothService obd, dynamic data, bool isLandscape) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.padding.top - media.padding.bottom;
    final availableWidth = media.size.width - media.padding.left - media.padding.right;

    final isShiftPoint = data.rpm >= obd.shiftRpm;
    const shiftYellow = Color(0xFFFFEA00);
    const defaultBg = Color(0xFF0A0D14);
    final currentBg = isShiftPoint ? shiftYellow : defaultBg;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _fullscreenGauge = FullscreenGauge.none);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          setState(() => _fullscreenGauge = FullscreenGauge.none);
        },
        child: Scaffold(
          backgroundColor: currentBg,
          body: SafeArea(
            child: isLandscape
                ? _buildLandscapeFullscreenBody(obd, data, isShiftPoint, availableWidth, availableHeight)
                : _buildPortraitFullscreenBody(obd, data, isShiftPoint, availableWidth, availableHeight, shiftYellow),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeFullscreenBody(
    ObdBluetoothService obd,
    dynamic data,
    bool isShiftPoint,
    double availableWidth,
    double availableHeight,
  ) {
    final hasShiftLight = _fullscreenGauge == FullscreenGauge.tachometer;
    final gaugeSize = hasShiftLight
        ? (availableHeight - 56).clamp(160.0, 500.0)
        : (availableHeight - 20).clamp(160.0, 500.0);

    return Row(
      children: [
        // 1. Barra vertical à esquerda com Velocidade e Marcha
        _buildLandscapeSpeedAndGearSidebar(
          data,
          isShiftPoint: isShiftPoint,
          onExit: () => setState(() => _fullscreenGauge = FullscreenGauge.none),
        ),

        const SizedBox(width: 8),

        // 2. Área principal do gauge expandido
        Expanded(
          child: Column(
            children: [
              if (isShiftPoint)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withValues(alpha: 0.15),
                  child: const Center(
                    child: Text(
                      '⚡ SHIFT UP • TROQUE DE MARCHA ⚡',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              if (hasShiftLight) ...[
                const SizedBox(height: 4),
                ShiftLightBar(rpm: data.rpm, shiftRpm: obd.shiftRpm),
                const SizedBox(height: 4),
              ],
              Expanded(
                child: Center(
                  child: _buildFullscreenGaugeWidget(obd, data, gaugeSize, isShiftPoint),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitFullscreenBody(
    ObdBluetoothService obd,
    dynamic data,
    bool isShiftPoint,
    double availableWidth,
    double availableHeight,
    Color shiftYellow,
  ) {
    final gaugeSize = (availableWidth - 24).clamp(
      180.0,
      (availableHeight - 170).clamp(180.0, 480.0),
    );

    return Column(
      children: [
        // 1. Shift banner in fullscreen mode
        if (isShiftPoint)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: shiftYellow,
            child: const Center(
              child: Text(
                '⚡ SHIFT UP • TROQUE DE MARCHA ⚡',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.black,
                ),
              ),
            ),
          ),

        const SizedBox(height: 4),

        // 2. Card de Velocidade e Marcha mantido no topo ao destacar qualquer gauge
        _buildPortraitSpeedAndGearBar(
          data,
          isFullscreen: true,
          isShiftPoint: isShiftPoint,
          onExit: () => setState(() => _fullscreenGauge = FullscreenGauge.none),
        ),

        const SizedBox(height: 4),

        // 3. Shift Light Bar on top for Tachometer
        if (_fullscreenGauge == FullscreenGauge.tachometer) ...[
          ShiftLightBar(rpm: data.rpm, shiftRpm: obd.shiftRpm),
          const SizedBox(height: 8),
        ],

        // 4. Fullscreen Gauge Widget
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: _buildFullscreenGaugeWidget(obd, data, gaugeSize, isShiftPoint),
            ),
          ),
        ),

        // 5. Bottom HUD: live quick stats + double tap hint
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isShiftPoint ? Colors.black.withValues(alpha: 0.1) : const Color(0xFF121722),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isShiftPoint ? Colors.black45 : const Color(0xFF202A3D),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 13,
                      color: isShiftPoint ? Colors.black54 : const Color(0xFF7387A8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Duplo toque para restaurar',
                      style: TextStyle(
                        fontSize: 11,
                        color: isShiftPoint ? Colors.black87 : const Color(0xFF8B9BB4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${data.speed} KM/H  •  M: ${data.gear}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isShiftPoint ? Colors.black : const Color(0xFF00E676),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenGaugeWidget(
    ObdBluetoothService obd,
    dynamic data,
    double gaugeSize,
    bool isShiftPoint,
  ) {
    if (_fullscreenGauge == FullscreenGauge.tachometer) {
      return TachometerGauge(
        rpm: data.rpm,
        size: gaugeSize,
        isShiftPoint: isShiftPoint,
        onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.none),
      );
    } else if (_fullscreenGauge == FullscreenGauge.boost) {
      return BoostGauge(
        boostBar: data.boostBar,
        boostPsi: data.boostPsi,
        peakBoostBar: data.peakBoostBar,
        dynamicPeakBar: data.dynamicPeakBoostBar,
        isShiftPoint: isShiftPoint,
        size: gaugeSize,
        onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.none),
      );
    } else {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () => setState(() => _fullscreenGauge = FullscreenGauge.none),
        child: _buildCenterCluster(data, isFullscreen: true, isShiftPoint: isShiftPoint),
      );
    }
  }
}
