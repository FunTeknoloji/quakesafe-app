import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../services/voice_call_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String endpointId;
  final String endpointName;
  final VoiceCallService voiceCallService;

  const VoiceCallScreen({
    super.key,
    required this.endpointId,
    required this.endpointName,
    required this.voiceCallService,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool _isMuted = false;
  DateTime? _startTime;
  Timer? _timer;
  String _duration = '00:00';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    widget.voiceCallService.startCall(widget.endpointId);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final diff = now.difference(_startTime!);
      setState(() {
        _duration = '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _endCall() {
    widget.voiceCallService.stopCall();
    Nearby().sendBytesPayload(widget.endpointId, Uint8List.fromList('CMD:VOICE_STOP'.codeUnits));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            _buildUserInfo(),
            const Spacer(),
            _buildWarningCard(),
            const SizedBox(height: 40),
            _buildControls(),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.redAccent.withOpacity(0.1),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.person_rounded, size: 60, color: Colors.redAccent),
        ),
        const SizedBox(height: 24),
        Text(
          widget.endpointName,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _duration,
          style: const TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 2),
        ),
      ],
    );
  }

  Widget _buildWarningCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Çevrimdışı bağlantı nedeniyle seste gecikmeler yaşanabilir.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRoundButton(
          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: _isMuted ? Colors.redAccent : Colors.white10,
          onTap: () => setState(() => _isMuted = !_isMuted),
        ),
        _buildRoundButton(
          icon: Icons.call_end_rounded,
          color: Colors.red,
          size: 80,
          iconSize: 32,
          onTap: _endCall,
        ),
        _buildRoundButton(
          icon: Icons.volume_up_rounded,
          color: Colors.white10,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildRoundButton({required IconData icon, required Color color, double size = 64, double iconSize = 24, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
