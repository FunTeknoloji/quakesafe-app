import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:torch_light/torch_light.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  void _playSound(String fileName) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      debugPrint('Sound error: $e');
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
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    _buildTacticalInstrument(),
                    const SizedBox(height: 24),
                    _buildPrimaryActions(),
                    const SizedBox(height: 24),
                    _buildEmergencySounds(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          const Text(
            'TAKTİK ARAÇLAR',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Text('OFFLINE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalInstrument() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompassInstrument(),
              Container(width: 1, height: 120, color: Colors.white10),
              _buildLevelInstrument(),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'NAVİGASYON VE DENGE SENSÖRLERİ AKTİF',
            style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildCompassInstrument() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 2),
              ),
            ),
            Transform.rotate(
              angle: ((_heading ?? 0) * (math.pi / 180) * -1),
              child: const Icon(Icons.navigation_rounded, size: 40, color: Colors.redAccent),
            ),
            ...List.generate(4, (i) {
              final labels = ['N', 'E', 'S', 'W'];
              final angles = [0.0, math.pi/2, math.pi, 3*math.pi/2];
              return Transform.rotate(
                angle: angles[i],
                child: Container(
                  height: 90,
                  alignment: Alignment.topCenter,
                  child: Text(labels[i], style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        Text('${(_heading ?? 0).toStringAsFixed(0)}°', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
      ],
    );
  }

  Widget _buildLevelInstrument() {
    double x = _accelerometerValues?[0] ?? 0;
    double y = _accelerometerValues?[1] ?? 0;
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent.withOpacity(0.2), width: 2),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              transform: Matrix4.translationValues(x * 4, y * 4, 0),
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('SU TERAZİSİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            'FENER',
            _isFlashlightOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
            _isFlashlightOn ? Colors.orangeAccent : Colors.white24,
            _toggleFlashlight
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionTile(
            'SOS ÇAĞRISI',
            Icons.phone_forwarded_rounded,
            Colors.redAccent,
            () async {
              final Uri url = Uri.parse('tel:112');
              if (await canLaunchUrl(url)) await launchUrl(url);
            }
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySounds() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACİL DURUM SİNYALLERİ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildSoundButton('HAVA SİRENİ', 'siren.wav', Colors.purpleAccent),
          const SizedBox(height: 12),
          _buildSoundButton('KURTARMA DÜDÜĞÜ', 'whistle.wav', Colors.blueAccent),
          const SizedBox(height: 12),
          _buildSoundButton('YÜKSEK FREKANS', 'high_pitch.wav', Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildSoundButton(String label, String file, Color color) {
    return GestureDetector(
      onTap: () => _playSound(file),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: color),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.volume_up_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
