import 'package:flutter/material.dart';
import 'package:quakesafe_app/screens/tools/calendar_screen.dart';
import 'package:quakesafe_app/screens/tools/mesh_settings_screen.dart';
import 'package:quakesafe_app/screens/tools/notepad_screen.dart';
import 'package:quakesafe_app/screens/tools/timer_screen.dart';
import 'package:quakesafe_app/screens/tools_screen.dart';

class ToolsBottomSheet extends StatelessWidget {
  const ToolsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Araçlar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildToolItem(Icons.flashlight_on, 'Fener', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ToolsScreen()));
              }),
              _buildToolItem(Icons.volume_up, 'Düdük', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ToolsScreen()));
              }),
              _buildToolItem(Icons.map, 'Harita', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ToolsScreen()));
              }),
              _buildToolItem(Icons.message, 'Hızlı Mesaj', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ToolsScreen()));
              }),
              _buildToolItem(Icons.note_alt, 'Not Defteri', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NotepadScreen()));
              }),
              _buildToolItem(Icons.timer, 'Kronometre', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TimerScreen()));
              }),
              _buildToolItem(Icons.calendar_today, 'Takvim', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
              }),
              _buildToolItem(Icons.settings, 'Ayarlar', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MeshSettingsScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
