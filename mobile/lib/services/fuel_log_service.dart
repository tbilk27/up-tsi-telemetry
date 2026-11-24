import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/fuel_log_entry.dart';

class FuelLogService extends ChangeNotifier {
  final List<FuelLogEntry> _entries = [];
  double _baseOdometerKm = 64250.0; // Padrão calibrável
  bool _isInitialized = false;

  List<FuelLogEntry> get entries => List.unmodifiable(_entries);
  double get baseOdometerKm => _baseOdometerKm;
  bool get isInitialized => _isInitialized;

  FuelLogEntry? get lastEntry => _entries.isNotEmpty ? _entries.first : null;

  File _getStorageFile() {
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
        return File('${dir.path}/fuel_log_v1.json');
      } catch (_) {}
    }
    return File('${Directory.systemTemp.path}/fuel_log_v1.json');
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = _getStorageFile();
      if (file.existsSync()) {
        final rawJson = await file.readAsString();
        if (rawJson.isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(rawJson);
          _baseOdometerKm = (data['baseOdometer'] as num?)?.toDouble() ?? 64250.0;
          final List<dynamic>? list = data['entries'] as List<dynamic>?;
          if (list != null && list.isNotEmpty) {
            _entries.clear();
            for (final item in list) {
              _entries.add(FuelLogEntry.fromJson(item as Map<String, dynamic>));
            }
            _sortEntries();
          } else {
            _createDefaultSampleEntries();
            await _saveToStorage();
          }
        } else {
          _createDefaultSampleEntries();
          await _saveToStorage();
        }
      } else {
        _createDefaultSampleEntries();
        await _saveToStorage();
      }
    } catch (e) {
      debugPrint('Erro ao inicializar FuelLogService: $e');
      if (_entries.isEmpty) {
        _createDefaultSampleEntries();
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _createDefaultSampleEntries() {
    _entries.clear();
    final now = DateTime.now();

    // Abastecimento inicial (tanque cheio de referência)
    final entry1 = FuelLogEntry(
      id: 'fuel_sample_1',
      date: now.subtract(const Duration(days: 14)),
      liters: 45.0,
      totalPrice: 265.05,
      pricePerLiter: 5.89,
      odometerKm: 63580.0,
      fuelType: 'Gasolina Comum',
      isFullTank: true,
      stationName: 'Posto Shell',
    );

    // Segundo abastecimento (após rodar 670 km)
    const deltaKm = 670.0;
    const liters2 = 47.5;
    const kml2 = deltaKm / liters2; // ~14.1 km/L
    const price2 = 279.77;

    final entry2 = FuelLogEntry(
      id: 'fuel_sample_2',
      date: now.subtract(const Duration(days: 4)),
      liters: liters2,
      totalPrice: price2,
      pricePerLiter: 5.89,
      odometerKm: 64250.0,
      fuelType: 'Gasolina Comum',
      isFullTank: true,
      distanceSinceLastFuelKm: deltaKm,
      calculatedKml: double.parse(kml2.toStringAsFixed(2)),
      costPerKm: double.parse((price2 / deltaKm).toStringAsFixed(3)),
      stationName: 'Posto Ipiranga',
    );

    _entries.add(entry2);
    _entries.add(entry1);
    _baseOdometerKm = 64250.0;
  }

  Future<void> setBaseOdometer(double odoKm) async {
    _baseOdometerKm = odoKm;
    await _saveToStorage();
    notifyListeners();
  }

  Future<void> addEntry({
    required double liters,
    required double totalPrice,
    double? pricePerLiter,
    required double odometerKm,
    String fuelType = 'Gasolina Comum',
    bool isFullTank = true,
    String? stationName,
    DateTime? date,
  }) async {
    final entryDate = date ?? DateTime.now();
    final calculatedPpl = pricePerLiter ?? (liters > 0 ? (totalPrice / liters) : 0.0);

    // Procura o abastecimento anterior com tanque cheio e odômetro menor
    FuelLogEntry? prevFull;
    for (final e in _entries) {
      if (e.isFullTank && e.odometerKm < odometerKm) {
        if (prevFull == null || e.odometerKm > prevFull.odometerKm) {
          prevFull = e;
        }
      }
    }

    double? distanceKm;
    double? kml;
    double? costPerKm;

    if (isFullTank && prevFull != null) {
      final delta = odometerKm - prevFull.odometerKm;
      if (delta > 0 && liters > 0) {
        distanceKm = delta;
        kml = double.parse((delta / liters).toStringAsFixed(2));
        costPerKm = double.parse((totalPrice / delta).toStringAsFixed(3));
      }
    }

    final newEntry = FuelLogEntry(
      id: 'fuel_${DateTime.now().millisecondsSinceEpoch}',
      date: entryDate,
      liters: liters,
      totalPrice: totalPrice,
      pricePerLiter: double.parse(calculatedPpl.toStringAsFixed(3)),
      odometerKm: odometerKm,
      fuelType: fuelType,
      isFullTank: isFullTank,
      distanceSinceLastFuelKm: distanceKm,
      calculatedKml: kml,
      costPerKm: costPerKm,
      stationName: stationName,
    );

    _entries.add(newEntry);
    _recalculateAllMetrics();
    _sortEntries();

    if (odometerKm > _baseOdometerKm) {
      _baseOdometerKm = odometerKm;
    }

    await _saveToStorage();
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _recalculateAllMetrics();
    _sortEntries();
    await _saveToStorage();
    notifyListeners();
  }

  void _recalculateAllMetrics() {
    if (_entries.length < 2) return;

    // Ordena cronologicamente do mais antigo para o mais novo para calcular deltas
    final chronological = List<FuelLogEntry>.from(_entries)
      ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));

    FuelLogEntry? prevFull;
    final List<FuelLogEntry> updated = [];

    for (final e in chronological) {
      if (e.isFullTank) {
        if (prevFull != null && e.odometerKm > prevFull.odometerKm) {
          final delta = e.odometerKm - prevFull.odometerKm;
          final kml = delta / e.liters;
          final costPerKm = e.totalPrice / delta;

          updated.add(e.copyWith(
            distanceSinceLastFuelKm: delta,
            calculatedKml: double.parse(kml.toStringAsFixed(2)),
            costPerKm: double.parse(costPerKm.toStringAsFixed(3)),
          ));
        } else {
          updated.add(e.copyWith(
            distanceSinceLastFuelKm: null,
            calculatedKml: null,
            costPerKm: null,
          ));
        }
        prevFull = e;
      } else {
        updated.add(e);
      }
    }

    _entries.clear();
    _entries.addAll(updated);
  }

  void _sortEntries() {
    // Exibe sempre do mais recente para o mais antigo
    _entries.sort((a, b) => b.odometerKm.compareTo(a.odometerKm));
  }

  Future<void> _saveToStorage() async {
    try {
      final file = _getStorageFile();
      final data = {
        'baseOdometer': _baseOdometerKm,
        'entries': _entries.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Erro ao salvar abastecimentos: $e');
    }
  }

  // Estatísticas calculadas
  double get overallAverageKml {
    double totalKm = 0.0;
    double totalLiters = 0.0;
    for (final e in _entries) {
      if (e.calculatedKml != null && e.distanceSinceLastFuelKm != null) {
        totalKm += e.distanceSinceLastFuelKm!;
        totalLiters += e.liters;
      }
    }
    if (totalLiters <= 0.01) return 0.0;
    return double.parse((totalKm / totalLiters).toStringAsFixed(2));
  }

  double get overallCostPerKm {
    double totalCost = 0.0;
    double totalKm = 0.0;
    for (final e in _entries) {
      if (e.distanceSinceLastFuelKm != null) {
        totalCost += e.totalPrice;
        totalKm += e.distanceSinceLastFuelKm!;
      }
    }
    if (totalKm <= 0.01) return 0.0;
    return double.parse((totalCost / totalKm).toStringAsFixed(3));
  }

  double get totalSpent {
    return _entries.fold(0.0, (sum, e) => sum + e.totalPrice);
  }

  double get totalLiters {
    return _entries.fold(0.0, (sum, e) => sum + e.liters);
  }

  double get totalTrackedKm {
    if (_entries.length < 2) return 0.0;
    final maxOdo = _entries.first.odometerKm;
    final minOdo = _entries.last.odometerKm;
    return (maxOdo - minOdo).clamp(0.0, double.infinity);
  }
}
