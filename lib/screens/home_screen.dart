import 'package:flutter/material.dart';
import 'package:quakesafe_app/models/message.dart' as model;
import 'package:quakesafe_app/services/p2p_connection_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'tools_bottom_sheet.dart';
import 'chat_screen.dart';
import 'disaster_guide_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Placeholder pages for navigation
  static const List<Widget> _widgetOptions = <Widget>[
    MainContent(),
    ChatScreen(),
    DisasterGuideScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Guide',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}

class MainContent extends StatefulWidget {
  const MainContent({super.key});

  @override
  State<MainContent> createState() => _MainContentState();
}

class _MainContentState extends State<MainContent> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;

  @override
  void initState() {
    super.initState();
    _battery.batteryLevel.then((level) {
      setState(() {
        _batteryLevel = level;
      });
    });

    _battery.onBatteryStateChanged.listen((BatteryState state) {
      _battery.batteryLevel.then((level) {
        setState(() {
          _batteryLevel = level;
          _batteryState = state;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(context),
          const Spacer(),
          _buildSOSButton(context),
          const Spacer(),
          _buildQuickActions(context),
          const SizedBox(height: 80), // Space for the bottom nav bar
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent, size: 20),
                onPressed: () {
                  P2PConnectionService().initMesh('Kullanıcı', (id, info) {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ağ yenileniyor...')));
                },
              ),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: P2PConnectionService(),
                builder: (context, _) {
                  return Text(
                    '${P2PConnectionService().endpointMap.length} Cihaz Aktif',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                _batteryState == BatteryState.charging
                    ? Icons.battery_charging_full
                    : Icons.battery_full,
                color: _batteryLevel > 20 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                '$_batteryLevel%',
                style: TextStyle(
                  color: _batteryLevel > 20 ? Colors.green : Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(BuildContext context) {
    return Column(
      children: [
        Text(
          'SAFE',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onLongPress: () {
            P2PConnectionService().sendMessage(
              text: "🚨 ACİL DURUM YARDIMI GEREKLİ!",
              priority: model.MessagePriority.SOS,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SOS'),
              ),
            );
          },
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8B0000), // Darker Red
              border: Border.all(color: Colors.red, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'HOLD FOR SOS',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionButton(context, Icons.flashlight_on, 'Fener', () {}),
          _buildQuickActionButton(context, Icons.volume_up, 'Düdük', () {}),
          _buildQuickActionButton(context, Icons.notifications, 'Bildirimler', () {}),
          _buildQuickActionButton(context, Icons.apps, 'Araçlar', () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => const ToolsBottomSheet(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 30),
          onPressed: onPressed,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
