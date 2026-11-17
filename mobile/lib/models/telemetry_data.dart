class TelemetryData {
  final bool isConnected;
  final bool isSimulating;
  final int rpm;
  final int speed;
  final int mapKpa;
  final double boostBar;
  final double boostPsi;
  final double peakBoostBar;
  final double dynamicPeakBoostBar;
  final int shiftRpm;
  final int coolant;
  final int iat;
  final int tps;
  final int engineLoad;
  final double timingAdvance;
  final double stft;
  final double ltft;
  final double voltage;
  final String gear;
  final String vin;
  final String protocol;
  final String vehicleProfile;
  final List<String> dtcs;

  // 1. Virtual Dyno & Performance
  final double estimatedHp;
  final double estimatedTorqueNm;
  final double estimatedTorqueKgfm;
  final double peakHp;
  final double peakTorqueKgfm;

  // 2. High Pressure Fuel & Air/Fuel Mixture
  final double fuelRailPressureBar;
  final double lambda;
  final double afr;

  // 3. Oil & Exhaust Temperatures
  final int oilTemperature;
  final int egt;

  // 4. Trip Computer & Eco / Flex
  final double fuelConsumptionLh;
  final double fuelConsumptionKml;
  final double avgFuelConsumptionKml;
  final double totalFuelConsumedLiters;
  final double tripDistanceKm;
  final double tripDurationMinutes;
  final int ethanolPercent;
  final double fuelPricePerLiter;

  // 5. Cylinder Health & Misfire Counters
  final int misfiresCyl1;
  final int misfiresCyl2;
  final int misfiresCyl3;
  final int misfiresCyl4;
  final int misfiresCyl5;
  final int misfiresCyl6;
  final double knockRetard;

  // 6. Dynamics / G-Force
  final double longitudinalGForce;
  final double lateralGForce;

  const TelemetryData({
    this.isConnected = false,
    this.isSimulating = false,
    this.rpm = 0,
    this.speed = 0,
    this.mapKpa = 101,
    this.boostBar = 0.0,
    this.boostPsi = 0.0,
    this.peakBoostBar = 0.0,
    this.dynamicPeakBoostBar = 0.0,
    this.shiftRpm = 5200,
    this.coolant = 0,
    this.iat = 0,
    this.tps = 0,
    this.engineLoad = 0,
    this.timingAdvance = 0.0,
    this.stft = 0.0,
    this.ltft = 0.0,
    this.voltage = 0.0,
    this.gear = 'N',
    this.vin = '3VW4T7AU9KM516995',
    this.protocol = 'CAN 11/500',
    this.vehicleProfile = 'VW TSI Universal',
    this.dtcs = const [],
    this.estimatedHp = 0.0,
    this.estimatedTorqueNm = 0.0,
    this.estimatedTorqueKgfm = 0.0,
    this.peakHp = 0.0,
    this.peakTorqueKgfm = 0.0,
    this.fuelRailPressureBar = 50.0,
    this.lambda = 1.00,
    this.afr = 14.7,
    this.oilTemperature = 90,
    this.egt = 450,
    this.fuelConsumptionLh = 0.0,
    this.fuelConsumptionKml = 0.0,
    this.avgFuelConsumptionKml = 0.0,
    this.totalFuelConsumedLiters = 0.0,
    this.tripDistanceKm = 0.0,
    this.tripDurationMinutes = 0.0,
    this.ethanolPercent = 27,
    this.fuelPricePerLiter = 5.89,
    this.misfiresCyl1 = 0,
    this.misfiresCyl2 = 0,
    this.misfiresCyl3 = 0,
    this.misfiresCyl4 = 0,
    this.misfiresCyl5 = 0,
    this.misfiresCyl6 = 0,
    this.knockRetard = 0.0,
    this.longitudinalGForce = 0.0,
    this.lateralGForce = 0.0,
  });

  TelemetryData copyWith({
    bool? isConnected,
    bool? isSimulating,
    int? rpm,
    int? speed,
    int? mapKpa,
    double? boostBar,
    double? boostPsi,
    double? peakBoostBar,
    double? dynamicPeakBoostBar,
    int? shiftRpm,
    int? coolant,
    int? iat,
    int? tps,
    int? engineLoad,
    double? timingAdvance,
    double? stft,
    double? ltft,
    double? voltage,
    String? gear,
    String? vin,
    String? protocol,
    String? vehicleProfile,
    List<String>? dtcs,
    double? estimatedHp,
    double? estimatedTorqueNm,
    double? estimatedTorqueKgfm,
    double? peakHp,
    double? peakTorqueKgfm,
    double? fuelRailPressureBar,
    double? lambda,
    double? afr,
    int? oilTemperature,
    int? egt,
    double? fuelConsumptionLh,
    double? fuelConsumptionKml,
    double? avgFuelConsumptionKml,
    double? totalFuelConsumedLiters,
    double? tripDistanceKm,
    double? tripDurationMinutes,
    int? ethanolPercent,
    double? fuelPricePerLiter,
    int? misfiresCyl1,
    int? misfiresCyl2,
    int? misfiresCyl3,
    int? misfiresCyl4,
    int? misfiresCyl5,
    int? misfiresCyl6,
    double? knockRetard,
    double? longitudinalGForce,
    double? lateralGForce,
  }) {
    return TelemetryData(
      isConnected: isConnected ?? this.isConnected,
      isSimulating: isSimulating ?? this.isSimulating,
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      mapKpa: mapKpa ?? this.mapKpa,
      boostBar: boostBar ?? this.boostBar,
      boostPsi: boostPsi ?? this.boostPsi,
      peakBoostBar: peakBoostBar ?? this.peakBoostBar,
      dynamicPeakBoostBar: dynamicPeakBoostBar ?? this.dynamicPeakBoostBar,
      shiftRpm: shiftRpm ?? this.shiftRpm,
      coolant: coolant ?? this.coolant,
      iat: iat ?? this.iat,
      tps: tps ?? this.tps,
      engineLoad: engineLoad ?? this.engineLoad,
      timingAdvance: timingAdvance ?? this.timingAdvance,
      stft: stft ?? this.stft,
      ltft: ltft ?? this.ltft,
      voltage: voltage ?? this.voltage,
      gear: gear ?? this.gear,
      vin: vin ?? this.vin,
      protocol: protocol ?? this.protocol,
      vehicleProfile: vehicleProfile ?? this.vehicleProfile,
      dtcs: dtcs ?? this.dtcs,
      estimatedHp: estimatedHp ?? this.estimatedHp,
      estimatedTorqueNm: estimatedTorqueNm ?? this.estimatedTorqueNm,
      estimatedTorqueKgfm: estimatedTorqueKgfm ?? this.estimatedTorqueKgfm,
      peakHp: peakHp ?? this.peakHp,
      peakTorqueKgfm: peakTorqueKgfm ?? this.peakTorqueKgfm,
      fuelRailPressureBar: fuelRailPressureBar ?? this.fuelRailPressureBar,
      lambda: lambda ?? this.lambda,
      afr: afr ?? this.afr,
      oilTemperature: oilTemperature ?? this.oilTemperature,
      egt: egt ?? this.egt,
      fuelConsumptionLh: fuelConsumptionLh ?? this.fuelConsumptionLh,
      fuelConsumptionKml: fuelConsumptionKml ?? this.fuelConsumptionKml,
      avgFuelConsumptionKml: avgFuelConsumptionKml ?? this.avgFuelConsumptionKml,
      totalFuelConsumedLiters: totalFuelConsumedLiters ?? this.totalFuelConsumedLiters,
      tripDistanceKm: tripDistanceKm ?? this.tripDistanceKm,
      tripDurationMinutes: tripDurationMinutes ?? this.tripDurationMinutes,
      ethanolPercent: ethanolPercent ?? this.ethanolPercent,
      fuelPricePerLiter: fuelPricePerLiter ?? this.fuelPricePerLiter,
      misfiresCyl1: misfiresCyl1 ?? this.misfiresCyl1,
      misfiresCyl2: misfiresCyl2 ?? this.misfiresCyl2,
      misfiresCyl3: misfiresCyl3 ?? this.misfiresCyl3,
      misfiresCyl4: misfiresCyl4 ?? this.misfiresCyl4,
      misfiresCyl5: misfiresCyl5 ?? this.misfiresCyl5,
      misfiresCyl6: misfiresCyl6 ?? this.misfiresCyl6,
      knockRetard: knockRetard ?? this.knockRetard,
      longitudinalGForce: longitudinalGForce ?? this.longitudinalGForce,
      lateralGForce: lateralGForce ?? this.lateralGForce,
    );
  }
}
