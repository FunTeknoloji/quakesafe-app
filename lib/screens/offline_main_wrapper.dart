import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'offline_home_screen.dart';
import 'chat_screen.dart';
import '../services/app_state_service.dart';
import 'tools_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class OfflineMainWrapper extends StatefulWidget {
  const OfflineMainWrapper({super.key});

  @override
  State<OfflineMainWrapper> createState() => _OfflineMainWrapperState();
}

class _OfflineMainWrapperState extends State<OfflineMainWrapper> {
  int _selectedIndex = 0;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    _checkHardware();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    if (result.isNotEmpty && result.first != ConnectivityResult.none && !_promptShown) {
      _promptShown = true;
      _showOnlineSwitchPrompt();
    } else if (result.isEmpty || result.first == ConnectivityResult.none) {
      _promptShown = false;
    }
  }

  void _showOnlineSwitchPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('İnternet Mevcut', style: TextStyle(color: Colors.white)),
        content: const Text('İnternet ağı tespit edildi. Online moda geçmek istiyor musunuz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              _promptShown = false;
              AppStateService.allowAutoSwitch.value = false;
              Navigator.pop(context);
            },
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () {
              AppStateService.allowAutoSwitch.value = true;
              _promptShown = false;
              Navigator.pop(context);
            },
            child: const Text('Evet', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkHardware() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHardwareWarning();
    });
  }

  void _showHardwareWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Donanım Kontrolü', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Çevrimdışı sohbetin çalışması için Bluetooth ve Konum servislerinin açık olduğundan emin olun.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  final List<Widget> _screens = [
    const OfflineHomeScreen(),
    const ChatScreen(),
    const ToolsScreen(),
    const ContactsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Sohbet'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Araçlar'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Rehber'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
