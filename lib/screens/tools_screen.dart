import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:torch_light/torch_light.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _isFlashlightOn = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double? _heading = 0;
  List<double>? _accelerometerValues;

  @override
  void initState() {
    super.initState();
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading;
        });
      }
    });
    accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) {
        setState(() {
          _accelerometerValues = <double>[event.x, event.y, event.z];
        });
      }
    });
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

  Future<void> _makeSosCall() async {
    final Uri url = Uri.parse('tel:112');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _playSound(String fileName) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Sound error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName bulunamadı. Lütfen assets/sounds/$fileName dosyasını ekleyin.')),
        );
      }
    }
  }

  void _showFirstAid() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚑 Temel İlk Yardım Bilgileri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                const Divider(color: Colors.white24),
                _buildInfoItem('Kanamalar', 'Temiz bir bezle baskı uygulayın. Uzuv yükseltin.'),
                _buildInfoItem('Kırıklar', 'Hareketsiz tutun, sabitleyin (atellleme).'),
                _buildInfoItem('Yanıklar', 'Soğuk (buz değil) su altında 15-20 dk tutun.'),
                _buildInfoItem('Bilinç Kaybı', 'Yan yatış pozisyonuna (koma pozisyonu) getirin.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(desc, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Araçlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 30),

              // Compass
              _buildToolCard(
                'Pusula',
                Center(
                  child: Transform.rotate(
                    angle: ((_heading ?? 0) * (math.pi / 180) * -1),
                    child: const Icon(Icons.explore, size: 100, color: Colors.redAccent),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Spirit Level (simplified)
              _buildToolCard(
                'Su Terazisi',
                Column(
                  children: [
                    Text('X: ${_accelerometerValues?[0].toStringAsFixed(2) ?? "0"}', style: const TextStyle(color: Colors.white)),
                    Text('Y: ${_accelerometerValues?[1].toStringAsFixed(2) ?? "0"}', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
                      child: Stack(
                        children: [
                          Positioned(
                            left: ((_accelerometerValues?[0] ?? 0) + 10) * (MediaQuery.of(context).size.width - 100) / 20,
                            child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildToolButton(
                      _isFlashlightOn ? 'Feneri Kapat' : 'Feneri Aç',
                      _isFlashlightOn ? Icons.flash_off : Icons.flash_on,
                      _toggleFlashlight,
                      _isFlashlightOn ? Colors.orange : Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildToolButton(
                      'SOS Ara (112)',
                      Icons.phone,
                      _makeSosCall,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 20),
              const Text('Acil Durum Sesleri', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildToolButton('Siren', Icons.warning, () => _playSound('siren.mp3'), Colors.purple),
                  _buildToolButton('Düdük', Icons.music_note, () => _playSound('whistle.mp3'), Colors.blue),
                  _buildToolButton('Tiz Ses', Icons.notifications_active, () => _playSound('high_pitch.mp3'), Colors.orange),
                  _buildToolButton('Yüksek Bip', Icons.error, () => _playSound('beep.mp3'), Colors.indigo),
                ],
              ),
              const SizedBox(height: 20),
              _buildToolButton(
                'İlk Yardım Rehberi',
                Icons.medical_services,
                _showFirstAid,
                Colors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard(String title, Widget content) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(String label, IconData icon, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
