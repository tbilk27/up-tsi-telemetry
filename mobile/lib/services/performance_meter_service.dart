import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PerformanceState {
  disarmed,     // Desarmado / Parado
  waitingToArm, // Aguardando atingir condição de largada (ex: parar veículo a 0 km/h)
  armed,        // Armado! Pronto para acelerar
  running,      // Cronômetro ativo / Acelerando
  finished,     // Prova concluída
  aborted,      // Prova abortada
}

class PerformancePreset {
  final String id;
  final String label;
  final String category;
  final int vStart;
  final int vEnd;

  const PerformancePreset({
    required this.id,
    required this.label,
    required this.category,
    required this.vStart,
    required this.vEnd,
  });

  bool get isFromZero => vStart == 0;
}

class SpeedSample {
  final double elapsedSeconds;
  final double speedKmh;
  final double boostBar;
  final int rpm;
  final double gForce;
  final double distanceMeters;

  const SpeedSample({
    required this.elapsedSeconds,
    required this.speedKmh,
    required this.boostBar,
    required this.rpm,
    required this.gForce,
    required this.distanceMeters,
  });
}

class PerformanceRun {
  final String id;
  final String presetLabel;
  final int vStart;
  final int vEnd;
  final double elapsedSeconds;
  final double peakBoostBar;
  final int peakRpm;
  final double peakGForce;
  final double distanceMeters;
  final DateTime timestamp;
  final Map<String, double> splits;
  final List<SpeedSample> samples;

  const PerformanceRun({
    required this.id,
    required this.presetLabel,
    required this.vStart,
    required this.vEnd,
    required this.elapsedSeconds,
    required this.peakBoostBar,
    required this.peakRpm,
    required this.peakGForce,
    required this.distanceMeters,
    required this.timestamp,
    required this.splits,
    required this.samples,
  });
}

class PerformanceMeterService extends ChangeNotifier {
  static const List<PerformancePreset> defaultPresets = [
    PerformancePreset(id: '0_100', label: '0 a 100 km/h', category: 'Arrancada', vStart: 0, vEnd: 100),
    PerformancePreset(id: '0_60', label: '0 a 60 km/h', category: 'Arrancada', vStart: 0, vEnd: 60),
    PerformancePreset(id: '40_100', label: '40 a 100 km/h', category: 'Retomada', vStart: 40, vEnd: 100),
    PerformancePreset(id: '60_120', label: '60 a 120 km/h', category: 'Retomada', vStart: 60, vEnd: 120),
    PerformancePreset(id: '80_120', label: '80 a 120 km/h', category: 'Retomada', vStart: 80, vEnd: 120),
    PerformancePreset(id: '100_200', label: '100 a 200 km/h', category: 'Retomada', vStart: 100, vEnd: 200),
    PerformancePreset(id: 'custom', label: 'Personalizada', category: 'Custom', vStart: 0, vEnd: 100),
  ];

  PerformancePreset _selectedPreset = defaultPresets[0];
  int _customVStart = 0;
  int _customVEnd = 100;

  PerformanceState _state = PerformanceState.disarmed;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiRefreshTimer;
  Timer? _simulationTimer;

  // Telemetria da puxada em andamento
  double _currentElapsedSeconds = 0.0;
  double _interpolatedStartTimeOffset = 0.0;
  double _lastSpeed = 0.0;
  DateTime? _lastSampleTime;
  double _distanceMeters = 0.0;
  double _peakBoost = 0.0;
  int _peakRpm = 0;
  double _peakGForce = 0.0;
  double _currentGForce = 0.0;

  final Map<String, double> _currentSplits = {};
  final List<SpeedSample> _currentSamples = [];
  final List<PerformanceRun> _history = [];

  PerformancePreset get selectedPreset => _selectedPreset;
  int get activeVStart => _selectedPreset.id == 'custom' ? _customVStart : _selectedPreset.vStart;
  int get activeVEnd => _selectedPreset.id == 'custom' ? _customVEnd : _selectedPreset.vEnd;
  String get activeLabel => _selectedPreset.id == 'custom' ? '$_customVStart a $_customVEnd km/h' : _selectedPreset.label;

