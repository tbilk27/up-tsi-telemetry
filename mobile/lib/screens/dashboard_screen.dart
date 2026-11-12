import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';
import '../widgets/tachometer_gauge.dart';
import '../widgets/boost_gauge.dart';
import '../widgets/shift_light_bar.dart';
import '../widgets/sensor_card.dart';
import 'bluetooth_connect_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isScanning = false;

  @override
  void dispose() {
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
    final liveAlerts = _getLiveAlerts(data);
    final totalIssues = liveAlerts.length + data.dtcs.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Navigation Tabs
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

                  // Swipe Tabs Indicator (Telemetria vs Alertas)
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
                          title: 'Alertas',
                          icon: Icons.warning_amber_rounded,
                          index: 1,
                          isActive: _currentPage == 1,
                          badgeCount: totalIssues,
                        ),
                      ],
                    ),
                  ),

                  // Bluetooth Status Pill
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
                  _buildTelemetryDashboardPage(data, isLandscape),

                  // PAGE 1: Alerts, Messages & DTC Errors Page
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
                  ? (index == 1 && badgeCount > 0 ? const Color(0xFFFF5252) : const Color(0xFF00E676))
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
  Widget _buildTelemetryDashboardPage(data, bool isLandscape) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          // Shift Light Bar
          ShiftLightBar(rpm: data.rpm),
          const SizedBox(height: 8),

          // Gauges Row
          if (isLandscape)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TachometerGauge(rpm: data.rpm, size: 230),
                _buildCenterCluster(data),
                BoostGauge(
                  boostBar: data.boostBar,
                  boostPsi: data.boostPsi,
                  peakBoostBar: data.peakBoostBar,
                  size: 230,
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TachometerGauge(rpm: data.rpm, size: 175),
                _buildCenterCluster(data),
                BoostGauge(
                  boostBar: data.boostBar,
                  boostPsi: data.boostPsi,
                  peakBoostBar: data.peakBoostBar,
                  size: 175,
                ),
              ],
            ),

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
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
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

  // Center Speed & Gear Cluster
  Widget _buildCenterCluster(data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E131D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF202B3D)),
          ),
          child: Column(
            children: [
              Text(
                '${data.speed}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const Text(
                'KM/H',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Color(0xFF8B9BB4),
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
            color: const Color(0xFFE51A24).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE51A24), width: 1.8),
          ),
          child: Center(
            child: Text(
              data.gear,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE51A24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PICO: ${data.peakBoostBar >= 0 ? "+" : ""}${data.peakBoostBar.toStringAsFixed(2)} bar',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF9100),
          ),
        ),
      ],
    );
  }
}
