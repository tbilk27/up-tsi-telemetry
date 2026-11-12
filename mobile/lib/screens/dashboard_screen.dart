import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';
import '../widgets/tachometer_gauge.dart';
import '../widgets/boost_gauge.dart';
import '../widgets/shift_light_bar.dart';
import '../widgets/sensor_card.dart';
import 'bluetooth_connect_screen.dart';
import 'dtc_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final data = obd.data;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF121722),
                border: Border(bottom: BorderSide(color: Color(0xFF242E42))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF5A739B), width: 1.5),
                        ),
                        child: const Center(
                          child: Text(
                            'VW',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7B98C5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'up!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'TSI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE51A24),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A0B0D),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF701B20)),
                        ),
                        child: const Text(
                          'SPEED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF4D58),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Actions
                  Row(
                    children: [
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC0CDE0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // DTC Button
                      IconButton(
                        icon: const Icon(Icons.warning_amber_rounded, size: 20),
                        color: data.dtcs.isNotEmpty
                            ? const Color(0xFFFF5252)
                            : const Color(0xFF8B9BB4),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DtcScreen()),
                          );
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    // Shift Light Bar
                    ShiftLightBar(rpm: data.rpm),
                    const SizedBox(height: 8),

                    // Gauges Layout (Landscape or Portrait)
                    if (isLandscape)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TachometerGauge(rpm: data.rpm, size: 240),
                          _buildCenterCluster(data),
                          BoostGauge(
                            boostBar: data.boostBar,
                            boostPsi: data.boostPsi,
                            peakBoostBar: data.peakBoostBar,
                            size: 240,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
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
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Sensor Telemetry Cards Grid
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

                    const SizedBox(height: 14),

                    // ECU Meta Footer
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121722),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF242E42)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VIN: ${data.vin}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF8B9BB4),
                            ),
                          ),
                          Text(
                            data.protocol,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF53627A),
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
        ),
      ),
    );
  }

  Widget _buildCenterCluster(data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed Display
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

        // Gear Indicator
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

        // Peak Boost
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
