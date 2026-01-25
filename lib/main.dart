import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/offline_main_wrapper.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('Notification Service Init Error: $e');
    }

    runApp(const QuakeSafeApp());
  }, (error, stack) {
    debugPrint('Critical startup error: $error');
    debugPrint(stack.toString());
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
  bool _isInitializing = true;
  String _status = 'Başlatılıyor...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _status = 'İzinler kontrol ediliyor...');
      await _requestPermissions();

      setState(() => _status = 'Servisler başlatılıyor...');
      await Future.delayed(const Duration(seconds: 1));
      try {
        await BackgroundService.initialize();
      } catch (e) {
        debugPrint('BG Init failed: $e');
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Init error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Stage 1: Basic Permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();

    // Stage 2: Hardware & Social
    await [
      Permission.camera,
      Permission.microphone,
      Permission.contacts,
      Permission.phone,
      Permission.storage,
    ].request();

    // Stage 3: Background Location (Sequential)
    if (await Permission.location.isGranted) {
      if (!await Permission.locationAlways.isGranted) {
        await Permission.locationAlways.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'QUAKESAFE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    return const OfflineMainWrapper();
  }
}