  PerformanceState get state => _state;
  double get currentElapsedSeconds => _currentElapsedSeconds;
  double get distanceMeters => _distanceMeters;
  double get peakBoost => _peakBoost;
  int get peakRpm => _peakRpm;
  double get peakGForce => _peakGForce;
  double get currentGForce => _currentGForce;
  Map<String, double> get currentSplits => Map.unmodifiable(_currentSplits);
  List<SpeedSample> get currentSamples => List.unmodifiable(_currentSamples);
  List<PerformanceRun> get history => List.unmodifiable(_history);

  PerformanceRun? get latestRun => _history.isNotEmpty ? _history.first : null;

  PerformanceRun? get bestRunForCurrentPreset {
    final runs = _history.where((r) => r.vStart == activeVStart && r.vEnd == activeVEnd).toList();
    if (runs.isEmpty) return null;
    runs.sort((a, b) => a.elapsedSeconds.compareTo(b.elapsedSeconds));
    return runs.first;
  }

  void selectPreset(PerformancePreset preset) {
    _selectedPreset = preset;
    arm();
  }

  void setCustomRange(int start, int end) {
    if (start >= end) return;
    _customVStart = start.clamp(0, 240);
    _customVEnd = end.clamp(10, 260);
    _selectedPreset = defaultPresets.firstWhere((p) => p.id == 'custom');
    arm();
  }

  void arm() {
    _simulationTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _stopwatch.reset();
    _currentElapsedSeconds = 0.0;
    _interpolatedStartTimeOffset = 0.0;
    _distanceMeters = 0.0;
    _peakBoost = 0.0;
    _peakRpm = 0;
    _peakGForce = 0.0;
    _currentGForce = 0.0;
    _currentSplits.clear();
    _currentSamples.clear();

    // Se a largada for de 0 km/h, aguarda o carro parar
    if (activeVStart == 0) {
      if (_lastSpeed <= 0.5) {
        _state = PerformanceState.armed;
      } else {
        _state = PerformanceState.waitingToArm;
      }
    } else {
      // Retomada: se a velocidade atual já estiver abaixo ou igual à velocidade inicial, está armado
      if (_lastSpeed <= activeVStart) {
        _state = PerformanceState.armed;
      } else {
        _state = PerformanceState.waitingToArm;
      }
    }
    notifyListeners();
  }

