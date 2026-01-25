import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  void _startRinging() async {
    // Start ringtone
    await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    await _ringtonePlayer.play(AssetSource('sounds/beep.wav')); // Use beep as temporary ringtone

    // Start vibration
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      Vibration.vibrate(duration: 1000);
    });
  }

  @override
  void dispose() {
    _ringtonePlayer.stop();
    _ringtonePlayer.dispose();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Text(
              'GELEN ÇAĞRI',
              style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 40),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.person_rounded, size: 80, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            Text(
              widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Mesh Network üzerinden aranıyor...',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCallButton(
                    icon: Icons.close_rounded,
                    color: Colors.red,
                    label: 'REDDET',
                    onTap: widget.onReject,
                  ),
                  _buildCallButton(
                    icon: Icons.check_rounded,
                    color: Colors.greenAccent,
                    label: 'KABUL ET',
                    onTap: widget.onAccept,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }
}
