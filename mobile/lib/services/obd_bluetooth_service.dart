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
  bool _autoReconnectAttempted = false;
  final Set<String> _supportedPids = {};
  int _barometricKpa = 101;
  double _peakBoost = 0.0;
  double _dynamicPeakBoost = 0.0;
  DateTime _dynamicPeakTimestamp = DateTime.now();
  int _shiftRpm = 5200;
  int _peakHoldSeconds = 10; // Default 10 seconds (configurable)
  String _vehicleProfile = 'VW TSI Universal';

  Completer<String>? _currentCompleter;
  final StringBuffer _rxAccumulator = StringBuffer();
  final List<ObdLogEntry> _logs = [];
  final List<String> _pendingLogLines = [];
  File? _activeLogFile;
  Timer? _logFlushTimer;

  Timer? _simulationTimer;

  BluetoothStateStatus get status => _status;
  String get statusMessage => _statusMessage;
  TelemetryData get data => _data;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _data.isConnected;
  bool get isSimulating => _data.isSimulating;
  List<ObdLogEntry> get logs => List.unmodifiable(_logs);
  String? get activeLogFilePath => _activeLogFile?.path;
  int get shiftRpm => _shiftRpm;
  int get peakHoldSeconds => _peakHoldSeconds;
  String get vehicleProfile => _vehicleProfile;
  double get dynamicPeakBoost => _dynamicPeakBoost;

  double _peakHp = 0.0;
  double _peakTorqueKgfm = 0.0;
  double _totalFuelConsumedLiters = 0.0;
  double _tripDistanceKm = 0.0;
  DateTime _tripStartTime = DateTime.now();
  double _fuelPricePerLiter = 5.89;
  int _misfiresCyl1 = 0;
  int _misfiresCyl2 = 0;
  int _misfiresCyl3 = 0;
  int _misfiresCyl4 = 0;
  int _misfiresCyl5 = 0;
  int _misfiresCyl6 = 0;

  double get peakHp => _peakHp;
  double get peakTorqueKgfm => _peakTorqueKgfm;
  double get totalFuelConsumedLiters => _totalFuelConsumedLiters;
  double get tripDistanceKm => _tripDistanceKm;
  double get fuelPricePerLiter => _fuelPricePerLiter;

  void setShiftRpm(int rpm) {
    _shiftRpm = rpm;
    _data = _data.copyWith(shiftRpm: rpm);
    notifyListeners();
  }

  void setPeakHoldSeconds(int seconds) {
    _peakHoldSeconds = seconds;
    notifyListeners();
  }

  double _baseOdometer = 64250.0;
  double get baseOdometer => _baseOdometer;

  void setBaseOdometer(double km) {
    _baseOdometer = km;
    _data = _data.copyWith(
      odometerKm: km + _tripDistanceKm,
      odometerSource: 'Calibrado Manualmente',
    );
    notifyListeners();
  }

  void setFuelPrice(double price) {
    _fuelPricePerLiter = price;
    _data = _data.copyWith(fuelPricePerLiter: price);
    notifyListeners();
  }

  void resetTrip() {
    _tripDistanceKm = 0.0;
    _totalFuelConsumedLiters = 0.0;
    _tripStartTime = DateTime.now();
    _data = _data.copyWith(
      tripDistanceKm: 0.0,
      totalFuelConsumedLiters: 0.0,
      tripDurationMinutes: 0.0,
      avgFuelConsumptionKml: 0.0,
    );
    notifyListeners();
  }

  void resetPowerPeaks() {
    _peakHp = 0.0;
    _peakTorqueKgfm = 0.0;
    _data = _data.copyWith(peakHp: 0.0, peakTorqueKgfm: 0.0);
    notifyListeners();
  }

  void clearMisfires() {
    _misfiresCyl1 = 0;
    _misfiresCyl2 = 0;
    _misfiresCyl3 = 0;
    _misfiresCyl4 = 0;
    _misfiresCyl5 = 0;
    _misfiresCyl6 = 0;
    _data = _data.copyWith(
      misfiresCyl1: 0,
      misfiresCyl2: 0,
      misfiresCyl3: 0,
      misfiresCyl4: 0,
      misfiresCyl5: 0,
      misfiresCyl6: 0,
    );
    notifyListeners();
  }

  void setVehicleProfile(String profile) {
    _vehicleProfile = profile;
    if (profile.contains('1.0 TSI')) {
      _shiftRpm = 5200;
    } else if (profile.contains('1.4 TSI')) {
      _shiftRpm = 5500;
    } else if (profile.contains('2.0 TSI')) {
      _shiftRpm = 6000;
    } else if (profile.contains('Sorento') || profile.contains('3.5 V6')) {
      _shiftRpm = 6200;
    }
    _data = _data.copyWith(vehicleProfile: profile, shiftRpm: _shiftRpm);
    notifyListeners();
  }

  void _updateDynamicPeak(double currentBoost) {
    final now = DateTime.now();
    if (currentBoost >= _dynamicPeakBoost) {
      _dynamicPeakBoost = currentBoost;
      _dynamicPeakTimestamp = now;
    } else {
      final elapsed = now.difference(_dynamicPeakTimestamp);
      if (elapsed.inSeconds >= _peakHoldSeconds) {
        // Após o tempo de retenção sem superar o valor máximo, reduz suavemente em direção ao boost atual
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
    sb.writeln('=== VW TSI TELEMETRY OBDII RAW LOG ===');
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

  File? _resolveWritableLogFile(String filename) {
    final candidateDirs = [
      '/sdcard/Download',
      '/sdcard/Android/data/com.antigravity.uptsi/files/obd_logs',
      '/data/user/0/com.antigravity.uptsi/files/obd_logs',
    ];
    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        final file = File('$dirPath/$filename');
        // Testa permissão de escrita criando/abrindo o arquivo
        file.writeAsStringSync('', mode: FileMode.append, flush: true);
        return file;
      } catch (_) {}
    }
    return null;
  }

  void _initSessionLogFile(BluetoothDevice device) {
    _flushPendingLogsSync();
    _logFlushTimer?.cancel();

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    _activeLogFile = _resolveWritableLogFile('obd_raw_log_$stamp.txt');
    if (_activeLogFile != null) {
      final header = StringBuffer()
        ..writeln('=== VW TSI TELEMETRY OBDII RAW LOG (AUTO-LOGGER) ===')
        ..writeln('Inicio: ${now.toIso8601String()}')
        ..writeln('Dispositivo: ${device.name ?? "N/A"} (${device.address})')
        ..writeln('Perfil Ativo: $_vehicleProfile')
        ..writeln('----------------------------------------');
      try {
        _activeLogFile!.writeAsStringSync(header.toString(), mode: FileMode.append, flush: true);
      } catch (e) {
        debugPrint('Erro ao escrever cabeçalho do log bruto: $e');
      }
      _logFlushTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _flushPendingLogsSync();
      });
    }
  }

  void _queueLogLine(ObdLogEntry entry) {
    if (_activeLogFile == null) return;
    _pendingLogLines.add(entry.toLogLine());
    if (_pendingLogLines.length >= 25) {
      _flushPendingLogsSync();
    }
  }

  void _flushPendingLogsSync() {
    if (_activeLogFile == null || _pendingLogLines.isEmpty) return;
    try {
      final chunk = '${_pendingLogLines.join('\n')}\n';
      _pendingLogLines.clear();
      _activeLogFile!.writeAsStringSync(chunk, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Erro ao gravar log bruto OBDII: $e');
    }
  }

  Future<String?> saveLogToFile() async {
    try {
      _flushPendingLogsSync();
      if (_activeLogFile != null && _activeLogFile!.existsSync()) {
        return _activeLogFile!.path;
      }
      final text = exportLogsAsText();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final file = _resolveWritableLogFile('obd_raw_log_$stamp.txt');
      if (file == null) return null;
      await file.writeAsString(text, flush: true);
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

  File _getLastDeviceFile() {
    final candidateDirs = [
      '/data/user/0/com.antigravity.uptsi/files',
      '/data/data/com.antigravity.uptsi/files',
    ];
    for (final d in candidateDirs) {
      try {
        final dir = Directory(d);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('${dir.path}/last_obd_device_v1.json');
      } catch (_) {}
    }
    return File('${Directory.systemTemp.path}/last_obd_device_v1.json');
  }

  Future<void> _saveLastDevice(BluetoothDevice device) async {
    try {
      final file = _getLastDeviceFile();
      final payload = {
        'address': device.address,
        'name': device.name ?? 'OBDII',
        'savedAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (e) {
      debugPrint('Erro ao salvar último dispositivo OBDII: $e');
    }
  }

  Future<Map<String, String>?> _loadLastDevice() async {
    try {
      final file = _getLastDeviceFile();
      if (!file.existsSync()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final Map<String, dynamic> decoded = jsonDecode(raw);
      final address = decoded['address'] as String?;
      if (address == null || address.isEmpty) return null;
      return {
        'address': address,
        'name': (decoded['name'] as String?) ?? 'OBDII',
      };
    } catch (e) {
      debugPrint('Erro ao carregar último dispositivo OBDII: $e');
      return null;
    }
  }

  /// Tenta reconectar automaticamente ao último adaptador OBDII Bluetooth conectado
  Future<void> tryAutoReconnect() async {
    if (_autoReconnectAttempted) return;
    _autoReconnectAttempted = true;

    if (kIsWeb || !Platform.isAndroid) return;
    if (isConnected || isSimulating) return;
    if (_status == BluetoothStateStatus.connecting ||
        _status == BluetoothStateStatus.initializing) {
      return;
    }

    final last = await _loadLastDevice();
    if (last == null) return;

    final address = last['address']!;
    final name = last['name'] ?? 'OBDII';

    try {
      final hasPerm = await requestPermissions();
      if (!hasPerm) return;

      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) return;

      final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
      BluetoothDevice? target;
      for (final d in bonded) {
        if (d.address == address) {
          target = d;
          break;
        }
      }
      target ??= BluetoothDevice(address: address, name: name);

      await connect(target);
    } catch (e) {
      debugPrint('Reconexão automática não concluída: $e');
    }
  }

  Future<void> _loadSavedBaseOdometer() async {
    final candidateFiles = [
      '/data/user/0/com.antigravity.uptsi/files/fuel_log_v1.json',
      '/data/data/com.antigravity.uptsi/files/fuel_log_v1.json',
    ];
    for (final path in candidateFiles) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final raw = await file.readAsString();
          if (raw.isNotEmpty) {
            final Map<String, dynamic> decoded = jsonDecode(raw);
            final saved = (decoded['baseOdometer'] as num?)?.toDouble();
            if (saved != null && saved > 0) {
              _baseOdometer = saved;
              return;
            }
          }
        }
      } catch (_) {}
    }
  }

  void _parseSupportedPidBitmask(int base, String raw) {
    final clean = _cleanResponse(raw);
    final baseHex = base.toRadixString(16).toUpperCase().padLeft(2, '0');
    final match = RegExp('41$baseHex([0-9A-F]{8})').firstMatch(clean);
    if (match == null) return;
    final val = int.tryParse(match.group(1)!, radix: 16);
    if (val == null) return;
    for (int i = 0; i < 32; i++) {
      if ((val & (1 << (31 - i))) != 0) {
        final pidHex = (base + i + 1).toRadixString(16).toUpperCase().padLeft(2, '0');
        _supportedPids.add(pidHex);
      }
    }
  }

  String? _parseVinResponse(String raw) {
    final clean = _cleanResponse(raw);
    // Remove prefixos de frame ISO-TP (ex: 014, 0:, 1:, 2:) e busca 490201
    final stripped = clean.replaceAll(RegExp(r'^[0-9A-F]{3}(?=0:)'), '').replaceAll(RegExp(r'[0-9]:'), '');
    final idx = stripped.indexOf('490201');
    if (idx == -1) return null;
    final hexVin = stripped.substring(idx + 6);
    final sb = StringBuffer();
    for (int i = 0; i + 2 <= hexVin.length && sb.length < 17; i += 2) {
      final code = int.tryParse(hexVin.substring(i, i + 2), radix: 16);
      if (code != null && code >= 0x30 && code <= 0x5A) {
        sb.writeCharCode(code);
      }
    }
    final vin = sb.toString();
    return vin.length >= 11 ? vin : null;
  }

  /// Sonda experimental UDS para tentar ler odômetro no módulo do Painel VW (Cluster 714/77E)
  Future<String> probeVwClusterOdometer() async {
    if (!_data.isConnected) return 'NÃO CONECTADO AO OBDII';
    final wasPolling = _isPolling;
    _isPolling = false;
    await Future.delayed(const Duration(milliseconds: 120));

    final sb = StringBuffer();
    try {
      sb.writeln(await _sendCommand('ATSH714'));
      sb.writeln(await _sendCommand('ATCRA77E'));
      sb.writeln(await _sendCommand('22F4A6', timeout: const Duration(milliseconds: 900)));
      sb.writeln(await _sendCommand('222203', timeout: const Duration(milliseconds: 900)));
      sb.writeln(await _sendCommand('220202', timeout: const Duration(milliseconds: 900)));
    } finally {
      await _sendCommand('ATCRA');
      await _sendCommand('ATSH7DF');
      if (wasPolling && _connection != null && _connection!.isConnected) {
        _startPollingLoop();
      }
    }
    return sb.toString();
  }

  // Connect to a Bluetooth OBD-II device
  Future<void> connect(BluetoothDevice device) async {
    disconnect();
    _selectedDevice = device;
    _status = BluetoothStateStatus.connecting;
    _statusMessage = 'Conectando a ${device.name ?? device.address}...';
    notifyListeners();

    try {
      await _loadSavedBaseOdometer();
      _supportedPids.clear();
      _barometricKpa = 101;

      _connection = await BluetoothConnection.toAddress(device.address);
      _initSessionLogFile(device);
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

      // Probe supported PID bitmasks, odometer & VIN
      _parseSupportedPidBitmask(0x00, await _sendCommand('0100'));
      if (_supportedPids.contains('20')) {
        _parseSupportedPidBitmask(0x20, await _sendCommand('0120'));
      }
      if (_supportedPids.contains('40')) {
        _parseSupportedPidBitmask(0x40, await _sendCommand('0140'));
      }
      if (_supportedPids.contains('60')) {
        _parseSupportedPidBitmask(0x60, await _sendCommand('0160'));
      }
      if (_supportedPids.contains('80')) {
        _parseSupportedPidBitmask(0x80, await _sendCommand('0180'));
      }
      if (_supportedPids.contains('A0')) {
        _parseSupportedPidBitmask(0xA0, await _sendCommand('01A0'));
      }
      if (_supportedPids.contains('A6')) {
        await _sendCommand('01A6');
      }
      if (_supportedPids.contains('31')) {
        await _sendCommand('0131');
      }
      final vinResp = await _sendCommand('0902', timeout: const Duration(milliseconds: 900));
      final parsedVin = _parseVinResponse(vinResp);

      double initialVolt = 12.3;
      final voltMatch = RegExp(r'(\d+\.?\d*)V', caseSensitive: false).firstMatch(voltResp);
      if (voltMatch != null) {
        initialVolt = double.tryParse(voltMatch.group(1) ?? '12.3') ?? 12.3;
      }

      _data = _data.copyWith(
        isConnected: true,
        isSimulating: false,
        voltage: initialVolt,
        vin: parsedVin ?? _data.vin,
        odometerKm: _baseOdometer,
        odometerSource: _supportedPids.contains('A6') ? 'ECU (PID 01A6)' : 'Odômetro Calibrado',
        protocol: protoResp.replaceAll(RegExp(r'[\r\n>]'), '').trim(),
      );

      _status = BluetoothStateStatus.connected;
      _statusMessage = 'Conectado à ECU VW TSI';
      await _saveLastDevice(device);
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
      final entry = ObdLogEntry(
        timestamp: DateTime.now(),
        command: cmd,
        rawResponse: rawResponse.trim(),
        cleanResponse: clean,
        latencyMs: stopwatch.elapsedMilliseconds,
        success: isSuccess,
      );
      _logs.add(entry);
      _queueLogLine(entry);
      notifyListeners();

      return rawResponse;
    } catch (e) {
      stopwatch.stop();
      if (_logs.length >= 250) _logs.removeAt(0);
      final errEntry = ObdLogEntry(
        timestamp: DateTime.now(),
        command: cmd,
        rawResponse: 'ERROR: $e',
        cleanResponse: 'ERROR',
        latencyMs: stopwatch.elapsedMilliseconds,
        success: false,
      );
      _logs.add(errEntry);
      _queueLogLine(errEntry);
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
        // Referência barométrica real (PID 0133 quando suportado, senão 101 kPa)
        boostBar = double.parse(((mapKpa - _barometricKpa) / 100.0).toStringAsFixed(2));
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

    // 4. Medium Priority (every 3 cycles): Load (0104), Timing (010E), Rail (0123), Lambda (0134)
    int load = _data.engineLoad;
    double timing = _data.timingAdvance;
    double? realRailBar;
    double? realLambda;
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

      if (_supportedPids.contains('23')) {
        final railRaw = await _sendCommand('0123');
        final railClean = _cleanResponse(railRaw);
        final railMatch = RegExp(r'4123([0-9A-F]{4})').firstMatch(railClean);
        if (railMatch != null) {
          final val = int.tryParse(railMatch.group(1)!, radix: 16);
          if (val != null) realRailBar = double.parse((val * 0.1).toStringAsFixed(1));
        }
      }

      if (_supportedPids.contains('34')) {
        final lbdRaw = await _sendCommand('0134');
        final lbdClean = _cleanResponse(lbdRaw);
        final lbdMatch = RegExp(r'4134([0-9A-F]{4})').firstMatch(lbdClean);
        if (lbdMatch != null) {
          final val = int.tryParse(lbdMatch.group(1)!, radix: 16);
          if (val != null && val > 0) {
            realLambda = double.parse(((2.0 / 65536.0) * val).toStringAsFixed(2));
          }
        }
      }
    }

    // 5. Low Priority (every 6 cycles): Coolant (0105), IAT (010F), STFT (0106), LTFT (0107), EGT (013C), Voltage (ATRV)
    int coolant = _data.coolant;
    int iat = _data.iat;
    double stft = _data.stft;
    double ltft = _data.ltft;
    double voltage = _data.voltage;
    int? realEgt;

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

      if (_supportedPids.contains('06')) {
        final stftRaw = await _sendCommand('0106');
        final stftClean = _cleanResponse(stftRaw);
        final stftMatch = RegExp(r'4106([0-9A-F]{2})').firstMatch(stftClean);
        if (stftMatch != null) {
          final val = int.tryParse(stftMatch.group(1)!, radix: 16);
          if (val != null) stft = double.parse((((val - 128) * 100.0) / 128.0).toStringAsFixed(1));
        }
      }

      if (_supportedPids.contains('07')) {
        final ltftRaw = await _sendCommand('0107');
        final ltftClean = _cleanResponse(ltftRaw);
        final ltftMatch = RegExp(r'4107([0-9A-F]{2})').firstMatch(ltftClean);
        if (ltftMatch != null) {
          final val = int.tryParse(ltftMatch.group(1)!, radix: 16);
          if (val != null) ltft = double.parse((((val - 128) * 100.0) / 128.0).toStringAsFixed(1));
        }
      }

      if (_supportedPids.contains('3C')) {
        final egtRaw = await _sendCommand('013C');
        final egtClean = _cleanResponse(egtRaw);
        final egtMatch = RegExp(r'413C([0-9A-F]{4})').firstMatch(egtClean);
        if (egtMatch != null) {
          final val = int.tryParse(egtMatch.group(1)!, radix: 16);
          if (val != null) realEgt = ((val / 10.0) - 40.0).round();
        }
      }

      final voltRaw = await _sendCommand('ATRV');
      final voltMatch = RegExp(r'(\d+\.?\d*)V', caseSensitive: false).firstMatch(voltRaw);
      if (voltMatch != null) {
        voltage = double.tryParse(voltMatch.group(1)!) ?? voltage;
      }
    }

    // 6. Infrequent Priority (every 30 cycles ~ 15s): Baro (0133), Etanol (0152), Odômetro (01A6 se suportado), Distância pós-DTC (0131)
    double odoKm = _data.odometerKm > 0 ? _data.odometerKm : (_baseOdometer + _tripDistanceKm);
    String odoSource = _data.odometerSource;
    int distDtc = _data.distanceSinceDtcClearKm;
    int? realEthanol;

    if (cycle % 30 == 1) {
      if (_supportedPids.contains('33')) {
        final baroRaw = await _sendCommand('0133');
        final baroClean = _cleanResponse(baroRaw);
        final baroMatch = RegExp(r'4133([0-9A-F]{2})').firstMatch(baroClean);
        if (baroMatch != null) {
          final val = int.tryParse(baroMatch.group(1)!, radix: 16);
          if (val != null && val >= 50 && val <= 110) _barometricKpa = val;
        }
      }

      if (_supportedPids.contains('52')) {
        final ethRaw = await _sendCommand('0152');
        final ethClean = _cleanResponse(ethRaw);
        final ethMatch = RegExp(r'4152([0-9A-F]{2})').firstMatch(ethClean);
        if (ethMatch != null) {
          final val = int.tryParse(ethMatch.group(1)!, radix: 16);
          if (val != null) realEthanol = ((val * 100) / 255).round();
        }
      }

      if (_supportedPids.contains('A6')) {
        final odoRaw = await _sendCommand('01A6', timeout: const Duration(milliseconds: 600));
        final odoClean = _cleanResponse(odoRaw);
        final odoMatch = RegExp(r'41A6([0-9A-F]{8})').firstMatch(odoClean);
        if (odoMatch != null) {
          final hex = odoMatch.group(1)!;
          final rawVal = int.tryParse(hex, radix: 16);
          if (rawVal != null && rawVal > 0) {
            odoKm = double.parse((rawVal / 10.0).toStringAsFixed(1));
            odoSource = 'ECU (PID 01A6)';
            _baseOdometer = odoKm;
          }
        }
      } else {
        odoKm = double.parse((_baseOdometer + _tripDistanceKm).toStringAsFixed(1));
        if (odoSource != 'ECU (PID 01A6)') {
          odoSource = 'Odômetro Calibrado';
        }
      }

      if (_supportedPids.contains('31')) {
        final dtcDistRaw = await _sendCommand('0131', timeout: const Duration(milliseconds: 600));
        final dtcDistClean = _cleanResponse(dtcDistRaw);
        final dtcDistMatch = RegExp(r'4131([0-9A-F]{4})').firstMatch(dtcDistClean);
        if (dtcDistMatch != null) {
          final rawVal = int.tryParse(dtcDistMatch.group(1)!, radix: 16);
          if (rawVal != null) distDtc = rawVal;
        }
      }
    } else {
      if (odoSource != 'ECU (PID 01A6)') {
        odoKm = double.parse((_baseOdometer + _tripDistanceKm).toStringAsFixed(1));
      }
    }

    _updateDynamicPeak(boostBar);

    final adv = _computeAdvancedMetrics(
      speed: speed,
      rpm: rpm,
      mapKpa: mapKpa,
      boostBar: boostBar,
      load: load,
      tps: tps,
      timing: timing,
      coolant: coolant,
      iat: iat,
      dtSeconds: 0.1,
      realLambda: realLambda,
    );

    final double effectiveRail = realRailBar ?? (cycle % 3 == 0 ? adv['railBar'] : _data.fuelRailPressureBar);
    final double effectiveLambda = realLambda ?? (cycle % 3 == 0 ? adv['lambda'] : _data.lambda);
    final double effectiveAfr = realLambda != null
        ? double.parse((realLambda * 14.7).toStringAsFixed(1))
        : (cycle % 3 == 0 ? adv['afr'] : _data.afr);
    final int effectiveEgt = realEgt ?? (cycle % 6 == 0 ? adv['egt'] : _data.egt);
    final int effectiveEthanol = realEthanol ?? (cycle % 30 == 1 ? adv['ethanol'] : _data.ethanolPercent);

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
      estimatedHp: adv['hp'],
      estimatedTorqueNm: adv['torqueNm'],
      estimatedTorqueKgfm: adv['torqueKgfm'],
      peakHp: adv['peakHp'],
      peakTorqueKgfm: adv['peakTorqueKgfm'],
      fuelRailPressureBar: effectiveRail,
      lambda: effectiveLambda,
      afr: effectiveAfr,
      oilTemperature: adv['oilTemp'],
      egt: effectiveEgt,
      fuelConsumptionLh: adv['fuelLh'],
      fuelConsumptionKml: adv['fuelKml'],
      avgFuelConsumptionKml: adv['avgKml'],
      totalFuelConsumedLiters: adv['totalFuel'],
      tripDistanceKm: adv['tripKm'],
      tripDurationMinutes: adv['tripMinutes'],
      ethanolPercent: effectiveEthanol,
      odometerKm: odoKm,
      odometerSource: odoSource,
      distanceSinceDtcClearKm: distDtc,
      longitudinalGForce: adv['gLong'],
      lateralGForce: adv['gLat'],
      misfiresCyl1: _misfiresCyl1,
      misfiresCyl2: _misfiresCyl2,
      misfiresCyl3: _misfiresCyl3,
      misfiresCyl4: _misfiresCyl4,
      misfiresCyl5: _misfiresCyl5,
      misfiresCyl6: _misfiresCyl6,
    );

    notifyListeners();
  }

  Map<String, dynamic> _computeAdvancedMetrics({
    required int speed,
    required int rpm,
    required int mapKpa,
    required double boostBar,
    required int load,
    required int tps,
    required double timing,
    required int coolant,
    required int iat,
    required double dtSeconds,
    double? realLambda,
  }) {
    // 1. Motor displacement & Max limits according to profile
    final double disp = (_vehicleProfile.contains('Sorento') || _vehicleProfile.contains('3.5 V6'))
        ? 3.470
        : (_vehicleProfile.contains('2.0 TSI')
            ? 1.984
            : (_vehicleProfile.contains('1.4 TSI') ? 1.395 : 0.999));
    final double maxHpCap = (_vehicleProfile.contains('Sorento') || _vehicleProfile.contains('3.5 V6'))
        ? 290.0
        : (_vehicleProfile.contains('2.0 TSI')
            ? 260.0
            : (_vehicleProfile.contains('1.4 TSI') ? 175.0 : 135.0));

    // 2. Airflow & Virtual Dyno
    final double absKpa = max(25.0, mapKpa.toDouble());
    final double ve = (0.82 + (boostBar > 0 ? boostBar * 0.32 : 0.0)).clamp(0.65, 1.40);
    final double airGramsPerSec = (absKpa * 1000.0 * (rpm / 120.0) * (disp * 0.001) * ve) /
        (287.05 * (max(10, iat) + 273.15)) * 1000.0;

    // Potência instantânea (CV)
    final double hp = rpm > 550
        ? ((airGramsPerSec / 0.81) * (1.0 + (timing > 10 ? (timing - 10) * 0.015 : 0.0))).clamp(0.0, maxHpCap)
        : 0.0;
    _peakHp = max(_peakHp, hp);

    // Torque instantâneo (kgfm e Nm)
    final double torqueKgfm = (rpm > 550 && hp > 0)
        ? ((hp * 716.2) / rpm).clamp(0.0, maxHpCap * 0.22)
        : 0.0;
    final double torqueNm = torqueKgfm * 9.80665;
    _peakTorqueKgfm = max(_peakTorqueKgfm, torqueKgfm);

    // 3. High Pressure Rail (HPFP 40 a 200 bar)
    final double railBar = (45.0 + (load * 1.15) + (boostBar > 0 ? boostBar * 45.0 : 0.0)).clamp(40.0, 210.0);

    // 4. Sonda Lambda & AFR
    final double lambda = realLambda ??
        ((tps < 3 && rpm > 1700)
            ? 1.25 // Cut-off freio motor
            : (load > 80 ? (0.83 + sin(rpm * 0.001) * 0.02) : (1.00 + sin(rpm * 0.002) * 0.01)));
    final double afr = lambda * 14.7;

    // 5. Temperaturas (Óleo e EGT)
    final int oilTemp = coolant > 0 ? (coolant + 4).clamp(70, 125) : 92;
    final int egt = (360 + (load * 3.5) + (boostBar > 0 ? boostBar * 190.0 : 0.0)).round().clamp(350, 940);

    // 6. Consumo de Combustível (km/L & L/h)
    final double fuelLh = (airGramsPerSec * 3600.0) / (afr * 745.0);
    final double fuelKml = speed > 2 ? (speed / max(0.2, fuelLh)).clamp(0.0, 35.0) : 0.0;

    // Integração da Viagem (Trip)
    _tripDistanceKm += (speed / 3600.0) * dtSeconds;
    _totalFuelConsumedLiters += (fuelLh / 3600.0) * dtSeconds;
    final double avgKml = _totalFuelConsumedLiters > 0.005
        ? (_tripDistanceKm / _totalFuelConsumedLiters).clamp(0.0, 32.0)
        : 0.0;
    final double tripMinutes = DateTime.now().difference(_tripStartTime).inSeconds / 60.0;

    // 7. Teor de Etanol (Flex)
    final int ethanol = (_vehicleProfile.contains('2.0 TSI') || _vehicleProfile.contains('Sorento')) ? 27 : 85;

    // 8. Força G
    final double accelMs2 = (speed / 3.6) * 0.05;
    final double gLong = (accelMs2 / 9.81).clamp(-1.2, 1.2);
    final double gLat = (sin(speed * 0.05) * 0.25).clamp(-1.2, 1.2);

    return {
      'hp': double.parse(hp.toStringAsFixed(1)),
      'torqueNm': double.parse(torqueNm.toStringAsFixed(1)),
      'torqueKgfm': double.parse(torqueKgfm.toStringAsFixed(1)),
      'peakHp': double.parse(_peakHp.toStringAsFixed(1)),
      'peakTorqueKgfm': double.parse(_peakTorqueKgfm.toStringAsFixed(1)),
      'railBar': double.parse(railBar.toStringAsFixed(1)),
      'lambda': double.parse(lambda.toStringAsFixed(2)),
      'afr': double.parse(afr.toStringAsFixed(1)),
      'oilTemp': oilTemp,
      'egt': egt,
      'fuelLh': double.parse(fuelLh.toStringAsFixed(1)),
      'fuelKml': double.parse(fuelKml.toStringAsFixed(1)),
      'avgKml': double.parse(avgKml.toStringAsFixed(1)),
      'totalFuel': double.parse(_totalFuelConsumedLiters.toStringAsFixed(2)),
      'tripKm': double.parse(_tripDistanceKm.toStringAsFixed(2)),
      'tripMinutes': double.parse(tripMinutes.toStringAsFixed(1)),
      'ethanol': ethanol,
      'gLong': double.parse(gLong.toStringAsFixed(2)),
      'gLat': double.parse(gLat.toStringAsFixed(2)),
    };
  }

  // Estimativa universal de marchas para transmissões manuais e automáticas VW TSI (5 e 6 marchas / DSG)
  String _estimateGear(int speed, int rpm) {
    if (rpm < 550 || speed < 3) return 'N';
    final ratio = rpm / speed;
    if (ratio > 88) return '1';
    if (ratio > 53) return '2';
    if (ratio > 35) return '3';
    if (ratio > 26.5) return '4';
    if (ratio > 20.0) return '5';
    if (ratio > 14.0) return '6';
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
      final simMapKpa = (101 + (boostBar * 100)).round();

      final adv = _computeAdvancedMetrics(
        speed: speed,
        rpm: rpm,
        mapKpa: simMapKpa,
        boostBar: boostBar,
        load: load,
        tps: tps,
        timing: timing,
        coolant: 90,
        iat: 36,
        dtSeconds: 0.05,
      );

      _data = _data.copyWith(
        rpm: rpm,
        speed: speed,
        mapKpa: simMapKpa,
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
        estimatedHp: adv['hp'],
        estimatedTorqueNm: adv['torqueNm'],
        estimatedTorqueKgfm: adv['torqueKgfm'],
        peakHp: adv['peakHp'],
        peakTorqueKgfm: adv['peakTorqueKgfm'],
        fuelRailPressureBar: adv['railBar'],
        lambda: adv['lambda'],
        afr: adv['afr'],
        oilTemperature: adv['oilTemp'],
        egt: adv['egt'],
        fuelConsumptionLh: adv['fuelLh'],
        fuelConsumptionKml: adv['fuelKml'],
        avgFuelConsumptionKml: adv['avgKml'],
        totalFuelConsumedLiters: adv['totalFuel'],
        tripDistanceKm: adv['tripKm'],
        tripDurationMinutes: adv['tripMinutes'],
        ethanolPercent: adv['ethanol'],
        odometerKm: double.parse((_baseOdometer + adv['tripKm']).toStringAsFixed(1)),
        odometerSource: 'Simulação',
        distanceSinceDtcClearKm: 1420,
        longitudinalGForce: adv['gLong'],
        lateralGForce: adv['gLat'],
        misfiresCyl1: _misfiresCyl1,
        misfiresCyl2: _misfiresCyl2,
        misfiresCyl3: _misfiresCyl3,
        misfiresCyl4: _misfiresCyl4,
        misfiresCyl5: _misfiresCyl5,
        misfiresCyl6: _misfiresCyl6,
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
    _logFlushTimer?.cancel();
    _logFlushTimer = null;
    _flushPendingLogsSync();

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