  void disarm() {
    _simulationTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _stopwatch.reset();
    _state = PerformanceState.disarmed;
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  // Processa dados de velocidade e telemetria recebidos do OBDII / GPS
  void updateTelemetry(int speedKmh, double boostBar, int rpm) {
    final now = DateTime.now();
    final speed = speedKmh.toDouble();
    final dtSeconds = _lastSampleTime != null
        ? (now.difference(_lastSampleTime!).inMicroseconds / 1000000.0).clamp(0.005, 0.5)
        : 0.1;

    // Cálculo instantâneo de G-force (aceleração longitudinal)
    if (_lastSampleTime != null && dtSeconds > 0) {
      final deltaV_ms = (speed - _lastSpeed) / 3.6;
      final accel_ms2 = deltaV_ms / dtSeconds;
      final g = (accel_ms2 / 9.80665).clamp(-2.0, 2.5);
      _currentGForce = double.parse(g.toStringAsFixed(2));
    }

    switch (_state) {
      case PerformanceState.disarmed:
        // Não faz nada
        break;

      case PerformanceState.waitingToArm:
        if (activeVStart == 0) {
          if (speed <= 0.5) {
            _state = PerformanceState.armed;
            HapticFeedback.lightImpact();
            notifyListeners();
          }
        } else {
          if (speed <= activeVStart) {
            _state = PerformanceState.armed;
            HapticFeedback.lightImpact();
            notifyListeners();
          }
        }
        break;

      case PerformanceState.armed:
        // Gatilho automático de largada
        if (activeVStart == 0) {
          if (speed > 0.8) {
            _startRun(now, speed, boostBar, rpm, 0.0);
          }
        } else {
          // Retomada: disparar assim que cruzar a velocidade inicial
          if (_lastSpeed <= activeVStart && speed > activeVStart) {
            // Interpolação do instante exato de largada
            final speedSpan = speed - _lastSpeed;
            final fraction = speedSpan > 0 ? (activeVStart - _lastSpeed) / speedSpan : 0.0;
            final timeOffset = (1.0 - fraction) * dtSeconds;
            _startRun(now, speed, boostBar, rpm, timeOffset);
          }
        }
        break;

      case PerformanceState.running:
        _processRunningStep(now, speed, boostBar, rpm, dtSeconds);
        break;

      case PerformanceState.finished:
      case PerformanceState.aborted:
        // Se o carro parar completamente após terminar uma prova de 0-100, re-arma automaticamente
        if (activeVStart == 0 && speed <= 0.5 && _lastSpeed > 1.0) {
          arm();
        }
        break;
    }

    _lastSpeed = speed;
    _lastSampleTime = now;
  }

  void _startRun(DateTime now, double speed, double boostBar, int rpm, double timeOffset) {
    _state = PerformanceState.running;
    _interpolatedStartTimeOffset = timeOffset;
    _stopwatch.reset();
    _stopwatch.start();
    _distanceMeters = 0.0;
    _peakBoost = max(0.0, boostBar);
    _peakRpm = rpm;
    _peakGForce = max(0.0, _currentGForce);
    _currentSplits.clear();
    _currentSamples.clear();

    HapticFeedback.mediumImpact();

    // Timer fluido para atualizar os dígitos do cronômetro a 30 FPS na interface
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (_state == PerformanceState.running) {
        _currentElapsedSeconds = (_stopwatch.elapsedMicroseconds / 1000000.0) + _interpolatedStartTimeOffset;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _recordSample(0.0, activeVStart.toDouble(), boostBar, rpm, _currentGForce, 0.0);
    notifyListeners();
  }

  void _processRunningStep(DateTime now, double speed, double boostBar, int rpm, double dtSeconds) {
    _currentElapsedSeconds = (_stopwatch.elapsedMicroseconds / 1000000.0) + _interpolatedStartTimeOffset;

    // Distância percorrida integrada
    final avgSpeedMs = ((_lastSpeed + speed) / 2.0) / 3.6;
    _distanceMeters += avgSpeedMs * dtSeconds;

    _peakBoost = max(_peakBoost, boostBar);
    _peakRpm = max(_peakRpm, rpm);
    _peakGForce = max(_peakGForce, _currentGForce);

    // Splits de parciais de velocidade
    if (activeVStart == 0 && activeVEnd >= 100) {
      if (!_currentSplits.containsKey('0-60 km/h') && speed >= 60.0) {
        final splitTime = _interpolateTimeForSpeed(60.0, dtSeconds);
        _currentSplits['0-60 km/h'] = splitTime;
      }
    }

    // Splits de distância
    if (activeVStart == 0) {
      if (!_currentSplits.containsKey('60 ft (18m)') && _distanceMeters >= 18.28) {
        _currentSplits['60 ft (18m)'] = _currentElapsedSeconds;
      }
      if (!_currentSplits.containsKey('100m') && _distanceMeters >= 100.0) {
        _currentSplits['100m'] = _currentElapsedSeconds;
      }
      if (!_currentSplits.containsKey('1/8 mi (201m)') && _distanceMeters >= 201.16) {
        _currentSplits['1/8 mi (201m)'] = _currentElapsedSeconds;
      }
      if (!_currentSplits.containsKey('1/4 mi (402m)') && _distanceMeters >= 402.33) {
        _currentSplits['1/4 mi (402m)'] = _currentElapsedSeconds;
      }
    }

    _recordSample(_currentElapsedSeconds, speed, boostBar, rpm, _currentGForce, _distanceMeters);

    // Condição de parada automática: atingiu a velocidade final
    if (speed >= activeVEnd) {
      _finishRun(dtSeconds, speed);
      return;
    }

    // Abortar se houver desaceleração brusca durante a aceleração (ex: freou)
    if (speed < _lastSpeed - 20.0 && speed < activeVEnd * 0.7) {
      _abortRun();
      return;
    }

    notifyListeners();
  }

  double _interpolateTimeForSpeed(double targetSpeed, double dtSeconds) {
    final speedSpan = _lastSpeed - targetSpeed;
    if (speedSpan.abs() < 0.001) return _currentElapsedSeconds;
    final frac = (_lastSpeed < targetSpeed)
        ? (targetSpeed - _lastSpeed) / (targetSpeed - _lastSpeed + 0.001)
        : 1.0;
    return max(0.01, _currentElapsedSeconds - (1.0 - frac) * dtSeconds);
  }

  void _recordSample(double t, double speed, double boost, int rpm, double g, double dist) {
    if (_currentSamples.length < 500) {
      _currentSamples.add(
        SpeedSample(
          elapsedSeconds: double.parse(t.toStringAsFixed(2)),
          speedKmh: double.parse(speed.toStringAsFixed(1)),
          boostBar: double.parse(boost.toStringAsFixed(2)),
          rpm: rpm,
          gForce: double.parse(g.toStringAsFixed(2)),
          distanceMeters: double.parse(dist.toStringAsFixed(1)),
        ),
      );
    }
  }

  void _finishRun(double dtSeconds, double finalSpeed) {
    _stopwatch.stop();
    _uiRefreshTimer?.cancel();

    // Interpolação milimétrica do instante exato de cruzar a velocidade final
    final speedDelta = finalSpeed - _lastSpeed;
    if (speedDelta > 0.01) {
      final fraction = (activeVEnd - _lastSpeed) / speedDelta;
      final excessTime = (1.0 - fraction) * dtSeconds;
      _currentElapsedSeconds = max(0.1, _currentElapsedSeconds - excessTime);
    }

    _state = PerformanceState.finished;
    HapticFeedback.heavyImpact();

    final run = PerformanceRun(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      presetLabel: activeLabel,
      vStart: activeVStart,
      vEnd: activeVEnd,
      elapsedSeconds: double.parse(_currentElapsedSeconds.toStringAsFixed(2)),
      peakBoostBar: double.parse(_peakBoost.toStringAsFixed(2)),
      peakRpm: _peakRpm,
      peakGForce: double.parse(_peakGForce.toStringAsFixed(2)),
      distanceMeters: double.parse(_distanceMeters.toStringAsFixed(1)),
      timestamp: DateTime.now(),
      splits: Map.from(_currentSplits),
      samples: List.from(_currentSamples),
    );

    _history.insert(0, run);
    notifyListeners();
  }

  void _abortRun() {
    _stopwatch.stop();
    _uiRefreshTimer?.cancel();
    _state = PerformanceState.aborted;
    HapticFeedback.vibrate();
    notifyListeners();
  }

  // Simulação realista de arrancada Up! TSI para demonstração e testes rápidos
  void simulateRun() {
    _simulationTimer?.cancel();
    arm();

    // Countdown / largada imediata
    int step = 0;
    const intervalMs = 60;
    final targetEnd = activeVEnd.toDouble();
    final targetStart = activeVStart.toDouble();

    // Curva de torque e potência típica do Up! TSI (105 cv / 16.8 kgfm)
    // 0-100 km/h em aprox. 8.4s
    double currentSimSpeed = targetStart;
    double currentSimBoost = 0.0;
    int currentSimRpm = 1000;

    _simulationTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      step++;
      final elapsed = (step * intervalMs) / 1000.0;

      // Simulação de física Up! TSI
      if (elapsed < 0.2) {
        // Largada / spool
        currentSimBoost = min(1.35, currentSimBoost + 0.35);
        currentSimSpeed = targetStart + 1.5;
        currentSimRpm = 2500;
      } else if (currentSimSpeed < 44.0) {
        // 1ª Marcha até 44 km/h (~5200 RPM)
        currentSimBoost = 1.32;
        currentSimSpeed += 1.8;
        currentSimRpm = (1000 + (currentSimSpeed * 95)).clamp(1000, 5300).round();
      } else if (currentSimSpeed < 47.0) {
        // Troca de marcha 1ª -> 2ª
        currentSimBoost = 0.7; // alívio de boost
        currentSimSpeed += 0.8;
        currentSimRpm = 3400;
      } else {
        // 2ª Marcha puxando até 100 km/h
        currentSimBoost = 1.28;
        currentSimSpeed += 1.15;
        currentSimRpm = (2800 + ((currentSimSpeed - 47) * 48)).clamp(2800, 5800).round();
      }

      updateTelemetry(currentSimSpeed.round(), currentSimBoost, currentSimRpm);

      if (currentSimSpeed >= targetEnd || _state == PerformanceState.finished) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _simulationTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
