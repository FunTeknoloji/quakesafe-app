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

  void _playEmergencySound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/siren.mp3'));
    } catch (e) {
      debugPrint('Siren sound error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Siren sesi dosyası bulunamadı. Lütfen assets/sounds/siren.mp3 dosyasını ekleyin.')),
        );
      }
    }
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
              _buildToolButton(
                'Acil Durum Sesi Çal',
                Icons.volume_up,
                _playEmergencySound,
                Colors.purple,
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
