import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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

class ObdLogEntry {
  final DateTime timestamp;
  final String command;
  final String rawResponse;
  final String cleanResponse;
  final int latencyMs;
  final bool success;

  ObdLogEntry({
    required this.timestamp,
    required this.command,
    required this.rawResponse,
    required this.cleanResponse,
    required this.latencyMs,
    required this.success,
  });

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toLogLine() {
    final escapedRaw = rawResponse.replaceAll('\r', '\\r').replaceAll('\n', '\\n');
    return '[$timeFormatted] [${latencyMs}ms] TX: $command | RX: $escapedRaw';
  }
}

class ObdBluetoothService extends ChangeNotifier {
  BluetoothConnection? _connection;
  BluetoothDevice? _selectedDevice;
  BluetoothStateStatus _status = BluetoothStateStatus.disconnected;
  String _statusMessage = 'Desconectado';
  TelemetryData _data = const TelemetryData();

  bool _isPolling = false;
  double _peakBoost = 0.0;
  double _dynamicPeakBoost = 0.0;
  DateTime _dynamicPeakTimestamp = DateTime.now();
  int _shiftRpm = 5200;

  Completer<String>? _currentCompleter;
  final StringBuffer _rxAccumulator = StringBuffer();
  final List<ObdLogEntry> _logs = [];

  Timer? _simulationTimer;

  BluetoothStateStatus get status => _status;
  String get statusMessage => _statusMessage;
  TelemetryData get data => _data;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _data.isConnected;
  bool get isSimulating => _data.isSimulating;
  List<ObdLogEntry> get logs => List.unmodifiable(_logs);
  int get shiftRpm => _shiftRpm;
  double get dynamicPeakBoost => _dynamicPeakBoost;

  void setShiftRpm(int rpm) {
    _shiftRpm = rpm;
    _data = _data.copyWith(shiftRpm: rpm);
    notifyListeners();
  }

  void _updateDynamicPeak(double currentBoost) {
    final now = DateTime.now();
    if (currentBoost >= _dynamicPeakBoost) {
      _dynamicPeakBoost = currentBoost;
      _dynamicPeakTimestamp = now;
    } else {
      final elapsed = now.difference(_dynamicPeakTimestamp);
      if (elapsed.inSeconds >= 120) {
        // Após 2 minutos sem superar o valor máximo, reduz suavemente em direção ao boost atual
        _dynamicPeakBoost = max(currentBoost, _dynamicPeakBoost - 0.015);
      }
    }
  }

  double get avgLatencyMs {
    if (_logs.isEmpty) return 0.0;
    final recent = _logs.reversed.take(15);
    return recent.map((e) => e.latencyMs).reduce((a, b) => a + b) / recent.length;
  }

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

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  String exportLogsAsText() {
    final sb = StringBuffer();
    sb.writeln('=== UP! TSI TELEMETRY OBDII RAW LOG ===');
    sb.writeln('Data: ${DateTime.now().toIso8601String()}');
    sb.writeln('Dispositivo: ${_selectedDevice?.name ?? "N/A"} (${_selectedDevice?.address ?? "N/A"})');
    sb.writeln('Protocolo: ${_data.protocol}');
    sb.writeln('Total de Transações: ${_logs.length}');
    sb.writeln('----------------------------------------');
    for (final l in _logs) {
      sb.writeln(l.toLogLine());
    }
    sb.writeln('========================================');
    return sb.toString();
  }

  Future<String?> saveLogToFile() async {
    try {
      final text = exportLogsAsText();
      final dir = Directory('/sdcard/Download');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File('/sdcard/Download/obd_log_uptsi.txt');
      await file.writeAsString(text);
      return file.path;
    } catch (e) {
      debugPrint('Erro ao salvar log: $e');
      return null;
    }
  }

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

      // Initialize ELM327 protocol with optimal settings
      await _sendCommand('ATZ', timeout: const Duration(milliseconds: 1200));
      await Future.delayed(const Duration(milliseconds: 500));
      await _sendCommand('ATE0'); // Echo Off
      await _sendCommand('ATL0'); // Linefeeds Off
      await _sendCommand('ATS0'); // Spaces Off (Faster parsing!)
      await _sendCommand('ATH0'); // Headers Off
      await _sendCommand('ATAT2'); // Fast Adaptive Timing
      await _sendCommand('ATST32'); // Fast Timeout (~200ms)
      await _sendCommand('ATSP0'); // Auto Protocol (CAN 11/500)

      // Query Battery Voltage & Protocol
      final voltResp = await _sendCommand('ATRV');
      final protoResp = await _sendCommand('ATDP');
      await _sendCommand('0100'); // Probe supported PIDs to wake up ECU

      double initialVolt = 12.3;
      final voltMatch = RegExp(r'(\d+\.?\d*)V', caseSensitive: false).firstMatch(voltResp);
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
    final text = ascii.decode(bytes, allowInvalid: true);
    _rxAccumulator.write(text);

