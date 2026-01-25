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
  String _selectedStrategy = 'CLUSTER';
  bool _preferWifi = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedStrategy = prefs.getString('mesh_strategy') ?? 'CLUSTER';
      _preferWifi = prefs.getBool('mesh_prefer_wifi') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mesh_strategy', _selectedStrategy);
    await prefs.setBool('mesh_prefer_wifi', _preferWifi);

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
            const Text('BAĞLANTI STRATEJİSİ', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildStrategyTile('CLUSTER (Önerilen)', 'Çok sayıda cihaz için ağ yapısı. Herkes herkesle konuşabilir.', 'CLUSTER'),
            _buildStrategyTile('STAR', 'Bir merkez cihaz etrafında hızlı bağlantı. Dosya paylaşımı için iyidir.', 'STAR'),
            _buildStrategyTile('POINT_TO_POINT', 'Birebir en yüksek hız.', 'P2P'),
            const SizedBox(height: 40),
            const Text('TRANSPORT AYARLARI', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 16),
            _buildToggleTile('Wi-Fi Direct Kullan', 'Daha uzun mesafe ve yüksek hız sağlar.', _preferWifi, (v) => setState(() => _preferWifi = v)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Not: Nearby Connections bağlantı türünü (BT/Wi-Fi) otomatik seçer. Wi-Fi kapatılırsa sadece Bluetooth kullanılır.',
                style: TextStyle(color: Colors.white24, fontSize: 10),
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

  Widget _buildStrategyTile(String title, String desc, String value) {
    bool isSelected = _selectedStrategy == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStrategy = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.1) : const Color(0xFF121212),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.redAccent : Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.redAccent),
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
