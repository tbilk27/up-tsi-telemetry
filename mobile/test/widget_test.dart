import 'package:flutter_test/flutter_test.dart';
import 'package:up_tsi_telemetry/models/telemetry_data.dart';
import 'package:up_tsi_telemetry/services/fuel_log_service.dart';
import 'package:up_tsi_telemetry/services/obd_bluetooth_service.dart';
import 'package:up_tsi_telemetry/services/trip_logger_service.dart';

void main() {
  test('ObdBluetoothService initial state and settings', () {
    final obd = ObdBluetoothService();
    expect(obd.isConnected, isFalse);
    expect(obd.isSimulating, isFalse);
    expect(obd.shiftRpm, 5200);
    obd.setShiftRpm(5800);
    expect(obd.shiftRpm, 5800);
  });

  test('FuelLogService calculates consumption on full tank entries', () async {
    final fuelLog = FuelLogService();
    await fuelLog.addEntry(
      liters: 40.0,
      totalPrice: 240.0,
      odometerKm: 10000.0,
      isFullTank: true,
    );
    await fuelLog.addEntry(
      liters: 40.0,
      totalPrice: 240.0,
      odometerKm: 10560.0,
      isFullTank: true,
    );
    expect(fuelLog.overallAverageKml, 14.0);
  });

  test('TripLoggerService records telemetry sample and saves trip', () async {
    final logger = TripLoggerService();
    logger.recordSample(const TelemetryData(
      isSimulating: true,
      rpm: 2800,
      speed: 75,
      boostBar: 0.65,
      estimatedHp: 98.5,
      tripDistanceKm: 5.2,
    ));
    expect(logger.isRecording, isTrue);
    expect(logger.activeSampleCount, 1);

    final record = await logger.finishAndSaveTrip();
    expect(record, isNotNull);
    expect(record!.maxSpeedKmh, 75);
    expect(record.maxRpm, 2800);
    expect(record.maxBoostBar, 0.65);
    expect(logger.history.length, 1);
  });
}
