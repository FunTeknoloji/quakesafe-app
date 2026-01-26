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

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool _isMuted = false;
  bool _isRemoteMuted = false;
  bool _isSpeakerOn = true;
  bool _isRecording = false;
  DateTime? _startTime;
  Timer? _timer;
  String _duration = '00:00';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    P2PConnectionService().addListener(_checkParticipants);
    widget.voiceCallService.isTransmitting.addListener(_onTransmissionChanged);
    widget.voiceCallService.startCall(widget.endpointId);
  }

  void _onTransmissionChanged() {
    if (mounted) {
      setState(() {
        _isTalking = widget.voiceCallService.isTransmitting.value;
      });
    }
  }

  void _checkParticipants() {
    final p2p = P2PConnectionService();
    if (p2p.endpointMap.isEmpty) {
      debugPrint('No participants left, ending call.');
      _endCall();
      return;
    }

    if (p2p.connectionQuality.isNotEmpty) {
      double avg = p2p.connectionQuality.values.reduce((a, b) => a + b) / p2p.connectionQuality.length;
      if (avg < 5) {
        widget.voiceCallService.setQuality(8000);
      } else {
        widget.voiceCallService.setQuality(16000);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      final diff = now.difference(_startTime!);
      setState(() {
        _duration = '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  @override
  void dispose() {
    P2PConnectionService().removeListener(_checkParticipants);
    widget.voiceCallService.isTransmitting.removeListener(_onTransmissionChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _endCall() {
    widget.voiceCallService.stopCall();
    P2PConnectionService().sendProtocolMessage(widget.endpointId, {'type': 'VOICE_SIG', 'cmd': 'STOP'});
    if (mounted) Navigator.pop(context);
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
    return ListenableBuilder(
      listenable: P2PConnectionService(),
      builder: (context, _) {
        final endpoints = P2PConnectionService().endpointMap;
        return Column(
          children: [
            const Text(
              'KATILIMCILAR',
              style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                children: [
                  _buildParticipantAvatar('Ben', isMe: true),
                  ...endpoints.entries.map((e) => _buildParticipantAvatar(e.value.endpointName)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _duration,
              style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
          ],
        );
      }
    );
  }

  Widget _buildParticipantAvatar(String name, {bool isMe = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe ? Colors.blueAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
              border: Border.all(color: isMe ? Colors.blueAccent : Colors.redAccent, width: 2),
            ),
            child: Icon(Icons.person_rounded, size: 40, color: isMe ? Colors.blueAccent : Colors.redAccent),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
              'PTT Modu: Sadece bastığınızda sesiniz gider.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool _isTalking = false;

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hub_rounded, color: Colors.greenAccent, size: 14),
            const SizedBox(width: 8),
            Text(
              '${P2PConnectionService().endpointMap.length + 1} KATILIMCI | HQ AUDIO',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTapDown: (_) {
            setState(() => _isTalking = true);
            widget.voiceCallService.startPTT(widget.endpointId);
          },
          onTapUp: (_) {
            setState(() => _isTalking = false);
            widget.voiceCallService.stopPTT();
          },
          onTapCancel: () {
            setState(() => _isTalking = false);
            widget.voiceCallService.stopPTT();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTalking ? Colors.redAccent : Colors.redAccent.withOpacity(0.1),
              border: Border.all(color: Colors.redAccent, width: 4),
              boxShadow: _isTalking ? [BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 20)] : [],
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 48,
              color: _isTalking ? Colors.white : Colors.redAccent
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'BAS KONUŞ (MAX 10SN)',
          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoundButton(
              icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
              color: _isSpeakerOn ? Colors.white10 : Colors.blueAccent,
              label: _isSpeakerOn ? 'HOPARLÖR' : 'AHİZE',
              onTap: () {
                bool newState = !_isSpeakerOn;
                setState(() => _isSpeakerOn = newState);
                widget.voiceCallService.toggleSpeaker(newState);
              },
            ),
            _buildRoundButton(
              icon: _isRemoteMuted ? Icons.volume_off_rounded : Icons.volume_down_rounded,
              color: _isRemoteMuted ? Colors.orangeAccent : Colors.white10,
              label: 'DİĞERLERİNİ SUSTUR',
              onTap: () {
                bool newState = !_isRemoteMuted;
                setState(() => _isRemoteMuted = newState);
                widget.voiceCallService.toggleRemoteMute(newState);
              },
            ),
            _buildRoundButton(
              icon: Icons.call_end_rounded,
              color: Colors.red,
              label: 'KAPAT',
              onTap: _endCall,
            ),
            _buildRoundButton(
              icon: _isRecording ? Icons.stop_circle_rounded : Icons.fiber_manual_record_rounded,
              color: _isRecording ? Colors.orangeAccent : Colors.white10,
              label: 'KAYDET',
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

  Widget _buildRoundButton({required IconData icon, required Color color, double size = 64, double iconSize = 24, String? label, required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }
}
