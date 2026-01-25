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
          'Uygulamanın çalışması için Bluetooth ve Konum servislerinin açık olduğundan emin olun.',
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'Sohbet'),
            BottomNavigationBarItem(icon: Icon(Icons.construction_rounded), label: 'Araçlar'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Rehber'),
            BottomNavigationBarItem(icon: Icon(Icons.account_circle_rounded), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
