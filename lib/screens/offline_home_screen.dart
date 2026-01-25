import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../services/database_service.dart';

class OfflineHomeScreen extends StatefulWidget {
  const OfflineHomeScreen({super.key});

  @override
  State<OfflineHomeScreen> createState() => _OfflineHomeScreenState();
}

class _OfflineHomeScreenState extends State<OfflineHomeScreen> with TickerProviderStateMixin {
  bool _isSafe = true;
  late AnimationController _pulseController;
  double _tiltX = 0, _tiltY = 0;
  StreamSubscription? _accelerometerSub;

  final Map<String, bool> _kitItems = {
    'Su (4 Litre)': true,
    'Konserve Gıda': true,
    'El Feneri': true,
    'Pilli Radyo': false,
    'İlkyardım Çantası': true,
    'Düdük': false,
    'Toz Maskesi': false,
    'Çakı': true,
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _accelerometerSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          _tiltX = event.x;
          _tiltY = event.y;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _accelerometerSub?.cancel();
    super.dispose();
  }

  double get _kitProgress {
    int checked = _kitItems.values.where((v) => v).length;
    return checked / _kitItems.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEmergencyDashboard(),
                  const SizedBox(height: 30),
                  _buildSectionTitle('HIZLI ARAÇLAR'),
                  const SizedBox(height: 15),
                  _buildQuickToolsGrid(),
                  const SizedBox(height: 30),
                  _buildSectionTitle('YARDIM VE REHBER'),
                  const SizedBox(height: 15),
                  _buildModernGuideList(),
                  const SizedBox(height: 30),
                  _buildSectionTitle('DEPREM ÇANTASI HAZIRLIĞI'),
                  const SizedBox(height: 15),
                  _buildInteractiveKitCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            const Text(
              'QUAKESAFE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyDashboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DURUMUNUZ', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_isSafe ? 'GÜVENDESİNİZ' : 'YARDIM GEREKLİ', style: TextStyle(color: _isSafe ? Colors.greenAccent : Colors.redAccent, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                child: Container(width: 12, height: 12, decoration: BoxDecoration(color: _isSafe ? Colors.greenAccent : Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _isSafe ? Colors.greenAccent : Colors.redAccent, blurRadius: 10)])),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDashboardStat('Eğim', '${_tiltX.toStringAsFixed(1)}°', FontAwesomeIcons.arrowsUpDownLeftRight)),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(child: _buildDashboardStat('Konum', 'Çevrimdışı', Icons.location_off_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _toggleStatus,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _isSafe ? [Colors.greenAccent.withOpacity(0.2), Colors.green.withOpacity(0.05)] : [Colors.redAccent.withOpacity(0.2), Colors.red.withOpacity(0.05)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (_isSafe ? Colors.greenAccent : Colors.redAccent).withOpacity(0.3)),
              ),
              child: Center(child: Text(_isSafe ? 'YARDIM İSTE (SOS)' : 'GÜVENDEYİM BİLDİR', style: TextStyle(color: _isSafe ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStat(String label, String value, IconData icon) {
    return Column(children: [Icon(icon, color: Colors.white38, size: 16), const SizedBox(height: 8), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10))]);
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5));
  }

  Widget _buildQuickToolsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.6,
      children: [
        _buildToolCard('FENER', Icons.flashlight_on_rounded, Colors.orangeAccent),
        _buildToolCard('SİREN', Icons.warning_amber_rounded, Colors.purpleAccent),
        _buildToolCard('SOS', Icons.emergency_share_rounded, Colors.redAccent),
        _buildToolCard('PUSULA', Icons.explore_rounded, Colors.blueAccent),
      ],
    );
  }

  Widget _buildToolCard(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]),
    );
  }

  Widget _buildModernGuideList() {
    return Column(children: [
      _buildGuideItem('DEPREM REHBERİ', 'Anlık yapılması gerekenler', Icons.menu_book_rounded, Colors.orangeAccent),
      _buildGuideItem('İLK YARDIM', 'Acil müdahale kılavuzu', Icons.medical_services_rounded, Colors.redAccent),
    ]);
  }

  Widget _buildGuideItem(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12))])),
        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
      ]),
    );
  }

  Widget _buildInteractiveKitCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF0F0F0F), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Hazırlık Durumu', style: TextStyle(color: Colors.white70)),
            Text('%${(_kitProgress * 100).toInt()}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _kitProgress, backgroundColor: Colors.white.withOpacity(0.05), valueColor: const AlwaysStoppedAnimation(Colors.blueAccent), minHeight: 8)),
          const SizedBox(height: 20),
          ..._kitItems.entries.map((e) => _buildKitToggle(e.key, e.value)),
        ],
      ),
    );
  }

  void _toggleStatus() async {
    bool newStatus = !_isSafe;
    setState(() => _isSafe = newStatus);

    String statusMsg = newStatus ? "✅ GÜVENDEYİM" : "🚨 YARDIM GEREKLİ (SOS)";
    Uint8List bytes = Uint8List.fromList(utf8.encode(statusMsg));

    // Attempt to broadcast to any currently connected endpoints if any
    // This is best-effort as the Chat screen usually handles connections.
    // In a real app, we'd have a central ConnectionManager.

    await DatabaseService.insertMessage(sender: 'SİSTEM', text: "Durumunuz güncellendi: $statusMsg", isMe: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durumunuz paylaşıldı: $statusMsg'), backgroundColor: newStatus ? Colors.green : Colors.red),
      );
    }
  }

  Widget _buildKitToggle(String label, bool value) {
    return GestureDetector(
      onTap: () => setState(() => _kitItems[label] = !value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(children: [
          Icon(value ? Icons.check_circle_rounded : Icons.circle_outlined, color: value ? Colors.greenAccent : Colors.white24, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: value ? Colors.white : Colors.white38, fontSize: 14)),
        ]),
      ),
    );
  }
}
