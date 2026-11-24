import 'telemetry_data.dart';

class TripTelemetrySample {
  final int offsetMs;
  final int rpm;
  final int speed;
  final String gear;
  final int mapKpa;
  final double boostBar;
  final int tps;
  final int engineLoad;
  final int coolant;
  final int iat;
  final int oilTemp;
  final int egt;
  final double timingAdvance;
  final double knockRetard;
  final double stft;
  final double ltft;
  final double lambda;
  final double afr;
  final double fuelRailBar;
  final double voltage;
  final double estimatedHp;
  final double estimatedTorqueKgfm;
  final double fuelLh;
  final double fuelKml;
  final double gLong;
  final double gLat;
  final int totalMisfires;

  const TripTelemetrySample({
    required this.offsetMs,
    required this.rpm,
    required this.speed,
    required this.gear,
    required this.mapKpa,
    required this.boostBar,
    required this.tps,
    required this.engineLoad,
    required this.coolant,
    required this.iat,
    required this.oilTemp,
    required this.egt,
    required this.timingAdvance,
    required this.knockRetard,
    required this.stft,
    required this.ltft,
    required this.lambda,
    required this.afr,
    required this.fuelRailBar,
    required this.voltage,
    required this.estimatedHp,
    required this.estimatedTorqueKgfm,
    required this.fuelLh,
    required this.fuelKml,
    required this.gLong,
    required this.gLat,
    required this.totalMisfires,
  });

  factory TripTelemetrySample.fromTelemetry(TelemetryData data, int offsetMs) {
    final misfires = data.misfiresCyl1 +
        data.misfiresCyl2 +
        data.misfiresCyl3 +
        data.misfiresCyl4 +
        data.misfiresCyl5 +
        data.misfiresCyl6;
    return TripTelemetrySample(
      offsetMs: offsetMs,
      rpm: data.rpm,
      speed: data.speed,
      gear: data.gear,
      mapKpa: data.mapKpa,
      boostBar: data.boostBar,
      tps: data.tps,
      engineLoad: data.engineLoad,
      coolant: data.coolant,
      iat: data.iat,
      oilTemp: data.oilTemperature,
      egt: data.egt,
      timingAdvance: data.timingAdvance,
      knockRetard: data.knockRetard,
      stft: data.stft,
      ltft: data.ltft,
      lambda: data.lambda,
      afr: data.afr,
      fuelRailBar: data.fuelRailPressureBar,
      voltage: data.voltage,
      estimatedHp: data.estimatedHp,
      estimatedTorqueKgfm: data.estimatedTorqueKgfm,
      fuelLh: data.fuelConsumptionLh,
      fuelKml: data.fuelConsumptionKml,
      gLong: data.longitudinalGForce,
      gLat: data.lateralGForce,
      totalMisfires: misfires,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      't': offsetMs,
      'rpm': rpm,
      'spd': speed,
      'gr': gear,
      'map': mapKpa,
      'bst': boostBar,
      'tps': tps,
      'ld': engineLoad,
      'ect': coolant,
      'iat': iat,
      'oil': oilTemp,
      'egt': egt,
      'ign': timingAdvance,
      'knk': knockRetard,
      'stft': stft,
      'ltft': ltft,
      'lbd': lambda,
      'afr': afr,
      'rail': fuelRailBar,
      'v': voltage,
      'hp': estimatedHp,
      'tq': estimatedTorqueKgfm,
      'lh': fuelLh,
      'kml': fuelKml,
      'gl': gLong,
      'gt': gLat,
      'msf': totalMisfires,
    };
  }

