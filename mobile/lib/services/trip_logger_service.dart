import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/telemetry_data.dart';
import '../models/trip_log_record.dart';

class TripLoggerService extends ChangeNotifier {
  final List<TripLogRecord> _history = [];
  final List<TripTelemetrySample> _activeSamples = [];

  bool _isInitialized = false;
  bool _isRecording = false;
  DateTime? _tripStartTime;
  DateTime? _lastSampleTime;
  TelemetryData? _lastRecordedData;

  // Peaks da viagem ativa
  int _maxSpeed = 0;
  int _maxRpm = 0;
  double _maxBoost = -1.0;
  double _maxHp = 0.0;
  double _maxTorque = 0.0;
  int _maxCoolant = 0;
  int _maxOil = 0;
  int _maxEgt = 0;
  int _maxIat = 0;
  double _maxKnock = 0.0;

  List<TripLogRecord> get history => List.unmodifiable(_history);
  List<TripTelemetrySample> get activeSamples => List.unmodifiable(_activeSamples);
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  int get activeSampleCount => _activeSamples.length;
  DateTime? get activeStartTime => _tripStartTime;

  Directory _getTripsDirectory() {
    final candidateDirs = [
      '/data/user/0/com.antigravity.uptsi/files/trips',
      '/data/data/com.antigravity.uptsi/files/trips',
    ];
    for (final d in candidateDirs) {
      try {
        final dir = Directory(d);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir;
      } catch (_) {}
    }
    final fallback = Directory('${Directory.systemTemp.path}/vw_tsi_trips');
    if (!fallback.existsSync()) {
      fallback.createSync(recursive: true);
    }
    return fallback;
  }

  File _getIndexFile() {
    return File('${_getTripsDirectory().path}/trip_history_index_v1.json');
  }

