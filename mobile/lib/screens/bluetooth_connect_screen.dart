import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';

class BluetoothConnectScreen extends StatefulWidget {
  const BluetoothConnectScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothConnectScreen> createState() => _BluetoothConnectScreenState();
}

class _BluetoothConnectScreenState extends State<BluetoothConnectScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final service = Provider.of<ObdBluetoothService>(context, listen: false);
    final list = await service.getPairedDevices();
    setState(() {
      _devices = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121722),
        elevation: 0,
        title: const Text(
          'CONEXÃO BLUETOOTH OBD-II',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF181F2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF242E42)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: obd.isConnected
                        ? const Color(0xFF00E676)
                        : (obd.status == BluetoothStateStatus.connecting
                            ? const Color(0xFFFFD600)
                            : const Color(0xFFFF5252)),
                    boxShadow: [
                      BoxShadow(
                        color: obd.isConnected
                            ? const Color(0xFF00E676).withOpacity(0.6)
                            : Colors.transparent,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obd.statusMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (obd.selectedDevice != null)
                        Text(
                          '${obd.selectedDevice!.name ?? "Dispositivo"} (${obd.selectedDevice!.address})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8B9BB4),
                          ),
                        ),
                    ],
                  ),
                ),
                if (obd.isConnected)
                  TextButton(
                    onPressed: () => obd.disconnect(),
                    child: const Text(
                      'Desconectar',
                      style: TextStyle(color: Color(0xFFFF5252), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Simulation Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: obd.isSimulating
                    ? const Color(0xFF2A0B0D)
                    : const Color(0xFF242E42),
                foregroundColor: obd.isSimulating
                    ? const Color(0xFFFF4D58)
                    : const Color(0xFFC0CDE0),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: obd.isSimulating
                        ? const Color(0xFFE51A24)
                        : const Color(0xFF364661),
                  ),
                ),
              ),
              icon: Icon(obd.isSimulating ? Icons.stop : Icons.play_arrow),
              label: Text(
                obd.isSimulating
                    ? 'Parar Modo Simulação (Demo)'
                    : 'Ativar Modo Simulação (Testar Sem Carro)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (obd.isSimulating) {
                  obd.disconnect();
                } else {
                  obd.startSimulation();
                  Navigator.pop(context);
                }
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DISPOSITIVOS PAREADOS NO TELEFONE:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF53627A),
                ),
              ),
            ),
          ),

          // Device list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE51A24)),
                  )
                : _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.bluetooth_searching,
                                size: 48, color: Color(0xFF53627A)),
                            SizedBox(height: 12),
                            Text(
                              'Nenhum dispositivo Bluetooth pareado.',
                              style: TextStyle(color: Color(0xFF8B9BB4)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pareie o adaptador "OBDII" nas configurações de Bluetooth do seu celular.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Color(0xFF53627A)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final name = device.name ?? 'Dispositivo Desconhecido';
                          final isObd = name.toUpperCase().contains('OBD') ||
                              name.toUpperCase().contains('ELM');
                          final isCurrent = obd.selectedDevice?.address == device.address &&
                              obd.isConnected;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFF1E283B)
                                  : const Color(0xFF121722),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isObd
                                    ? const Color(0xFFE51A24).withOpacity(0.5)
                                    : const Color(0xFF242E42),
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                isObd ? Icons.directions_car : Icons.bluetooth,
                                color: isObd
                                    ? const Color(0xFFE51A24)
                                    : const Color(0xFF8B9BB4),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isObd) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2A0B0D),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: const Color(0xFF701B20)),
                                      ),
                                      child: const Text(
                                        'OBDII',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Color(0xFFFF4D58),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                device.address,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF53627A)),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isCurrent
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFF0070F3),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: isCurrent
                                    ? null
                                    : () async {
                                        await obd.connect(device);
                                        if (mounted && obd.isConnected) {
                                          Navigator.pop(context);
                                        }
                                      },
                                child: Text(isCurrent ? 'Ativo' : 'Conectar'),
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
