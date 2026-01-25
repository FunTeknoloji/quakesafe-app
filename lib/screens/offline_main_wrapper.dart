import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'offline_home_screen.dart';
import 'chat_screen.dart';
import 'tools_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class OfflineMainWrapper extends StatefulWidget {
  const OfflineMainWrapper({super.key});

  static _OfflineMainWrapperState? of(BuildContext context) =>
      context.findAncestorStateOfType<_OfflineMainWrapperState>();

  @override
  State<OfflineMainWrapper> createState() => _OfflineMainWrapperState();
}

class _OfflineMainWrapperState extends State<OfflineMainWrapper> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Key _chatKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      FlutterBackgroundService().invoke("setForeground");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    if (state == AppLifecycleState.paused) {
      FlutterBackgroundService().invoke("setBackground");
    } else if (state == AppLifecycleState.resumed) {
      FlutterBackgroundService().invoke("setForeground");
    }
  }

  void setTab(int index) {
    setState(() {
      if (index == 1 && _selectedIndex != 1) {
        _chatKey = UniqueKey();
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const OfflineHomeScreen(),
          ChatScreen(key: _chatKey), // Forces new session when entering
          const ToolsScreen(),
          const ContactsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildModernBottomBar(),
    );
  }

  Widget _buildModernBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.dashboard_rounded, 'Ana Sayfa'),
            _buildNavItem(1, Icons.chat_bubble_outline_rounded, 'Sohbet'),
            _buildNavItem(2, Icons.build_circle_outlined, 'Araçlar'),
            _buildNavItem(3, Icons.people_outline_rounded, 'Rehber'),
            _buildNavItem(4, Icons.person_outline_rounded, 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.redAccent : Colors.white38,
              size: 24,
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  '', // Compact label or hidden to save space
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