  File _getSamplesFile(String tripId) {
    return File('${_getTripsDirectory().path}/trip_samples_$tripId.json');
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final indexFile = _getIndexFile();
      if (indexFile.existsSync()) {
        final raw = await indexFile.readAsString();
        if (raw.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(raw);
          _history.clear();
          for (final item in decoded) {
            _history.add(TripLogRecord.fromJson(item as Map<String, dynamic>));
          }
          _history.sort((a, b) => b.startTime.compareTo(a.startTime));
        }
      }
    } catch (e) {
      debugPrint('Erro ao inicializar TripLoggerService: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Chamado continuamente pelo listener do ObdBluetoothService
  void recordSample(TelemetryData data) {
    final isActive = data.isConnected || data.isSimulating;

    // Se desconectou enquanto estava gravando uma viagem com amostras, salva automaticamente
    if (!isActive) {
      if (_isRecording && _activeSamples.length >= 3) {
        finishAndSaveTrip();
      } else if (_isRecording) {
        _resetActiveState();
      }
      return;
    }

    // Só inicia/grava se o motor estiver ligado ou o carro em movimento
    if (data.rpm <= 0 && data.speed <= 0) return;

    final now = DateTime.now();

    if (!_isRecording) {
      _isRecording = true;
      _tripStartTime = now;
      _lastSampleTime = null;
      _activeSamples.clear();
      _resetPeaks();
    }

    // Amostragem de 1 Hz (1 amostra completa por segundo)
    if (_lastSampleTime != null && now.difference(_lastSampleTime!).inMilliseconds < 950) {
      return;
    }

    _lastSampleTime = now;
    _lastRecordedData = data;

    final offsetMs = now.difference(_tripStartTime!).inMilliseconds;
    final sample = TripTelemetrySample.fromTelemetry(data, offsetMs);
    _activeSamples.add(sample);

    // Atualiza picos
    _maxSpeed = max(_maxSpeed, data.speed);
    _maxRpm = max(_maxRpm, data.rpm);
    _maxBoost = max(_maxBoost, data.boostBar);
    _maxHp = max(_maxHp, data.estimatedHp);
    _maxTorque = max(_maxTorque, data.estimatedTorqueKgfm);
    _maxCoolant = max(_maxCoolant, data.coolant);
    _maxOil = max(_maxOil, data.oilTemperature);
    _maxEgt = max(_maxEgt, data.egt);
    _maxIat = max(_maxIat, data.iat);
    _maxKnock = max(_maxKnock, data.knockRetard);

    notifyListeners();
  }

  void _resetPeaks() {
    _maxSpeed = 0;
    _maxRpm = 0;
    _maxBoost = -1.0;
    _maxHp = 0.0;
    _maxTorque = 0.0;
    _maxCoolant = 0;
    _maxOil = 0;
    _maxEgt = 0;
    _maxIat = 0;
    _maxKnock = 0.0;
  }

  void _resetActiveState() {
    _isRecording = false;
    _tripStartTime = null;
    _lastSampleTime = null;
    _lastRecordedData = null;
    _activeSamples.clear();
    _resetPeaks();
    notifyListeners();
  }

  Future<TripLogRecord?> finishAndSaveTrip() async {
    if (!_isRecording || _activeSamples.isEmpty) {
      _resetActiveState();
      return null;
    }

    final endTime = DateTime.now();
    final startTime = _tripStartTime ?? endTime;
    final durationMin = max(0.01, endTime.difference(startTime).inSeconds / 60.0);
    final lastData = _lastRecordedData;

    final distKm = lastData?.tripDistanceKm ?? 0.0;
    final avgSpeed = durationMin > 0 ? (distKm / (durationMin / 60.0)) : 0.0;
    final fuelLiters = lastData?.totalFuelConsumedLiters ?? 0.0;
    final avgKml = lastData?.avgFuelConsumptionKml ?? 0.0;
    final estCost = fuelLiters * (lastData?.fuelPricePerLiter ?? 5.89);

    int totalMisfires = 0;
    if (_activeSamples.isNotEmpty) {
      totalMisfires = _activeSamples.last.totalMisfires;
    }

    final tripId = '${startTime.millisecondsSinceEpoch}';
    final record = TripLogRecord(
      id: tripId,
      startTime: startTime,
      endTime: endTime,
      vehicleProfile: lastData?.vehicleProfile ?? 'VW TSI Universal',
      distanceKm: double.parse(distKm.toStringAsFixed(2)),
      durationMinutes: double.parse(durationMin.toStringAsFixed(1)),
      avgSpeedKmh: double.parse(avgSpeed.toStringAsFixed(1)),
      maxSpeedKmh: _maxSpeed,
      maxRpm: _maxRpm,
      maxBoostBar: double.parse((_maxBoost < -0.9 ? 0.0 : _maxBoost).toStringAsFixed(2)),
      maxHp: double.parse(_maxHp.toStringAsFixed(1)),
      maxTorqueKgfm: double.parse(_maxTorque.toStringAsFixed(1)),
      maxCoolantTemp: _maxCoolant,
      maxOilTemp: _maxOil,
      maxEgtTemp: _maxEgt,
      maxIatTemp: _maxIat,
      avgConsumptionKml: double.parse(avgKml.toStringAsFixed(1)),
      fuelConsumedLiters: double.parse(fuelLiters.toStringAsFixed(2)),
      estimatedCost: double.parse(estCost.toStringAsFixed(2)),
      totalMisfires: totalMisfires,
      maxKnockRetard: double.parse(_maxKnock.toStringAsFixed(1)),
      sampleCount: _activeSamples.length,
    );

    final samplesCopy = List<TripTelemetrySample>.from(_activeSamples);

    _history.insert(0, record);
    _resetActiveState();

    try {
      final samplesFile = _getSamplesFile(tripId);
      final encodedSamples = jsonEncode(samplesCopy.map((s) => s.toJson()).toList());
      await samplesFile.writeAsString(encodedSamples, flush: true);

      await _saveIndex();
    } catch (e) {
      debugPrint('Erro ao salvar viagem no logger: $e');
    }

    notifyListeners();
    return record;
  }

  Future<List<TripTelemetrySample>> loadTripSamples(String tripId) async {
    try {
      final file = _getSamplesFile(tripId);
      if (!file.existsSync()) return [];
      final raw = await file.readAsString();
      if (raw.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((item) => TripTelemetrySample.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Erro ao carregar amostras da viagem $tripId: $e');
      return [];
    }
  }

  Future<String> buildCsvContent(String tripId) async {
    final samples = await loadTripSamples(tripId);
    final sb = StringBuffer();
    sb.writeln(TripTelemetrySample.csvHeader);
    for (final s in samples) {
      sb.writeln(s.toCsvRow());
    }
    return sb.toString();
  }

  Future<String?> exportTripCsvFile(String tripId) async {
    try {
      final csv = await buildCsvContent(tripId);
      final dir = _getTripsDirectory();
      final csvFile = File('${dir.path}/datalog_viagem_$tripId.csv');
      await csvFile.writeAsString(csv, flush: true);
      return csvFile.path;
    } catch (e) {
      debugPrint('Erro ao exportar CSV: $e');
      return null;
    }
  }

  Future<void> deleteTrip(String tripId) async {
    _history.removeWhere((t) => t.id == tripId);
    try {
      final samplesFile = _getSamplesFile(tripId);
      if (samplesFile.existsSync()) {
        await samplesFile.delete();
      }
      await _saveIndex();
    } catch (e) {
      debugPrint('Erro ao excluir viagem: $e');
    }
    notifyListeners();
  }

  Future<void> _saveIndex() async {
    final indexFile = _getIndexFile();
    await indexFile.writeAsString(
      jsonEncode(_history.map((r) => r.toJson()).toList()),
      flush: true,
    );
  }
}
