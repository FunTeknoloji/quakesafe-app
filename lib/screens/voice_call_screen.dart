import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../services/voice_call_service.dart';
import '../services/p2p_connection_service.dart';

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

class _VoiceCallScreenState extends State<VoiceCallScreen> with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isRecording = false;
  DateTime? _startTime;
  Timer? _timer;
  String _duration = '00:00';
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    _rippleController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
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
    _rippleController.dispose();
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
        Stack(
          alignment: Alignment.center,
          children: [
            if (!_isMuted) ...List.generate(3, (i) => _buildRippleEffect(i)),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent,
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 20)],
              ),
              child: const Icon(Icons.person_rounded, size: 60, color: Colors.white),
            ),
          ],
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hub_rounded, color: Colors.greenAccent, size: 14),
            const SizedBox(width: 8),
            Text(
              '${P2PConnectionService().endpointMap.length} CİHAZ BAĞLI | 16KHZ HQ',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoundButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: _isMuted ? Colors.redAccent : Colors.white10,
              onTap: () {
                bool newMute = !_isMuted;
                setState(() => _isMuted = newMute);
                widget.voiceCallService.toggleMute(newMute);
              },
            ),
            _buildRoundButton(
              icon: Icons.call_end_rounded,
              color: Colors.red,
              size: 80,
              iconSize: 32,
              onTap: _endCall,
            ),
            _buildRoundButton(
              icon: _isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded,
              color: _isRecording ? Colors.orangeAccent : Colors.white10,
              onTap: _toggleRecording,
            ),
          ],
        ),
      ],
    );
  }

  void _toggleRecording() async {
    if (_isRecording) {
      String? path = await widget.voiceCallService.stopRecording();
      setState(() => _isRecording = false);
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt tamamlandı: $path')));
      }
    } else {
      await widget.voiceCallService.startRecording();
      setState(() => _isRecording = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses kaydı başlatıldı')));
    }
  }

  Widget _buildRippleEffect(int index) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        double progress = (_rippleController.value + (index / 3)) % 1;
        return Container(
          width: 120 + (progress * 100),
          height: 120 + (progress * 100),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.redAccent.withOpacity(1 - progress), width: 2),
          ),
        );
      },
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
