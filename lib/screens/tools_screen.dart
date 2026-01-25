import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:torch_light/torch_light.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/p2p_connection_service.dart';
import 'tools/notepad_screen.dart';
import 'tools/timer_screen.dart';
import 'tools/calendar_screen.dart';
import 'tools/light_mode_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _isFlashlightOn = false;
  bool _isSosFlashlightOn = false;
  Timer? _sosFlashTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double? _heading = 0;
  List<double>? _accelerometerValues;
  bool _isLooping = false;
  String? _currentlyPlaying;

  bool _hasCompass = true;
  bool _hasAccelerometer = true;

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  void _initSensors() {
    final compassStream = FlutterCompass.events;
    if (compassStream == null) {
      setState(() => _hasCompass = false);
    } else {
      compassStream.listen((event) {
        if (mounted) {
          setState(() {
            _heading = event.heading;
            if (event.heading == null) _hasCompass = false;
          });
        }
      });
    }

    try {
      accelerometerEventStream().listen((AccelerometerEvent event) {
        if (mounted) {
          setState(() {
            _accelerometerValues = <double>[event.x, event.y, event.z];
          });
        }
      }, onError: (e) {
        setState(() => _hasAccelerometer = false);
      });
    } catch (e) {
      setState(() => _hasAccelerometer = false);
    }
  }

  Future<void> _toggleFlashlight() async {
    if (_isSosFlashlightOn) _toggleSosFlashlight();
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

  void _toggleSosFlashlight() async {
    if (_isFlashlightOn) await _toggleFlashlight();

    if (_isSosFlashlightOn) {
      _sosFlashTimer?.cancel();
      await TorchLight.disableTorch();
      setState(() => _isSosFlashlightOn = false);
    } else {
      setState(() => _isSosFlashlightOn = true);
      bool state = false;
      _sosFlashTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
        state = !state;
        try {
          if (state) await TorchLight.enableTorch();
          else await TorchLight.disableTorch();
        } catch (e) {}
      });
    }
  }

  void _playSound(String fileName) async {
    try {
      if (_currentlyPlaying == fileName) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlaying = null);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(_isLooping ? ReleaseMode.loop : ReleaseMode.release);
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
      setState(() => _currentlyPlaying = fileName);

      _audioPlayer.onPlayerComplete.listen((event) {
        if (!_isLooping) {
          setState(() => _currentlyPlaying = null);
        }
      });
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  @override
  void dispose() {
    _sosFlashTimer?.cancel();
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
                    _buildRadarView(),
                    const SizedBox(height: 24),
                    _buildPrimaryActions(),
                    const SizedBox(height: 24),
                    _buildEmergencySounds(),
                    const SizedBox(height: 24),
                    _buildUtilityTools(),
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
    if (!_hasCompass) {
      return const Column(
        children: [
          Icon(Icons.explore_off_rounded, size: 60, color: Colors.white10),
          SizedBox(height: 12),
          Text('PUSULA YOK', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      );
    }
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
    if (!_hasAccelerometer) {
      return const Column(
        children: [
          Icon(Icons.speed_rounded, size: 60, color: Colors.white10),
          SizedBox(height: 12),
          Text('SENSÖR YOK', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      );
    }
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
    return Column(
      children: [
        Row(
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
                'FLAŞ SOS',
                Icons.emergency_rounded,
                _isSosFlashlightOn ? Colors.redAccent : Colors.white24,
                _toggleSosFlashlight
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildActionTile(
          'ACİL SERVİSİ ARA',
          Icons.phone_forwarded_rounded,
          Colors.redAccent,
          () async {
            final Uri url = Uri.parse('tel:112');
            if (await canLaunchUrl(url)) await launchUrl(url);
          }
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

  Widget _buildRadarView() {
    return ListenableBuilder(
      listenable: P2PConnectionService(),
      builder: (context, _) {
        final devices = P2PConnectionService().endpointMap.values.toList();
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('YAKINDAKİ CİHAZLAR (MESH)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('${devices.length} AKTİF', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              if (devices.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('Yakında cihaz bulunamadı...', style: TextStyle(color: Colors.white24, fontSize: 12)),
                ))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: devices.length,
                  itemBuilder: (context, i) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.radar_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(devices[i].endpointName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const Text('P2P Mesh Link', style: TextStyle(color: Colors.white24, fontSize: 9)),
                          ],
                        ),
                        const Spacer(),
                        _buildStabilityIndicator(P2PConnectionService().connectionQuality[P2PConnectionService().endpointMap.keys.elementAt(i)] ?? 10),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUtilityTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YARDIMCI ARAÇLAR', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildSmallTool('NOTLAR', Icons.note_alt_rounded, Colors.tealAccent, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotepadScreen()));
            }),
            _buildSmallTool('ZAMANLAYICI', Icons.timer_rounded, Colors.orangeAccent, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TimerScreen()));
            }),
            _buildSmallTool('TAKVİM', Icons.calendar_month_rounded, Colors.blueAccent, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
            }),
            _buildSmallTool('EKRAN IŞIĞI', Icons.light_mode_rounded, Colors.white, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LightModeScreen()));
            }),
            _buildSmallTool('POLİS IŞIĞI', Icons.local_police_rounded, Colors.blue, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LightModeScreen(isPolice: true)));
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallTool(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ACİL DURUM SİNYALLERİ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Text('DÖNGÜ', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                  Switch(
                    value: _isLooping,
                    onChanged: (v) => setState(() => _isLooping = v),
                    activeColor: Colors.redAccent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSoundButton('HAVA SİRENİ', 'siren.wav', Colors.purpleAccent),
          const SizedBox(height: 12),
          _buildSoundButton('KURTARMA DÜDÜĞÜ', 'whistle.wav', Colors.blueAccent),
          const SizedBox(height: 12),
          _buildSoundButton('YÜKSEK FREKANS', 'high_pitch.wav', Colors.orangeAccent),
          const SizedBox(height: 24),
          const Text('TİZ FREKANSLAR', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFreqChip('8 kHz', 'freq_8khz.wav'),
              _buildFreqChip('10 kHz', 'freq_10khz.wav'),
              _buildFreqChip('12 kHz', 'freq_12khz.wav'),
              _buildFreqChip('15 kHz', 'freq_15khz.wav'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityIndicator(int score) {
    Color color = score > 15 ? Colors.greenAccent : (score > 5 ? Colors.orangeAccent : Colors.redAccent);
    String label = score > 15 ? 'STABİL' : (score > 5 ? 'ORTA' : 'DÜŞÜK');
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Row(
          children: List.generate(3, (index) => Container(
            width: 8,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: index < (score / 10).ceil() ? color : Colors.white10,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildSoundButton(String label, String file, Color color) {
    bool isPlaying = _currentlyPlaying == file;
    return GestureDetector(
      onTap: () => _playSound(file),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isPlaying ? color.withOpacity(0.1) : Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPlaying ? color : color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: color),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isPlaying)
              const Icon(Icons.graphic_eq_rounded, color: Colors.white70, size: 16)
            else
              const Icon(Icons.volume_up_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFreqChip(String label, String file) {
    bool isPlaying = _currentlyPlaying == file;
    return ActionChip(
      label: Text(label),
      onPressed: () => _playSound(file),
      backgroundColor: isPlaying ? Colors.redAccent : Colors.white.withOpacity(0.05),
      labelStyle: TextStyle(color: isPlaying ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
      side: BorderSide(color: isPlaying ? Colors.redAccent : Colors.white10),
      avatar: Icon(isPlaying ? Icons.stop : Icons.waves, size: 14, color: isPlaying ? Colors.white : Colors.white38),
    );
  }
}