  factory TripTelemetrySample.fromJson(Map<String, dynamic> json) {
    return TripTelemetrySample(
      offsetMs: (json['t'] as num?)?.toInt() ?? 0,
      rpm: (json['rpm'] as num?)?.toInt() ?? 0,
      speed: (json['spd'] as num?)?.toInt() ?? 0,
      gear: (json['gr'] as String?) ?? 'N',
      mapKpa: (json['map'] as num?)?.toInt() ?? 101,
      boostBar: (json['bst'] as num?)?.toDouble() ?? 0.0,
      tps: (json['tps'] as num?)?.toInt() ?? 0,
      engineLoad: (json['ld'] as num?)?.toInt() ?? 0,
      coolant: (json['ect'] as num?)?.toInt() ?? 0,
      iat: (json['iat'] as num?)?.toInt() ?? 0,
      oilTemp: (json['oil'] as num?)?.toInt() ?? 0,
      egt: (json['egt'] as num?)?.toInt() ?? 0,
      timingAdvance: (json['ign'] as num?)?.toDouble() ?? 0.0,
      knockRetard: (json['knk'] as num?)?.toDouble() ?? 0.0,
      stft: (json['stft'] as num?)?.toDouble() ?? 0.0,
      ltft: (json['ltft'] as num?)?.toDouble() ?? 0.0,
      lambda: (json['lbd'] as num?)?.toDouble() ?? 1.0,
      afr: (json['afr'] as num?)?.toDouble() ?? 14.7,
      fuelRailBar: (json['rail'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['v'] as num?)?.toDouble() ?? 0.0,
      estimatedHp: (json['hp'] as num?)?.toDouble() ?? 0.0,
      estimatedTorqueKgfm: (json['tq'] as num?)?.toDouble() ?? 0.0,
      fuelLh: (json['lh'] as num?)?.toDouble() ?? 0.0,
      fuelKml: (json['kml'] as num?)?.toDouble() ?? 0.0,
      gLong: (json['gl'] as num?)?.toDouble() ?? 0.0,
      gLat: (json['gt'] as num?)?.toDouble() ?? 0.0,
      totalMisfires: (json['msf'] as num?)?.toInt() ?? 0,
    );
  }

  static const String csvHeader =
      'Tempo(s),RPM,Velocidade(km/h),Marcha,MAP(kPa),Turbo(bar),TPS(%),Carga(%),Agua(C),Admissao(C),Oleo(C),EGT(C),Avanco(deg),Knock(deg),STFT(%),LTFT(%),Lambda,AFR,Rail(bar),Bateria(V),Potencia(CV),Torque(kgfm),Consumo(L/h),Consumo(km/L),G_Long,G_Lat,Misfires';

  String toCsvRow() {
    final sec = (offsetMs / 1000.0).toStringAsFixed(1);
    return '$sec,$rpm,$speed,$gear,$mapKpa,${boostBar.toStringAsFixed(2)},$tps,$engineLoad,$coolant,$iat,$oilTemp,$egt,${timingAdvance.toStringAsFixed(1)},${knockRetard.toStringAsFixed(1)},${stft.toStringAsFixed(1)},${ltft.toStringAsFixed(1)},${lambda.toStringAsFixed(2)},${afr.toStringAsFixed(1)},${fuelRailBar.toStringAsFixed(1)},${voltage.toStringAsFixed(1)},${estimatedHp.toStringAsFixed(1)},${estimatedTorqueKgfm.toStringAsFixed(1)},${fuelLh.toStringAsFixed(2)},${fuelKml.toStringAsFixed(1)},${gLong.toStringAsFixed(2)},${gLat.toStringAsFixed(2)},$totalMisfires';
  }
}

class TripLogRecord {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String vehicleProfile;
  final double distanceKm;
  final double durationMinutes;
  final double avgSpeedKmh;
  final int maxSpeedKmh;
  final int maxRpm;
  final double maxBoostBar;
  final double maxHp;
  final double maxTorqueKgfm;
  final int maxCoolantTemp;
  final int maxOilTemp;
  final int maxEgtTemp;
  final int maxIatTemp;
  final double avgConsumptionKml;
  final double fuelConsumedLiters;
  final double estimatedCost;
  final int totalMisfires;
  final double maxKnockRetard;
  final int sampleCount;

  const TripLogRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.vehicleProfile,
    required this.distanceKm,
    required this.durationMinutes,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.maxRpm,
    required this.maxBoostBar,
    required this.maxHp,
    required this.maxTorqueKgfm,
    required this.maxCoolantTemp,
    required this.maxOilTemp,
    required this.maxEgtTemp,
    required this.maxIatTemp,
    required this.avgConsumptionKml,
    required this.fuelConsumedLiters,
    required this.estimatedCost,
    required this.totalMisfires,
    required this.maxKnockRetard,
    required this.sampleCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'vehicleProfile': vehicleProfile,
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'maxRpm': maxRpm,
      'maxBoostBar': maxBoostBar,
      'maxHp': maxHp,
      'maxTorqueKgfm': maxTorqueKgfm,
      'maxCoolantTemp': maxCoolantTemp,
      'maxOilTemp': maxOilTemp,
      'maxEgtTemp': maxEgtTemp,
      'maxIatTemp': maxIatTemp,
      'avgConsumptionKml': avgConsumptionKml,
      'fuelConsumedLiters': fuelConsumedLiters,
      'estimatedCost': estimatedCost,
      'totalMisfires': totalMisfires,
      'maxKnockRetard': maxKnockRetard,
      'sampleCount': sampleCount,
    };
  }

  factory TripLogRecord.fromJson(Map<String, dynamic> json) {
    return TripLogRecord(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      vehicleProfile: (json['vehicleProfile'] as String?) ?? 'VW TSI Universal',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toInt() ?? 0,
      maxRpm: (json['maxRpm'] as num?)?.toInt() ?? 0,
      maxBoostBar: (json['maxBoostBar'] as num?)?.toDouble() ?? 0.0,
      maxHp: (json['maxHp'] as num?)?.toDouble() ?? 0.0,
      maxTorqueKgfm: (json['maxTorqueKgfm'] as num?)?.toDouble() ?? 0.0,
      maxCoolantTemp: (json['maxCoolantTemp'] as num?)?.toInt() ?? 0,
      maxOilTemp: (json['maxOilTemp'] as num?)?.toInt() ?? 0,
      maxEgtTemp: (json['maxEgtTemp'] as num?)?.toInt() ?? 0,
      maxIatTemp: (json['maxIatTemp'] as num?)?.toInt() ?? 0,
      avgConsumptionKml: (json['avgConsumptionKml'] as num?)?.toDouble() ?? 0.0,
      fuelConsumedLiters: (json['fuelConsumedLiters'] as num?)?.toDouble() ?? 0.0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      totalMisfires: (json['totalMisfires'] as num?)?.toInt() ?? 0,
      maxKnockRetard: (json['maxKnockRetard'] as num?)?.toDouble() ?? 0.0,
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
    );
  }
}
