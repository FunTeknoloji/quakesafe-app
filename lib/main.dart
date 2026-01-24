import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/webview_screen.dart';
import 'screens/offline_home_screen.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuakeSafeApp());
}

class QuakeSafeApp extends StatelessWidget {
  const QuakeSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuakeSafe',
      theme: ThemeData(
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
    setState(() {
      _connectionStatus = result.isEmpty ? ConnectivityResult.none : result.first;
    });
  }

  Future<void> requestPermissions() async {
    await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
      Permission.contacts,
      Permission.storage,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionStatus == ConnectivityResult.none) {
      return const OfflineHomeScreen();
    } else {
      return const WebViewScreen();
    }
  }
}
