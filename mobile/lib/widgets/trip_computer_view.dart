import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';
import '../services/fuel_log_service.dart';
import '../models/fuel_log_entry.dart';

class TripComputerView extends StatelessWidget {
  final bool isLandscape;

  const TripComputerView({
    Key? key,
    this.isLandscape = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final fuelLog = Provider.of<FuelLogService>(context);
    final data = obd.data;

    return Container(
      color: const Color(0xFF0A0D14),
      child: isLandscape
          ? _buildLandscapeLayout(context, obd, data, fuelLog)
          : _buildPortraitLayout(context, obd, data, fuelLog),
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    ObdBluetoothService obd,
    dynamic data,
    FuelLogService fuelLog,
  ) {
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

          // 4. Métricas de Viagem & Odômetro Total
          _buildTripMetricsCard(context, obd, data, fuelLog),

          const SizedBox(height: 14),

          // 5. Módulo de Registro de Abastecimento & Consumo Real na Bomba
          _buildFuelLogSection(context, obd, data, fuelLog),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
    BuildContext context,
    ObdBluetoothService obd,
    dynamic data,
    FuelLogService fuelLog,
  ) {
    return Row(
      children: [
        // Lado Esquerdo: Consumo Instantâneo, Média e Odômetro
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
                const SizedBox(height: 8),
                _buildTripMetricsCard(context, obd, data, fuelLog, compact: true),
              ],
            ),
          ),
        ),

        // Lado Direito: Teor de Etanol e Registro de Abastecimento
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _buildEthanolFlexCard(context, data),
                const SizedBox(height: 8),
                _buildFuelLogSection(context, obd, data, fuelLog, compact: true),
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

  // Métricas de Viagem & Odômetro Total
  Widget _buildTripMetricsCard(
    BuildContext context,
    ObdBluetoothService obd,
    dynamic data,
    FuelLogService fuelLog, {
    bool compact = false,
  }) {
    final double tripKm = data.tripDistanceKm;
    final double tripMinutes = data.tripDurationMinutes;
    final double avgSpeed = tripMinutes > 0 ? (tripKm / (tripMinutes / 60.0)) : 0.0;
    final double currentOdo = (data.odometerKm > 0)
        ? data.odometerKm
        : (fuelLog.baseOdometerKm + tripKm);

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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricColumn('DISTÂNCIA', '${tripKm.toStringAsFixed(1)} km', const Color(0xFF00A8FF)),
              _buildVerticalSeparator(),
              _buildMetricColumn('TEMPO VIAGEM', '${tripMinutes.toStringAsFixed(0)} min', const Color(0xFFFFD600)),
              _buildVerticalSeparator(),
              _buildMetricColumn('VEL. MÉDIA', '${avgSpeed.toStringAsFixed(0)} km/h', const Color(0xFF00E676)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF141A26),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF263348)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed, color: Color(0xFF8EB1E5), size: 16),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ODÔMETRO TOTAL DO VEÍCULO',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF7387A8)),
                        ),
                        Text(
                          '${currentOdo.toStringAsFixed(0)} KM',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showCalibrateOdometerDialog(context, obd, fuelLog, currentOdo),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E283B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF384A68)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.tune, color: Color(0xFF00A8FF), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Ajustar',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8EB1E5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Módulo de Registro de Abastecimento & Consumo Real na Bomba
  Widget _buildFuelLogSection(
    BuildContext context,
    ObdBluetoothService obd,
    dynamic data,
    FuelLogService fuelLog, {
    bool compact = false,
  }) {
    final overallKml = fuelLog.overallAverageKml;
    final overallCost = fuelLog.overallCostPerKm;
    final entries = fuelLog.entries;
    final double currentOdo = (data.odometerKm > 0)
        ? data.odometerKm
        : (fuelLog.baseOdometerKm + data.tripDistanceKm);

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
          // Cabeçalho do Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_gas_station, color: Color(0xFFFFD600), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'HISTÓRICO DE ABASTECIMENTOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Abastecer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddFuelDialog(context, obd, fuelLog, currentOdo),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Text(
            'Calcula o consumo real médio (km/L) e custo por km baseado no histórico de tanques cheios.',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF8B9BB4)),
          ),

          const SizedBox(height: 12),

          // Resumo Geral: Média Real, Custo/km e Total Gasto
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141F1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MÉDIA NA BOMBA',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        overallKml > 0 ? '${overallKml.toStringAsFixed(1)} km/L' : '--',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF221F14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD600).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CUSTO / KM',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFFFD600)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        overallCost > 0 ? 'R\$ ${overallCost.toStringAsFixed(2)}' : '--',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00A8FF).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL GASTO',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF00A8FF)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'R\$ ${fuelLog.totalSpent.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Comparativo Telemetria OBDII vs Bomba Real
          if (data.avgFuelConsumptionKml > 0 && overallKml > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF121824),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF25334D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows, color: Color(0xFF8EB1E5), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ECU OBD: ${data.avgFuelConsumptionKml.toStringAsFixed(1)} km/L  •  Bomba: ${overallKml.toStringAsFixed(1)} km/L  (Precisão: ${((data.avgFuelConsumptionKml - overallKml) / overallKml * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC0CDE0)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Lista de Abastecimentos Registrados
          const Text(
            'REGISTROS ANTERIORES',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF7387A8)),
          ),
          const SizedBox(height: 6),

          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'Nenhum abastecimento cadastrado ainda.\nToque em "+ Abastecer" acima para adicionar o primeiro!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF677B99)),
              ),
            )
          else
            ...entries.take(5).map((e) => _buildFuelEntryItem(context, e, fuelLog)),
        ],
      ),
    );
  }

  Widget _buildFuelEntryItem(BuildContext context, FuelLogEntry entry, FuelLogService fuelLog) {
    final dateStr = '${entry.date.day.toString().padLeft(2, '0')}/${entry.date.month.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF121722),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF222C3E)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: entry.isFullTank ? const Color(0xFF14241C) : const Color(0xFF222016),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  entry.isFullTank ? Icons.local_gas_station : Icons.local_gas_station_outlined,
                  size: 18,
                  color: entry.isFullTank ? const Color(0xFF00E676) : const Color(0xFFFFD600),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${entry.fuelType}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8B9BB4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Odômetro: ${entry.odometerKm.toStringAsFixed(0)} km  (${entry.liters.toStringAsFixed(1)} L a R\$ ${entry.pricePerLiter.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF677B99)),
                  ),
                ],
              ),
            ],
          ),

          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${entry.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (entry.calculatedKml != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF00E676)),
                      ),
                      child: Text(
                        '${entry.calculatedKml!.toStringAsFixed(1)} km/L',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    )
                  else if (entry.isFullTank)
                    const Text(
                      'Tanque Base',
                      style: TextStyle(fontSize: 9, color: Color(0xFF8EB1E5)),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF677B99)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF141A26),
                      title: const Text('Excluir Abastecimento?', style: TextStyle(color: Colors.white, fontSize: 14)),
                      content: const Text('Deseja remover este registro de abastecimento?', style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 12)),
                      actions: [
                        TextButton(
                          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE51A24)),
                          child: const Text('Excluir', style: TextStyle(color: Colors.white)),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await fuelLog.deleteEntry(entry.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFuelDialog(
    BuildContext context,
    ObdBluetoothService obd,
    FuelLogService fuelLog,
    double currentOdo,
  ) async {
    final litersCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final odoCtrl = TextEditingController(text: currentOdo.toStringAsFixed(0));
    final stationCtrl = TextEditingController();
    String selectedFuel = 'Gasolina Comum';
    bool fullTank = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101522),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final double l = double.tryParse(litersCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final double p = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
          final double unitPrice = (l > 0 && p > 0) ? (p / l) : 0.0;

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.local_gas_station, color: Color(0xFF00E676), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'REGISTRAR ABASTECIMENTO',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF8B9BB4), size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Campos de Litros e Valor
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: litersCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Litros Abastecidos (L)',
                            labelStyle: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                            suffixText: 'L',
                            suffixStyle: const TextStyle(color: Color(0xFF00E676)),
                            filled: true,
                            fillColor: const Color(0xFF141A26),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Valor Total Pago (R\$)',
                            labelStyle: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                            prefixText: 'R\$ ',
                            prefixStyle: const TextStyle(color: Color(0xFFFFD600)),
                            filled: true,
                            fillColor: const Color(0xFF141A26),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),

                  if (unitPrice > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Preço Calculado por Litro: R\$ ${unitPrice.toStringAsFixed(2)} / L',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8EB1E5)),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Campo Odômetro
                  TextField(
                    controller: odoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Odômetro Atual do Carro (km)',
                      labelStyle: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                      suffixText: 'km',
                      suffixStyle: const TextStyle(color: Color(0xFF00A8FF)),
                      filled: true,
                      fillColor: const Color(0xFF141A26),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Seletor de Tipo de Combustível
                  const Text('Tipo de Combustível:', style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: ['Gasolina Comum', 'Gasolina Aditivada', 'Etanol', 'Gasolina Premium'].map((fuel) {
                      final isSel = selectedFuel == fuel;
                      return ChoiceChip(
                        label: Text(fuel, style: TextStyle(fontSize: 10.5, color: isSel ? Colors.white : const Color(0xFF8B9BB4))),
                        selected: isSel,
                        selectedColor: const Color(0xFF0066FF),
                        backgroundColor: const Color(0xFF141A26),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedFuel = fuel);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  // Switch Tanque Cheio
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Encheu o Tanque? (Tanque Cheio)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: const Text('Permite calcular o consumo exato em km/L desde o último abastecimento.', style: TextStyle(fontSize: 10, color: Color(0xFF7387A8))),
                    value: fullTank,
                    activeThumbColor: const Color(0xFF00E676),
                    onChanged: (val) => setModalState(() => fullTank = val),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Salvar Abastecimento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    onPressed: () async {
                      final double? parsedLiters = double.tryParse(litersCtrl.text.replaceAll(',', '.'));
                      final double? parsedPrice = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                      final double? parsedOdo = double.tryParse(odoCtrl.text.replaceAll(',', '.'));

                      if (parsedLiters == null || parsedLiters <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a quantidade de litros abastecida.')));
                        return;
                      }
                      if (parsedPrice == null || parsedPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o valor total pago.')));
                        return;
                      }
                      if (parsedOdo == null || parsedOdo <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a quilometragem atual do odômetro.')));
                        return;
                      }

                      await fuelLog.addEntry(
                        liters: parsedLiters,
                        totalPrice: parsedPrice,
                        odometerKm: parsedOdo,
                        fuelType: selectedFuel,
                        isFullTank: fullTank,
                        stationName: stationCtrl.text.trim().isNotEmpty ? stationCtrl.text.trim() : null,
                      );

                      obd.setBaseOdometer(parsedOdo);

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF00E676),
                            content: Text('Abastecimento registrado com sucesso! Médias atualizadas.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCalibrateOdometerDialog(
    BuildContext context,
    ObdBluetoothService obd,
    FuelLogService fuelLog,
    double currentOdo,
  ) async {
    final odoCtrl = TextEditingController(text: currentOdo.toStringAsFixed(0));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A26),
        title: Row(
          children: const [
            Icon(Icons.speed, color: Color(0xFF00A8FF), size: 20),
            SizedBox(width: 8),
            Text('Ajustar Odômetro', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caso o veículo não informe o odômetro via PID OBDII padrão (01A6), você pode calibrar a quilometragem real do painel do carro:',
              style: TextStyle(fontSize: 11, color: Color(0xFF8B9BB4), height: 1.3),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: odoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Quilometragem do Painel (km)',
                labelStyle: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12),
                suffixText: 'km',
                suffixStyle: const TextStyle(color: Color(0xFF00A8FF)),
                filled: true,
                fillColor: const Color(0xFF0E131D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            child: const Text('Salvar Odômetro', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final double? val = double.tryParse(odoCtrl.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                await fuelLog.setBaseOdometer(val);
                obd.setBaseOdometer(val);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
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
