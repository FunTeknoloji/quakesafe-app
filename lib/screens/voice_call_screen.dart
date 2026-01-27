import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/p2p_connection_service.dart';
import '../services/voice_call_service.dart';
import '../models/node.dart';

class VoiceCallScreen extends StatefulWidget {
  final String endpointId;
  final VoiceCallService voiceCallService;

  const VoiceCallScreen({
    super.key,
    required this.endpointId,
    required this.voiceCallService,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool _isSpeakerOn = true;
  bool _isRecording = false;
  DateTime? _startTime;
  Timer? _timer;
  String _duration = '00:00';
  bool _isTalking = false;
  final P2PConnectionService _p2pService = P2PConnectionService();
  final Map<String, bool> _mutedUsers = {};

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    WakelockPlus.enable();
    _p2pService.addListener(_onP2PChange);
    widget.voiceCallService.isTransmitting.addListener(_onTransmissionChanged);
    widget.voiceCallService.startCall(widget.endpointId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    _p2pService.removeListener(_onP2PChange);
    widget.voiceCallService.isTransmitting.removeListener(_onTransmissionChanged);
    widget.voiceCallService.stopCall();
    super.dispose();
  }

  void _onTransmissionChanged() {
    if (mounted) {
      setState(() {
        _isTalking = widget.voiceCallService.isTransmitting.value;
      });
    }
  }

  void _onP2PChange() {
    if (mounted) {
      setState(() {});
      final currentNodes = _p2pService.endpointMap.keys.toSet();
      currentNodes.add(_p2pService.selfNodeId);
      if (!currentNodes.contains(widget.endpointId)) {
        _endCall(showToast: true);
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

  void _endCall({bool showToast = false}) {
    widget.voiceCallService.stopCall();
    if (showToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arama sonlandırıldı.')));
    }
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute(String nodeId) {
    setState(() {
      _mutedUsers[nodeId] = !(_mutedUsers[nodeId] ?? false);
    });
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
            _buildConnectionQualityIndicator(),
            const SizedBox(height: 20),
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
        const Text(
          'GÖRÜŞME',
          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: ListenableBuilder(
            listenable: _p2pService,
            builder: (context, _) {
              final nodes = _p2pService.endpointMap.values.toList();
              return ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                children: nodes.map((node) => _buildParticipantAvatar(node)).toList(),
              );
            },
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

  Widget _buildParticipantAvatar(Node node) {
    final isMe = node.nodeId == _p2pService.selfNodeId;
    final isMuted = _mutedUsers[node.nodeId] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (!isMe) {
                _showMuteDialog(node);
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe ? Colors.blueAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                border: Border.all(
                  color: (isMe ? Colors.blueAccent : Colors.redAccent).withOpacity(isMuted ? 0.3 : 1.0),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: (isMe ? Colors.blueAccent : Colors.redAccent).withOpacity(isMuted ? 0.3 : 1.0),
                  ),
                  if (isMuted)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.6),
                      ),
                      child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 24),
                    )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isMe ? 'Siz' : (node.nodeId.substring(0, 6)),
            style: TextStyle(
              color: Colors.white.withOpacity(isMuted ? 0.3 : 1.0),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showMuteDialog(Node node) {
    final isMuted = _mutedUsers[node.nodeId] ?? false;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${node.nodeId.substring(0, 6)} için işlem'),
        content: Text('Bu kullanıcıyı susturmak veya sesini açmak ister misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              _toggleMute(node.nodeId);
              Navigator.pop(context);
            },
            child: Text(isMuted ? 'Sesi Aç' : 'Sustur'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionQualityIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.signal_cellular_alt_rounded, color: Colors.greenAccent, size: 16),
          SizedBox(width: 12),
          Text(
            'Bağlantı Kalitesi: İyi',
            style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) => widget.voiceCallService.startPTT(widget.endpointId),
          onTapUp: (_) => widget.voiceCallService.stopPTT(),
          onTapCancel: () => widget.voiceCallService.stopPTT(),
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
              color: _isTalking ? Colors.white : Colors.redAccent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'BAS KONUŞ',
          style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildRoundButton(
              icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
              color: _isSpeakerOn ? Colors.blueAccent : Colors.white10,
              label: _isSpeakerOn ? 'HOPARLÖR' : 'AHİZE',
              onTap: () {
                setState(() => _isSpeakerOn = !_isSpeakerOn);
                widget.voiceCallService.toggleSpeaker(_isSpeakerOn);
              },
            ),
            _buildRoundButton(
              icon: Icons.call_end_rounded,
              color: Colors.red.withOpacity(0.8),
              label: 'KAPAT',
              onTap: () => _endCall(),
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
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt tamamlandı: $path')));
      }
    } else {
      await widget.voiceCallService.startRecording();
      setState(() => _isRecording = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses kaydı başlatıldı.')));
      }
    }
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    double size = 64,
    double iconSize = 24,
    String? label,
    required VoidCallback onTap,
  }) {
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
