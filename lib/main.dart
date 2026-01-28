import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr_TR', null);

    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('Notification Service Init Error: $e');
    }

    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Critical startup error: $error');
    debugPrint(stack.toString());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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

      // Check if profile is complete
      final prefs = await SharedPreferences.getInstance();
      bool profileComplete = prefs.getString('username') != null &&
                            prefs.getString('emergency_contact_number') != null;

      if (mounted) {
        setState(() {
          _forceProfile = !profileComplete;
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

  bool _forceProfile = false;

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
    return const HomeScreen();
  }
}
