import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/obd_bluetooth_service.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable full rotation (car dashboard mount friendly)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ObdBluetoothService()),
      ],
      child: const UpTsiTelemetryApp(),
    ),
  );
}

class UpTsiTelemetryApp extends StatelessWidget {
  const UpTsiTelemetryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Up! TSI Telemetry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0D14),
        primaryColor: const Color(0xFFE51A24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE51A24),
          secondary: Color(0xFF0070F3),
          surface: Color(0xFF121722),
          background: Color(0xFF0A0D14),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
