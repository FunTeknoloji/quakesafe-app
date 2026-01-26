import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/p2p_connection_service.dart';
import 'package:nearby_connections/nearby_connections.dart';

class MeshSettingsScreen extends StatefulWidget {
  const MeshSettingsScreen({super.key});

  @override
  State<MeshSettingsScreen> createState() => _MeshSettingsScreenState();
}

class _MeshSettingsScreenState extends State<MeshSettingsScreen> {
  bool _useBluetooth = true;
  bool _useWifi = true;
  bool _useHotspot = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBluetooth = prefs.getBool('mesh_use_bluetooth') ?? true;
      _useWifi = prefs.getBool('mesh_use_wifi') ?? true;
      _useHotspot = prefs.getBool('mesh_use_hotspot') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mesh_use_bluetooth', _useBluetooth);
    await prefs.setBool('mesh_use_wifi', _useWifi);
    await prefs.setBool('mesh_use_hotspot', _useHotspot);

    // Restart mesh with new settings
    final p2p = P2PConnectionService();
    // Use stored name
    String name = prefs.getString('username') ?? 'User';
    p2p.initMesh(name, (id, info) {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesh Ayarları Kaydedildi ve Yeniden Başlatıldı'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('MESH AYARLARI'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MESH MODLARI', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildToggleTile('Bluetooth Mesh', 'Kısa mesafe, düşük güç tüketimi.', _useBluetooth, (v) => setState(() => _useBluetooth = v)),
            _buildToggleTile('Wi-Fi Direct', 'Yüksek hız, uzun mesafe.', _useWifi, (v) => setState(() => _useWifi = v)),
            _buildToggleTile('Hotspot', 'Wi-Fi yoksa cihazlar arası köprü.', _useHotspot, (v) => setState(() => _useHotspot = v)),
            const SizedBox(height: 40),
            const Text('AĞ DURUMU', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Wi-Fi önceliklidir. Wi-Fi bağlantısı kurulamadığında otomatik olarak Bluetooth Mesh ağına geçilir.',
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('AYARLARI UYGULA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildToggleTile(String title, String desc, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.redAccent),
        ],
      ),
    );
  }
}
