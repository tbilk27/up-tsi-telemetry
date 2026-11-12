class TelemetryData {
  final bool isConnected;
  final bool isSimulating;
  final int rpm;
  final int speed;
  final int mapKpa;
  final double boostBar;
  final double boostPsi;
  final double peakBoostBar;
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
  final List<String> dtcs;

  const TelemetryData({
    this.isConnected = false,
    this.isSimulating = false,
    this.rpm = 0,
    this.speed = 0,
    this.mapKpa = 101,
    this.boostBar = 0.0,
    this.boostPsi = 0.0,
    this.peakBoostBar = 0.0,
    this.coolant = 0,
    this.iat = 0,
    this.tps = 0,
    this.engineLoad = 0,
    this.timingAdvance = 0.0,
    this.stft = 0.0,
    this.ltft = 0.0,
    this.voltage = 0.0,
    this.gear = 'N',
    this.vin = '9BWAH4124HT516995',
    this.protocol = 'CAN 11/500',
    this.dtcs = const [],
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
    List<String>? dtcs,
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
      dtcs: dtcs ?? this.dtcs,
    );
  }
}
