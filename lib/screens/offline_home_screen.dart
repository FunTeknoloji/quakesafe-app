import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/survival_kit_service.dart';
import '../services/p2p_connection_service.dart';
import 'offline_main_wrapper.dart';
import 'guide_detail_screen.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Battery _battery = Battery();
  int _batteryLevel = 0;
  bool _isFlashlightOn = false;

  Map<String, bool> _kitItems = {};
  bool _isLoadingKit = true;
  Timer? _beaconTimer;

  @override
  void initState() {
    super.initState();
    _loadKit();
    _getBattery();
    _startEmergencyBeacon();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initAccelerometer();
  }

  void _initAccelerometer() {
    try {
      _accelerometerSub = accelerometerEventStream().listen((AccelerometerEvent event) {
        if (mounted) {
          setState(() {
            _tiltX = event.x;
            _tiltY = event.y;
          });
        }
      }, onError: (e) {
        debugPrint('Accelerometer error: $e');
      });
    } catch (e) {
      debugPrint('Accelerometer init error: $e');
    }
  }

  Future<void> _loadKit() async {
    try {
      final items = await SurvivalKitService.loadKit();
      if (mounted) {
        setState(() {
          _kitItems = items;
          _isLoadingKit = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingKit = false);
    }
  }

  Future<void> _getBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } catch (e) {}
  }

  Future<void> _toggleKitItem(String label, bool value) async {
    setState(() {
      _kitItems[label] = !value;
    });
    await SurvivalKitService.saveKit(_kitItems);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _accelerometerSub?.cancel();
    _beaconTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startEmergencyBeacon() {
    _beaconTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (!_isSafe) {
        Position pos = await Geolocator.getCurrentPosition();
        String beaconMsg = "🚨 OTOMATİK BEACON: YARDIM GEREKLİ! Konum: https://www.google.com/maps?q=${pos.latitude},${pos.longitude}";
        P2PConnectionService().broadcast(beaconMsg);
      }
    });
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
          ListenableBuilder(
            listenable: P2PConnectionService(),
            builder: (context, _) => Row(
              children: [
                Expanded(child: _buildDashboardStat('Eğim', '${_tiltX.toStringAsFixed(1)}°', FontAwesomeIcons.arrowsUpDownLeftRight)),
                Container(width: 1, height: 40, color: Colors.white10),
                Expanded(child: _buildDashboardStat('Cihaz', '${P2PConnectionService().nodes.length}', Icons.hub_rounded)),
                Container(width: 1, height: 40, color: Colors.white10),
                Expanded(child: _buildDashboardStat('Batarya', '%$_batteryLevel', _batteryLevel > 20 ? Icons.battery_full_rounded : Icons.battery_alert_rounded)),
              ],
            ),
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildToolCard('SOS', Icons.sos_rounded, Colors.redAccent, _toggleStatus, isLarge: true),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildToolCard('FENER', _isFlashlightOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded, Colors.orangeAccent, _toggleFlashlight, isLarge: true),
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildToolCard('SESLİ ARAMA', Icons.call_rounded, Colors.greenAccent, _startVoiceCall, isLarge: false),
      ],
    );
  }

  void _startVoiceCall() {
    final p2p = P2PConnectionService();
    if (p2p.nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlı cihaz yok')));
      return;
    }
    p2p.sendProtocolMessage('all', {'type': 'VOICE_SIG', 'cmd': 'START'});
  }

  void _shareLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      String url = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
      P2PConnectionService().broadcast('📍 KONUMUM: $url');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konumunuz paylaşıldı')));
    } catch (e) {}
  }

  void _sendEmergencySMS() async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getString('emergency_contact_number');
    final customMsg = prefs.getString('custom_sos_message') ?? 'ACİL DURUM! Yardıma ihtiyacım var. Konumum:';

    if (number == null || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acil durum kişisi ayarlanmamış! Lütfen Profilden ayarlayın.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition();
      String url = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
      final Uri uri = Uri.parse('sms:$number?body=$customMsg $url');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS gönderilemedi')));
    }
  }

  void _playWhistle() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/whistle.wav'));
    } catch (e) {}
  }

  Widget _buildToolCard(String title, IconData icon, Color color, VoidCallback onTap, {bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isLarge ? 120 : 60,
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.1))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]),
      ),
    );
  }

  Future<void> _toggleFlashlight() async {
    try {
      if (_isFlashlightOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() {
        _isFlashlightOn = !_isFlashlightOn;
      });
    } catch (e) {
      debugPrint('Flashlight error: $e');
    }
  }

  void _playSiren() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/siren.wav'));
    } catch (e) {
      debugPrint('Siren error: $e');
    }
  }

  Future<void> _makeSosCall() async {
    final Uri url = Uri.parse('tel:112');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _goToCompass() {
    OfflineMainWrapper.of(context)?.setTab(2); // Araçlar tab
  }

  Widget _buildModernGuideList() {
    return Column(children: [
      _buildGuideItem('DEPREM REHBERİ', 'Anlık yapılması gerekenler', Icons.menu_book_rounded, Colors.orangeAccent, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => GuideDetailScreen(
          title: 'DEPREM REHBERİ',
          content: [
            GuideContent('Deprem Anında Bina İçindeyseniz', 'Pencere, raf, avize gibi düşebilecek nesnelerden uzak durun. Sağlam bir masanın yanına ÇÖK-KAPAN-TUTUN yapın. Merdivenlere veya çıkışlara koşmayın.'),
            GuideContent('Deprem Anında Açık Alandaysanız', 'Binalardan, elektrik direklerinden ve ağaçlardan uzak durun. Başınızı koruyarak güvenli bir alanda bekleyin.'),
            GuideContent('Deprem Sonrası İlk Dakikalar', 'Sakin olun, çevrenizdekileri kontrol edin. Gaz ve elektrik vanalarını kapatın. Binayı merdivenleri kullanarak terk edin, asansör kullanmayın.'),
          ],
        )));
      }),
      _buildGuideItem('İLK YARDIM', 'Acil müdahale kılavuzu', Icons.medical_services_rounded, Colors.redAccent, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => GuideDetailScreen(
          title: 'İLK YARDIM REHBERİ',
          content: [
            GuideContent('Kanamalarda Müdahale', 'Kanayan yere temiz bir bezle bastırın. Mümkünse bölgeyi kalp seviyesinden yukarı kaldırın.'),
            GuideContent('Kırıklarda Müdahale', 'Kırık olduğundan şüphelenilen bölgeyi hareket ettirmeyin. Sert bir malzeme ile sabitleyin (atellleme).'),
            GuideContent('Bilinç Kaybı', 'Hastayı yan yatırarak soluk yolunun açık olduğundan emin olun. Tıbbi yardım gelene kadar başından ayrılmayın.'),
          ],
        )));
      }),
    ]);
  }

  Widget _buildGuideItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12))])),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
        ]),
      ),
    );
  }

  Widget _buildInteractiveKitCard() {
    if (_isLoadingKit) return const Center(child: CircularProgressIndicator());

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

    // Broadcast status to mesh network
    P2PConnectionService().broadcast(statusMsg);

    await DatabaseService.insertMessage(sender: 'SİSTEM', text: "Durumunuz güncellendi: $statusMsg", isMe: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Durumunuz paylaşıldı: $statusMsg'),
          backgroundColor: newStatus ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildKitToggle(String label, bool value) {
    return GestureDetector(
      onTap: () => _toggleKitItem(label, value),
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
