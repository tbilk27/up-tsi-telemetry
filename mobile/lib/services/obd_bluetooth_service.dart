import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/telemetry_data.dart';

enum BluetoothStateStatus {
  disconnected,
  connecting,
  initializing,
  connected,
  error,
}

class ObdBluetoothService extends ChangeNotifier {
  BluetoothConnection? _connection;
  BluetoothDevice? _selectedDevice;
  BluetoothStateStatus _status = BluetoothStateStatus.disconnected;
  String _statusMessage = 'Desconectado';
  TelemetryData _data = const TelemetryData();

  Timer? _pollingTimer;
  Timer? _simulationTimer;
  bool _isPolling = false;
  double _peakBoost = 0.0;
  String _receiveBuffer = '';

  BluetoothStateStatus get status => _status;
  String get statusMessage => _statusMessage;
  TelemetryData get data => _data;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _data.isConnected;
  bool get isSimulating => _data.isSimulating;

  // Dictionary of known VW EA211 TSI fault codes
  static const Map<String, String> tsiDtcDatabase = {
    'P0299': 'Pressão de turbo abaixo do esperado (Underboost)',
    'P0234': 'Pressão de turbo excessiva (Overboost)',
    'P0300': 'Falha de combustão aleatória/múltipla (Misfire)',
    'P0301': 'Falha de combustão no cilindro 1',
    'P0302': 'Falha de combustão no cilindro 2',
    'P0303': 'Falha de combustão no cilindro 3 (EA211 3 Cil.)',
    'P0106': 'Sensor MAP - Faixa/Rendimento incorreto',
    'P0171': 'Mistura ar/combustível excessivamente pobre',
    'P0172': 'Mistura ar/combustível excessivamente rica',
    'P0420': 'Eficiência do catalisador abaixo do limite (Downpipe)',
    'P0130': 'Falha no circuito da Sonda Lambda pré-catalisador',
    'P0136': 'Falha no circuito da Sonda Lambda pós-catalisador',
    'P0016': 'Correlação Virabrequim/Comando de válvulas fora de ponto',
  };