    // ELM327 responds and terminates strictly with '>' prompt
    if (text.contains('>') || _rxAccumulator.toString().contains('>')) {
      final fullResponse = _rxAccumulator.toString();
      _rxAccumulator.clear();
      if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
        _currentCompleter!.complete(fullResponse);
      }
    }
  }

  String _cleanResponse(String raw) {
    return raw.replaceAll(RegExp(r'[\r\n\t> ]'), '').toUpperCase();
  }

  Future<String> _sendCommand(String cmd, {Duration timeout = const Duration(milliseconds: 600)}) async {
    if (_connection == null || !_connection!.isConnected) return '';

    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete('');
    }

    _rxAccumulator.clear();
    final completer = Completer<String>();
    _currentCompleter = completer;

    final stopwatch = Stopwatch()..start();
    try {
      _connection!.output.add(ascii.encode('$cmd\r'));
      await _connection!.output.allSent;

      final rawResponse = await completer.future.timeout(timeout, onTimeout: () {
        final partial = _rxAccumulator.toString();
        _rxAccumulator.clear();
        return partial.isNotEmpty ? partial : 'TIMEOUT';
      });
      stopwatch.stop();

      final clean = _cleanResponse(rawResponse);
      final isSuccess = !clean.contains('ERROR') &&
          !clean.contains('TIMEOUT') &&
          !clean.contains('NODATA') &&
          !clean.contains('?');

      if (_logs.length >= 250) {
        _logs.removeAt(0);
      }
      _logs.add(ObdLogEntry(
        timestamp: DateTime.now(),
        command: cmd,
        rawResponse: rawResponse.trim(),
        cleanResponse: clean,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: isSuccess,
      ));
      notifyListeners();

      return rawResponse;
    } catch (e) {
      stopwatch.stop();
      if (_logs.length >= 250) _logs.removeAt(0);
      _logs.add(ObdLogEntry(
        timestamp: DateTime.now(),
        command: cmd,
        rawResponse: 'ERROR: $e',
        cleanResponse: 'ERROR',
        latencyMs: stopwatch.elapsedMilliseconds,
        success: false,
      ));
      notifyListeners();
      return '';
    } finally {
      if (_currentCompleter == completer) {
        _currentCompleter = null;
      }
    }
  }

  Future<String> sendManualCommand(String cmd) async {
    if (!_data.isConnected) {
      return 'NÃO CONECTADO AO OBDII';
    }
    return await _sendCommand(cmd, timeout: const Duration(seconds: 1));
  }

  // Real-time sequential OBD polling loop (NO OVERLAPPING TIMERS)
  void _startPollingLoop() async {
    _isPolling = true;
    int cycle = 0;

    while (_isPolling && _connection != null && _connection!.isConnected) {
      cycle++;
      try {
        await _pollCycle(cycle);
      } catch (e) {
        debugPrint('Erro no loop OBD: $e');
      }
      // Small pause between cycles (15ms)
      await Future.delayed(const Duration(milliseconds: 15));
    }
  }

  Future<void> _pollCycle(int cycle) async {
    // 1. High Priority: RPM (010C)
    final rpmRaw = await _sendCommand('010C');
    final rpmClean = _cleanResponse(rpmRaw);
    final rpmMatch = RegExp(r'410C([0-9A-F]{4})').firstMatch(rpmClean);
    int rpm = _data.rpm;
    if (rpmMatch != null) {
      final val = int.tryParse(rpmMatch.group(1)!, radix: 16);
      if (val != null) {
        final calcRpm = (val / 4).round();
        if (calcRpm >= 0 && calcRpm <= 8000) rpm = calcRpm;
      }
    }

    // 2. High Priority: MAP & Boost (010B)
    final mapRaw = await _sendCommand('010B');
    final mapClean = _cleanResponse(mapRaw);
    final mapMatch = RegExp(r'410B([0-9A-F]{2})').firstMatch(mapClean);
    int mapKpa = _data.mapKpa;
    double boostBar = _data.boostBar;
    double boostPsi = _data.boostPsi;

    if (mapMatch != null) {
      final val = int.tryParse(mapMatch.group(1)!, radix: 16);
      if (val != null && val > 0) {
        mapKpa = val;
        // Atmospheric reference: 101 kPa
        boostBar = double.parse(((mapKpa - 101) / 100.0).toStringAsFixed(2));
        boostPsi = double.parse((boostBar * 14.5038).toStringAsFixed(1));
        if (boostBar > _peakBoost) _peakBoost = boostBar;
      }
    }

    // 3. High Priority: Speed (010D) & TPS (0111)
    final speedRaw = await _sendCommand('010D');
    final speedClean = _cleanResponse(speedRaw);
    final speedMatch = RegExp(r'410D([0-9A-F]{2})').firstMatch(speedClean);
    int speed = _data.speed;
    if (speedMatch != null) {
      final val = int.tryParse(speedMatch.group(1)!, radix: 16);
      if (val != null && val >= 0 && val <= 300) speed = val;
    }

    final tpsRaw = await _sendCommand('0111');
    final tpsClean = _cleanResponse(tpsRaw);
    final tpsMatch = RegExp(r'4111([0-9A-F]{2})').firstMatch(tpsClean);
    int tps = _data.tps;
    if (tpsMatch != null) {
      final val = int.tryParse(tpsMatch.group(1)!, radix: 16);
      if (val != null) tps = ((val * 100) / 255).round();
    }

    // 4. Medium Priority (every 3 cycles): Load (0104) and Timing (010E)
    int load = _data.engineLoad;
    double timing = _data.timingAdvance;
    if (cycle % 3 == 0) {
      final loadRaw = await _sendCommand('0104');
      final loadClean = _cleanResponse(loadRaw);
      final loadMatch = RegExp(r'4104([0-9A-F]{2})').firstMatch(loadClean);
      if (loadMatch != null) {
        final val = int.tryParse(loadMatch.group(1)!, radix: 16);
        if (val != null) load = ((val * 100) / 255).round();
      }

      final timingRaw = await _sendCommand('010E');
      final timingClean = _cleanResponse(timingRaw);
      final timingMatch = RegExp(r'410E([0-9A-F]{2})').firstMatch(timingClean);
      if (timingMatch != null) {
        final val = int.tryParse(timingMatch.group(1)!, radix: 16);
        if (val != null) timing = (val / 2) - 64;
      }
    }

    // 5. Low Priority (every 6 cycles): Coolant (0105), IAT (010F), Fuel Trims, Voltage (ATRV)
    int coolant = _data.coolant;
    int iat = _data.iat;
    double stft = _data.stft;
    double ltft = _data.ltft;
    double voltage = _data.voltage;

    if (cycle % 6 == 0) {
      final coolRaw = await _sendCommand('0105');
      final coolClean = _cleanResponse(coolRaw);
      final coolMatch = RegExp(r'4105([0-9A-F]{2})').firstMatch(coolClean);
      if (coolMatch != null) {
        final val = int.tryParse(coolMatch.group(1)!, radix: 16);
        if (val != null) coolant = val - 40;
      }

      final iatRaw = await _sendCommand('010F');
      final iatClean = _cleanResponse(iatRaw);
      final iatMatch = RegExp(r'410F([0-9A-F]{2})').firstMatch(iatClean);
      if (iatMatch != null) {
        final val = int.tryParse(iatMatch.group(1)!, radix: 16);
        if (val != null) iat = val - 40;
      }

      final voltRaw = await _sendCommand('ATRV');
      final voltMatch = RegExp(r'(\d+\.?\d*)V', caseSensitive: false).firstMatch(voltRaw);
      if (voltMatch != null) {
        voltage = double.tryParse(voltMatch.group(1)!) ?? voltage;
      }
    }

    _updateDynamicPeak(boostBar);

    _data = _data.copyWith(
      rpm: rpm,
      speed: speed,
      mapKpa: mapKpa,
      boostBar: boostBar,
      boostPsi: boostPsi,
      peakBoostBar: _peakBoost,
      dynamicPeakBoostBar: _dynamicPeakBoost,
      shiftRpm: _shiftRpm,
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
  }

  // Gear estimation for Up! TSI (MQ200 5-speed manual)
  // Relações Up! TSI: 1ª 3.769, 2ª 2.095, 3ª 1.281, 4ª 0.927, 5ª 0.740, Dif 3.625
  // Relações teóricas RPM / km/h: 1ª ~120, 2ª ~66.8, 3ª ~40.8, 4ª ~29.6, 5ª ~23.6
  String _estimateGear(int speed, int rpm) {
    if (rpm < 550 || speed < 3) return 'N';
    final ratio = rpm / speed;
    if (ratio > 88) return '1';
    if (ratio > 53) return '2';
    if (ratio > 35) return '3';
    if (ratio > 26.5) return '4';
    if (ratio > 17) return '5';
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

      _updateDynamicPeak(boostBar);

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
        dynamicPeakBoostBar: _dynamicPeakBoost,
        shiftRpm: _shiftRpm,
        tps: tps,
        engineLoad: load,
        timingAdvance: timing,
        stft: stft,
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

    final raw = await _sendCommand('03', timeout: const Duration(seconds: 2));
    final clean = _cleanResponse(raw);
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

    await _sendCommand('04', timeout: const Duration(seconds: 2));
    _data = _data.copyWith(dtcs: []);
    notifyListeners();
  }

  // Disconnect helper
  void disconnect() {
    _isPolling = false;
    _simulationTimer?.cancel();
    _simulationTimer = null;

    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter!.complete('');
      _currentCompleter = null;
    }
    _rxAccumulator.clear();

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
