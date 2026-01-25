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
    accelerometerEventStream().listen((AccelerometerEvent event) {
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
          SnackBar(
            content: Text('$fileName bulunamadı.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ARAÇLAR',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: _buildSquareTool(
                      'Fener',
                      _isFlashlightOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      _isFlashlightOn ? Colors.orangeAccent : Colors.white24,
                      _toggleFlashlight,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildSquareTool(
                      'SOS Ara',
                      Icons.phone_in_talk_rounded,
                      Colors.redAccent,
                      _makeSosCall,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                'NAVİGASYON & DENGE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Transform.rotate(
                            angle: ((_heading ?? 0) * (math.pi / 180) * -1),
                            child: Icon(Icons.explore_rounded, size: 80, color: Colors.redAccent),
                          ),
                          const SizedBox(height: 10),
                          Text('Pusula', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 100, color: Colors.white10),
                    Expanded(
                      child: Column(
                        children: [
                          _buildLevelIndicator(),
                          const SizedBox(height: 10),
                          Text('Su Terazisi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                'ACİL DURUM SESLERİ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSoundChip('Siren', 'siren.mp3', Icons.warning_rounded, Colors.purpleAccent),
                  _buildSoundChip('Düdük', 'whistle.mp3', Icons.air_rounded, Colors.blueAccent),
                  _buildSoundChip('Tiz Ses', 'high_pitch.mp3', Icons.notifications_active_rounded, Colors.orangeAccent),
                  _buildSoundChip('Yüksek Bip', 'beep.mp3', Icons.error_rounded, Colors.indigoAccent),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquareTool(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelIndicator() {
    double x = _accelerometerValues?[0] ?? 0;
    double y = _accelerometerValues?[1] ?? 0;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          margin: EdgeInsets.only(
            left: x * 5,
            top: y * 5,
          ),
          decoration: BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundChip(String label, String file, IconData icon, Color color) {
    return ActionChip(
      onPressed: () => _playSound(file),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }
}