  // Request Bluetooth & Location permissions
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  // Get paired Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      await requestPermissions();
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      debugPrint('Erro ao listar dispositivos pareados: $e');
      return [];
    }
  }

  // Connect to a Bluetooth OBD-II device
  Future<void> connect(BluetoothDevice device) async {
    disconnect();
    _selectedDevice = device;
    _status = BluetoothStateStatus.connecting;
    _statusMessage = 'Conectando a ${device.name ?? device.address}...';
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _status = BluetoothStateStatus.initializing;
      _statusMessage = 'Inicializando ELM327...';
      notifyListeners();

      _connection!.input?.listen(_onDataReceived).onDone(() {
        disconnect();
      });

      // Initialize ELM327 protocol
      await _sendCommand('ATZ', delayMs: 1000);
      await _sendCommand('ATE0', delayMs: 300); // Echo Off
      await _sendCommand('ATL0', delayMs: 250); // Linefeeds Off
      await _sendCommand('ATH0', delayMs: 250); // Headers Off
      await _sendCommand('ATSP0', delayMs: 350); // Auto Protocol

      // Query Battery Voltage & Protocol
      final voltResp = await _sendCommand('ATRV', delayMs: 300);
      final protoResp = await _sendCommand('ATDP', delayMs: 300);

      double initialVolt = 12.3;
      final voltMatch = RegExp(r'(\d+\.?\d*)V').firstMatch(voltResp);
      if (voltMatch != null) {
        initialVolt = double.tryParse(voltMatch.group(1) ?? '12.3') ?? 12.3;
      }

      _data = _data.copyWith(
        isConnected: true,
        isSimulating: false,
        voltage: initialVolt,
        protocol: protoResp.replaceAll(RegExp(r'[\r\n>]'), '').trim(),
      );

      _status = BluetoothStateStatus.connected;
      _statusMessage = 'Conectado ao Up! TSI';
      notifyListeners();

      _startPollingLoop();
    } catch (e) {
      _status = BluetoothStateStatus.error;
      _statusMessage = 'Falha ao conectar: $e';
      disconnect();
      notifyListeners();
    }
  }

  void _onDataReceived(Uint8List bytes) {
    _receiveBuffer += ascii.decode(bytes);
  }

  Future<String> _sendCommand(String cmd, {int delayMs = 300}) async {
    if (_connection == null || !_connection!.isConnected) return '';
    _receiveBuffer = '';
    _connection!.output.add(ascii.encode('$cmd\r'));
    await _connection!.output.allSent;
    await Future.delayed(Duration(milliseconds: delayMs));
    return _receiveBuffer;
  }

  // Real-time OBD polling loop
  void _startPollingLoop() {
    _isPolling = true;
    int cycle = 0;

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) async {
      if (!_isPolling || _connection == null || !_connection!.isConnected) {
        timer.cancel();
        return;
      }

      cycle++;
      try {
        // High priority: RPM (010C)
        final rpmRaw = await _sendCommand('010C', delayMs: 220);
        final rpmMatch = RegExp(r'410C([0-9A-Fa-f]{4})').firstMatch(rpmRaw.replaceAll(' ', ''));
        int rpm = _data.rpm;
        if (rpmMatch != null) {
          final val = int.tryParse(rpmMatch.group(1)!, radix: 16);
          if (val != null) rpm = (val / 4).round();
        }

        // MAP & Boost (010B)
        final mapRaw = await _sendCommand('010B', delayMs: 180);
        final mapMatch = RegExp(r'410B([0-9A-Fa-f]{2})').firstMatch(mapRaw.replaceAll(' ', ''));
        int mapKpa = _data.mapKpa;
        double boostBar = _data.boostBar;
        double boostPsi = _data.boostPsi;

        if (mapMatch != null) {
          final val = int.tryParse(mapMatch.group(1)!, radix: 16);
          if (val != null) {
            mapKpa = val;
            boostBar = double.parse(((mapKpa - 101) / 100).toStringAsFixed(2));
            boostPsi = double.parse((boostBar * 14.5038).toStringAsFixed(1));
            if (boostBar > _peakBoost) _peakBoost = boostBar;
          }
        }

        // Speed (010D) & TPS (0111)
        final speedRaw = await _sendCommand('010D', delayMs: 160);
        final speedMatch = RegExp(r'410D([0-9A-Fa-f]{2})').firstMatch(speedRaw.replaceAll(' ', ''));
        int speed = _data.speed;
        if (speedMatch != null) {
          final val = int.tryParse(speedMatch.group(1)!, radix: 16);
          if (val != null) speed = val;
        }

        final tpsRaw = await _sendCommand('0111', delayMs: 160);
        final tpsMatch = RegExp(r'4111([0-9A-Fa-f]{2})').firstMatch(tpsRaw.replaceAll(' ', ''));
        int tps = _data.tps;
        if (tpsMatch != null) {
          final val = int.tryParse(tpsMatch.group(1)!, radix: 16);
          if (val != null) tps = ((val * 100) / 255).round();
        }

        // Medium priority (Every 3 cycles): Load (0104) and Timing (010E)
        int load = _data.engineLoad;
        double timing = _data.timingAdvance;
        if (cycle % 3 == 0) {
          final loadRaw = await _sendCommand('0104', delayMs: 160);
          final loadMatch = RegExp(r'4104([0-9A-Fa-f]{2})').firstMatch(loadRaw.replaceAll(' ', ''));
          if (loadMatch != null) {
            final val = int.tryParse(loadMatch.group(1)!, radix: 16);
            if (val != null) load = ((val * 100) / 255).round();
          }

          final timingRaw = await _sendCommand('010E', delayMs: 160);
          final timingMatch = RegExp(r'410E([0-9A-Fa-f]{2})').firstMatch(timingRaw.replaceAll(' ', ''));
          if (timingMatch != null) {
            final val = int.tryParse(timingMatch.group(1)!, radix: 16);
            if (val != null) timing = (val / 2) - 64;
          }
        }

        // Low priority (Every 6 cycles): Coolant (0105), IAT (010F), Fuel Trim (0106/0107)
        int coolant = _data.coolant;
        int iat = _data.iat;
        double stft = _data.stft;
        double ltft = _data.ltft;
        double voltage = _data.voltage;

        if (cycle % 6 == 0) {
          final coolRaw = await _sendCommand('0105', delayMs: 160);
          final coolMatch = RegExp(r'4105([0-9A-Fa-f]{2})').firstMatch(coolRaw.replaceAll(' ', ''));
          if (coolMatch != null) {
            final val = int.tryParse(coolMatch.group(1)!, radix: 16);
            if (val != null) coolant = val - 40;
          }

          final iatRaw = await _sendCommand('010F', delayMs: 160);
          final iatMatch = RegExp(r'410F([0-9A-Fa-f]{2})').firstMatch(iatRaw.replaceAll(' ', ''));
          if (iatMatch != null) {
            final val = int.tryParse(iatMatch.group(1)!, radix: 16);
            if (val != null) iat = val - 40;
          }

          final voltRaw = await _sendCommand('ATRV', delayMs: 160);
          final voltMatch = RegExp(r'(\d+\.?\d*)V').firstMatch(voltRaw);
          if (voltMatch != null) {
            voltage = double.tryParse(voltMatch.group(1)!) ?? voltage;
          }
        }

        _data = _data.copyWith(
          rpm: rpm,
          speed: speed,
          mapKpa: mapKpa,
          boostBar: boostBar,
          boostPsi: boostPsi,
          peakBoostBar: _peakBoost,
          tps: tps,
          engineLoad: load,
          timingAdvance: timing,
          coolant: coolant,
          iat: iat,
          stft: stft,
          ltft: ltft,
          voltage: voltage,
          gear: _estimateGear(speed, rpm),
        );

        notifyListeners();
      } catch (e) {
        debugPrint('Erro no loop OBD: $e');
      }
    });
  }

  // Gear estimation for Up! TSI (MQ200 5-speed manual)
  String _estimateGear(int speed, int rpm) {
    if (rpm < 500 || speed < 2) return 'N';
    final ratio = rpm / speed;
    if (ratio > 110) return '1';
    if (ratio > 65) return '2';
    if (ratio > 44) return '3';
    if (ratio > 32) return '4';
    if (ratio > 22) return '5';
    return 'N';
  }

  // Simulation / Mock Mode for testing without car
  void startSimulation() {
    disconnect();
    _status = BluetoothStateStatus.connected;
    _statusMessage = 'Modo Mock Ativo (Dados Fictícios)';
    _peakBoost = 1.25;

    _data = const TelemetryData(
      isConnected: true,
      isSimulating: true,
      voltage: 14.2,
      coolant: 90,
      iat: 36,
      protocol: 'CAN 11/500 (Simulado)',
    );
    notifyListeners();

    double simTime = 0.0;
    String phase = 'idle';
    double phaseTimer = 0.0;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      simTime += 0.05;
      phaseTimer += 0.05;

      int rpm = 850;
      int speed = 0;
      int tps = 12;
      double boostBar = -0.62;
      int load = 18;
      double timing = 5.0;
      String gear = 'N';

      if (phase == 'idle') {
        rpm = (850 + sin(simTime * 4) * 25).round();
        speed = 0;
        tps = 12;
        boostBar = -0.62;
        load = 18;
        timing = 5.0;
        gear = 'N';
        if (phaseTimer > 2.5) { phase = 'accel1'; phaseTimer = 0; }
      } else if (phase == 'accel1') {
        tps = 100;
        gear = '1';
        rpm = min(6200, (1400 + phaseTimer * 1700).round());
        speed = ((rpm / 6200) * 48).round();
        boostBar = double.parse(min(1.25, -0.6 + phaseTimer * 0.9).toStringAsFixed(2));
        load = 96;
        timing = 9.5;
        if (rpm >= 6000) { phase = 'shift1'; phaseTimer = 0; }
      } else if (phase == 'shift1') {
        tps = 0;
        boostBar = -0.45;
        rpm = 3800;
        gear = '2';
        if (phaseTimer > 0.35) { phase = 'accel2'; phaseTimer = 0; }
      } else if (phase == 'accel2') {
        tps = 100;
        gear = '2';
        rpm = min(6100, (3800 + phaseTimer * 1150).round());
        speed = (48 + (phaseTimer * 24)).round();
        boostBar = double.parse((1.20 + sin(simTime * 2) * 0.05).toStringAsFixed(2));
        load = 98;
        timing = 11.0;
        if (rpm >= 6000) { phase = 'cruise'; phaseTimer = 0; }
      } else if (phase == 'cruise') {
        tps = 24;
        gear = '4';
        speed = 80;
        rpm = 2100;
        boostBar = -0.38;
        load = 32;
        timing = 24.5;
        if (phaseTimer > 4.0) { phase = 'idle'; phaseTimer = 0; }
      }

      final boostPsi = double.parse((boostBar * 14.5038).toStringAsFixed(1));
      final stft = double.parse((sin(simTime * 1.5) * 2.5).toStringAsFixed(1));
      final volt = double.parse((14.1 + sin(simTime) * 0.15).toStringAsFixed(1));

      _data = _data.copyWith(
        rpm: rpm,
        speed: speed,
        mapKpa: (101 + (boostBar * 100)).round(),
        boostBar: boostBar,
        boostPsi: boostPsi,
        peakBoostBar: max(_peakBoost, boostBar),
        tps: tps,
        engineLoad: load,
        timingAdvance: timing,
        stft: stft,
        ltft: 1.2,
        voltage: volt,
        gear: gear,
      );

      notifyListeners();
    });
  }

  // Scan DTCs (Mode 03)
  Future<List<String>> scanDTCs() async {
    if (_data.isSimulating) {
      return [];
    }

    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Dispositivo Bluetooth não conectado');
    }

    final raw = await _sendCommand('03', delayMs: 1200);
    final clean = raw.replaceAll(RegExp(r'[\r\n\t> ]'), '').toUpperCase();
    final List<String> codes = [];

    if (clean.contains('4300') || clean == '43') {
      _data = _data.copyWith(dtcs: []);
      notifyListeners();
      return [];
    }

    final match = RegExp(r'43([0-9A-F]+)').firstMatch(clean);
    if (match != null) {
      final hex = match.group(1)!;
      for (int i = 0; i + 4 <= hex.length; i += 4) {
        final b1 = int.parse(hex.substring(i, i + 2), radix: 16);
        final b2 = hex.substring(i + 2, i + 4);
        if (b1 == 0 && int.parse(b2, radix: 16) == 0) continue;

        const prefixes = ['P', 'C', 'B', 'U'];
        final p = prefixes[(b1 >> 6) & 0x03];
        final d1 = (b1 >> 4) & 0x03;
        final d2 = (b1 & 0x0F).toRadixString(16).toUpperCase();
        final code = '$p$d1$d2${b2.toUpperCase()}';
        if (!codes.contains(code)) codes.add(code);
      }
    }

    _data = _data.copyWith(dtcs: codes);
    notifyListeners();
    return codes;
  }

  // Clear DTCs (Mode 04)
  Future<void> clearDTCs() async {
    if (_data.isSimulating) {
      _data = _data.copyWith(dtcs: []);
      notifyListeners();
      return;
    }

    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Dispositivo Bluetooth não conectado');
    }

    await _sendCommand('04', delayMs: 1000);
    _data = _data.copyWith(dtcs: []);
    notifyListeners();
  }

  // Disconnect helper
  void disconnect() {
    _isPolling = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _simulationTimer?.cancel();
    _simulationTimer = null;

    try {
      _connection?.dispose();
    } catch (_) {}
    _connection = null;

    _status = BluetoothStateStatus.disconnected;
    _statusMessage = 'Desconectado';
    _data = const TelemetryData();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
