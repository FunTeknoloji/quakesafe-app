import 'package:flutter/material.dart';
import 'offline_home_screen.dart';
import 'chat_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _checkHardware();
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
