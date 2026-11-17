import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';

class TripComputerView extends StatelessWidget {
  final bool isLandscape;

  const TripComputerView({
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
          // 1. Mostrador Central de Consumo Instantâneo (km/L ou L/h)
          _buildInstantConsumptionCard(context, data),

          const SizedBox(height: 12),

          // 2. Média da Viagem e Custos em R$
          _buildTripCostAndAverageCard(context, obd, data),

          const SizedBox(height: 12),

          // 3. Teor de Etanol no Tanque (% de Álcool / Flex Fuel)
          _buildEthanolFlexCard(context, data),

          const SizedBox(height: 12),

          // 4. Métricas de Viagem (Distância, Duração, Velocidade Média)
          _buildTripMetricsCard(context, obd, data),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, ObdBluetoothService obd, dynamic data) {
    return Row(
      children: [
        // Lado Esquerdo: Consumo Instantâneo e Média
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildInstantConsumptionCard(context, data, compact: true),
                const SizedBox(height: 8),
                _buildTripCostAndAverageCard(context, obd, data, compact: true),
              ],
            ),
          ),
        ),

        // Lado Direito: Teor de Etanol e Métricas
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildEthanolFlexCard(context, data),
                const SizedBox(height: 8),
                _buildTripMetricsCard(context, obd, data, compact: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Card do Consumo Instantâneo (km/L em movimento, L/h parado)
  Widget _buildInstantConsumptionCard(BuildContext context, dynamic data, {bool compact = false}) {
    final bool isStationary = data.speed < 3;
    final String unit = isStationary ? 'L/h' : 'km/L';
    final double value = isStationary ? data.fuelConsumptionLh : data.fuelConsumptionKml;

    // Cores ecológicas
    final Color valueColor = isStationary
        ? const Color(0xFF00A8FF)
        : (value >= 12.0
            ? const Color(0xFF00E676)
            : (value >= 8.0 ? const Color(0xFFFFD600) : const Color(0xFFFF9100)));

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.eco, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'CONSUMO INSTANTÂNEO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16241B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                ),
                child: Text(
                  isStationary ? 'PARADO (L/H)' : 'EM MOVIMENTO (KM/L)',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: compact ? 6 : 14),

          // Valor Gigante de Consumo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: compact ? 48 : 64,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: valueColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B9BB4),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Barra de Eco
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (value / 25.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF1B2332),
              valueColor: AlwaysStoppedAnimation<Color>(valueColor),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
              Text('Consumo Eficiente TSI', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
              Text('25 km/L', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
            ],
          ),
        ],
      ),
    );
  }

  // Média da Viagem e Custos em R$
  Widget _buildTripCostAndAverageCard(BuildContext context, ObdBluetoothService obd, dynamic data, {bool compact = false}) {
    final double avgKml = data.avgFuelConsumptionKml;
    final double totalLiters = data.totalFuelConsumedLiters;
    final double fuelCost = totalLiters * data.fuelPricePerLiter;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.monetization_on_outlined, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'MÉDIA & CUSTO DA VIAGEM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => obd.resetTrip(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E283B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Zerar Viagem',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8B9BB4)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              // Média km/L
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF202B3D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MÉDIA DA SESSÃO',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7387A8)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            avgKml.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00E676),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('km/L', style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Litros Consumidos
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF202B3D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMBUSTÍVEL',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7387A8)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            totalLiters.toStringAsFixed(2),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF00A8FF),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('L', style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Custo em R$
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF202B3D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CUSTO VIAGEM',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7387A8)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            'R\$ ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFFD600)),
                          ),
                          Text(
                            fuelCost.toStringAsFixed(2),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Teor de Etanol no Tanque (Flex Alcohol Sensor %)
  Widget _buildEthanolFlexCard(BuildContext context, dynamic data) {
    final int ethanolPercent = data.ethanolPercent;
    final String fuelType = ethanolPercent > 70
        ? 'Etanol Hidratado ($ethanolPercent%)'
        : (ethanolPercent < 32 ? 'Gasolina Brasileira E27 ($ethanolPercent%)' : 'Mistura Flex ($ethanolPercent%)');

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
                children: const [
                  Icon(Icons.opacity, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'TEOR DE ETANOL (SENSOR FLEX)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16251E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E676)),
                ),
                child: Text(
                  '$ethanolPercent% ÁLCOOL',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Barra visual de combustível Flex
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (ethanolPercent / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: const Color(0xFF263248),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0% Gasolina Pura', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
              Text(
                fuelType,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Text('100% Etanol', style: TextStyle(fontSize: 10, color: Color(0xFF677B99))),
            ],
          ),
        ],
      ),
    );
  }

  // Métricas de Viagem (Distância e Duração)
  Widget _buildTripMetricsCard(BuildContext context, ObdBluetoothService obd, dynamic data, {bool compact = false}) {
    final double tripKm = data.tripDistanceKm;
    final double tripMinutes = data.tripDurationMinutes;
    final double avgSpeed = tripMinutes > 0 ? (tripKm / (tripMinutes / 60.0)) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E131D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202B3D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricColumn('DISTÂNCIA', '${tripKm.toStringAsFixed(1)} km', const Color(0xFF00A8FF)),
          _buildVerticalSeparator(),
          _buildMetricColumn('TEMPO VIAGEM', '${tripMinutes.toStringAsFixed(0)} min', const Color(0xFFFFD600)),
          _buildVerticalSeparator(),
          _buildMetricColumn('VEL. MÉDIA', '${avgSpeed.toStringAsFixed(0)} km/h', const Color(0xFF00E676)),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF7387A8)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalSeparator() {
    return Container(width: 1, height: 26, color: const Color(0xFF202B3D));
  }
}
