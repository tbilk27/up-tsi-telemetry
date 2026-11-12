import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/obd_bluetooth_service.dart';

class DtcScreen extends StatefulWidget {
  const DtcScreen({Key? key}) : super(key: key);

  @override
  State<DtcScreen> createState() => _DtcScreenState();
}

class _DtcScreenState extends State<DtcScreen> {
  bool _isScanning = false;
  bool _hasScanned = false;
  String? _errorMessage;

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    final obd = Provider.of<ObdBluetoothService>(context, listen: false);
    try {
      await obd.scanDTCs();
      setState(() {
        _hasScanned = true;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isScanning = false;
      });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181F2E),
        title: const Text('Limpar Falhas da Injeção?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Isso enviará o comando Mode 04 para apagar a memória da ECU e apagar a luz da injeção (MIL).',
          style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE51A24)),
            child: const Text('Apagar Falhas'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final obd = Provider.of<ObdBluetoothService>(context, listen: false);
      try {
        await obd.clearDTCs();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00E676),
            content: Text('Falhas apagadas com sucesso!'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF5252),
            content: Text('Erro ao apagar: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obd = Provider.of<ObdBluetoothService>(context);
    final dtcs = obd.data.dtcs;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121722),
        elevation: 0,
        title: const Text(
          'DIAGNÓSTICO DA ECU — DTCs',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0070F3),
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
                        : const Icon(Icons.search, size: 18),
                    label: Text(_isScanning ? 'Escanenado...' : 'Escanear Falhas'),
                    onPressed: _isScanning ? null : _scan,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D1012),
                    foregroundColor: const Color(0xFFFF4D58),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFF701B20)),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Apagar'),
                  onPressed: dtcs.isEmpty ? null : _clear,
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A0B0D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF701B20)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13),
                ),
              ),

            // Results
            Expanded(
              child: !_hasScanned
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.monitor_heart, size: 48, color: Color(0xFF53627A)),
                          SizedBox(height: 12),
                          Text(
                            'Clique em "Escanear Falhas" para ler a central.',
                            style: TextStyle(color: Color(0xFF8B9BB4)),
                          ),
                        ],
                      ),
                    )
                  : dtcs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle_outline,
                                  size: 64, color: Color(0xFF00E676)),
                              SizedBox(height: 14),
                              Text(
                                'Nenhuma Falha Registrada!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'A ECU Bosch MED17 do Up! TSI reportou zero DTCs.',
                                style: TextStyle(
                                  color: Color(0xFF8B9BB4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: dtcs.length,
                          itemBuilder: (context, index) {
                            final code = dtcs[index];
                            final desc = ObdBluetoothService.tsiDtcDatabase[code] ??
                                'Código específico VAG / Fabricante';

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1417),
                                borderRadius: BorderRadius.circular(10),
                                border: const Border(
                                  left: BorderSide(
                                    color: Color(0xFFE51A24),
                                    width: 4,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const SizedBox(height: 4),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFC0CDE0),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
