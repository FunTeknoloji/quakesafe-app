import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/webview_screen.dart';
import 'screens/offline_main_wrapper.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'services/app_state_service.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const QuakeSafeApp());
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
        primarySwatch: Colors.red,
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
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    requestPermissions();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
      return;
    }
    if (!mounted) {
      return Future.value(null);
    }
    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    final oldStatus = _connectionStatus;
    final newStatus = result.isEmpty ? ConnectivityResult.none : result.first;

    setState(() {
      _connectionStatus = newStatus;
    });

    if (newStatus != ConnectivityResult.none) {
      SyncService.syncData();
    }

    if (oldStatus != ConnectivityResult.none && newStatus == ConnectivityResult.none) {
      NotificationService.showNotification(
        id: 1,
        title: 'Çevrimdışı Mod Aktif',
        body: 'İnternet bağlantısı kesildi. QuakeSafe çevrimdışı moduna geçildi.',
      );
    }
  }

  Future<void> requestPermissions() async {
    await [
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppStateService.allowAutoSwitch,
      builder: (context, allowSwitch, child) {
        if (_connectionStatus == ConnectivityResult.none || !allowSwitch) {
          return const OfflineMainWrapper();
        } else {
          return const WebViewScreen();
        }
      },
    );
  }
}
