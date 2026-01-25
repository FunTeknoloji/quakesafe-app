import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/offline_main_wrapper.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.init();
    try {
      await BackgroundService.initialize();
    } catch (e) {
      debugPrint('Background Service Init Error: $e');
    }
    runApp(const QuakeSafeApp());
  }, (error, stack) {
    debugPrint('Uncaught error: $error');
  });
}

class QuakeSafeApp extends StatelessWidget {
  const QuakeSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuakeSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const MainGate(),
    );
  }
}

class MainGate extends StatefulWidget {
  const MainGate({super.key});

  @override
  State<MainGate> createState() => _MainGateState();
}

class _MainGateState extends State<MainGate> {
  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    // Request basic permissions first
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.contacts,
      Permission.storage,
      Permission.notification,
      Permission.phone,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();

    // Background location MUST be requested separately after fine location is granted on Android 11+
    if (statuses[Permission.location] == PermissionStatus.granted) {
      PermissionStatus backgroundStatus = await Permission.locationAlways.request();
      statuses[Permission.locationAlways] = backgroundStatus;
    }

    if (statuses[Permission.locationAlways] != PermissionStatus.granted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Konum İzni'),
            content: const Text('Arka planda çalışabilmek için konum iznini "Her zaman izin ver" olarak ayarlamanız gerekmektedir.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('TAMAM')),
              TextButton(onPressed: () => openAppSettings(), child: const Text('AYARLAR')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const OfflineMainWrapper();
  }
}
