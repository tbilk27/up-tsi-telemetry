class FuelLogEntry {
  final String id;
  final DateTime date;
  final double liters;
  final double totalPrice;
  final double pricePerLiter;
  final double odometerKm;
  final String fuelType;
  final bool isFullTank;
  final double? distanceSinceLastFuelKm;
  final double? calculatedKml;
  final double? costPerKm;
  final String? stationName;

  const FuelLogEntry({
    required this.id,
    required this.date,
    required this.liters,
    required this.totalPrice,
    required this.pricePerLiter,
    required this.odometerKm,
    this.fuelType = 'Gasolina Comum',
    this.isFullTank = true,
    this.distanceSinceLastFuelKm,
    this.calculatedKml,
    this.costPerKm,
    this.stationName,
  });

  FuelLogEntry copyWith({
    String? id,
    DateTime? date,
    double? liters,
    double? totalPrice,
    double? pricePerLiter,
    double? odometerKm,
    String? fuelType,
    bool? isFullTank,
    double? distanceSinceLastFuelKm,
    double? calculatedKml,
    double? costPerKm,
    String? stationName,
  }) {
    return FuelLogEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      liters: liters ?? this.liters,
      totalPrice: totalPrice ?? this.totalPrice,
      pricePerLiter: pricePerLiter ?? this.pricePerLiter,
      odometerKm: odometerKm ?? this.odometerKm,
      fuelType: fuelType ?? this.fuelType,
      isFullTank: isFullTank ?? this.isFullTank,
      distanceSinceLastFuelKm: distanceSinceLastFuelKm ?? this.distanceSinceLastFuelKm,
      calculatedKml: calculatedKml ?? this.calculatedKml,
      costPerKm: costPerKm ?? this.costPerKm,
      stationName: stationName ?? this.stationName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'liters': liters,
      'totalPrice': totalPrice,
      'pricePerLiter': pricePerLiter,
      'odometerKm': odometerKm,
      'fuelType': fuelType,
      'isFullTank': isFullTank,
      'distanceSinceLastFuelKm': distanceSinceLastFuelKm,
      'calculatedKml': calculatedKml,
      'costPerKm': costPerKm,
      'stationName': stationName,
    };
  }

  factory FuelLogEntry.fromJson(Map<String, dynamic> json) {
    return FuelLogEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      liters: (json['liters'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      pricePerLiter: (json['pricePerLiter'] as num).toDouble(),
      odometerKm: (json['odometerKm'] as num).toDouble(),
      fuelType: (json['fuelType'] as String?) ?? 'Gasolina Comum',
      isFullTank: (json['isFullTank'] as bool?) ?? true,
      distanceSinceLastFuelKm: (json['distanceSinceLastFuelKm'] as num?)?.toDouble(),
      calculatedKml: (json['calculatedKml'] as num?)?.toDouble(),
      costPerKm: (json['costPerKm'] as num?)?.toDouble(),
      stationName: json['stationName'] as String?,
    );
  }
}
