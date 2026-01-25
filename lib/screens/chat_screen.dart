import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../services/profile_service.dart';
import '../services/voice_call_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  String userName = 'Kullanıcı';

  Map<String, ConnectionInfo> endpointMap = {};
  List<ChatMessage> messages = [];
  final TextEditingController _textController = TextEditingController();
  final VoiceCallService _voiceCallService = VoiceCallService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isCalling = false;
  bool _isRecording = false;
  String? _activeCallEndpoint;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    String? name = await ProfileService.getUsername();
    if (name != null && name.isNotEmpty) {
      setState(() => userName = name);
    }
    await _loadMessages();
    await _voiceCallService.init();
    startDiscovery();
    startAdvertising();
  }

  Future<void> _loadMessages() async {
    final data = await DatabaseService.getMessages();
    setState(() {
      messages = data.map((m) => ChatMessage(
        sender: m['sender'],
        text: m['text'],
        isMe: m['isMe'] == 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp']),
        type: m['type'] ?? 'text',
        extraData: m['extraData'],
      )).toList();
    });
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  void startAdvertising() async {
    try {
      await Nearby().startAdvertising(userName, strategy,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: (id, status) => debugPrint('Status: $status'),
        onDisconnected: (id) => setState(() => endpointMap.remove(id)),
      );
    } catch (e) { debugPrint('Error: $e'); }
  }

  void startDiscovery() async {
    try {
      await Nearby().startDiscovery(userName, strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(userName, id,
            onConnectionInitiated: onConnectionInitiated,
            onConnectionResult: (id, status) => debugPrint('Status: $status'),
            onDisconnected: (id) => setState(() => endpointMap.remove(id)),
          );
        },
        onEndpointLost: (id) {},
      );
    } catch (e) { debugPrint('Error: $e'); }
  }

  void onConnectionInitiated(String id, ConnectionInfo info) {
    setState(() => endpointMap[id] = info);
    Nearby().acceptConnection(id,
      onPayLoadRecieved: (id, payload) async {
        if (payload.type == PayloadType.BYTES) {
          Uint8List bytes = payload.bytes!;
          if (_isCalling && _activeCallEndpoint == id) {
             _voiceCallService.receiveAudio(bytes);
             return;
          }
          String str = utf8.decode(bytes);
          if (str.startsWith('CMD:VOICE_START')) {
            setState(() { _isCalling = true; _activeCallEndpoint = id; });
            _voiceCallService.startCall(id);
            return;
          } else if (str.startsWith('CMD:VOICE_STOP')) {
            setState(() { _isCalling = false; _activeCallEndpoint = null; });
            _voiceCallService.stopCall();
            return;
          }

          String sender = endpointMap[id]?.endpointName ?? 'Bilinmeyen';
          String type = str.startsWith('📍 Konum:') ? 'location' : 'text';
          String? extra = type == 'location' ? str.split('📍 Konum: ').last : null;
          await DatabaseService.insertMessage(sender: sender, text: str, isMe: false, type: type, extraData: extra);
          setState(() => messages.add(ChatMessage(sender: sender, text: str, isMe: false, type: type, extraData: extra)));
        } else if (payload.type == PayloadType.FILE) {
          String path = payload.filePath!;
          String sender = endpointMap[id]?.endpointName ?? 'Bilinmeyen';
          String type = path.endsWith('.m4a') ? 'voice' : 'image';
          await DatabaseService.insertMessage(sender: sender, text: type == 'voice' ? '[Sesli]' : '[Resim]', isMe: false, type: type, extraData: path);
          setState(() => messages.add(ChatMessage(sender: sender, text: type == 'voice' ? '[Sesli]' : '[Resim]', isMe: false, type: type, extraData: path)));
        }
      },
    );
  }

  void sendMessage() async {
    String text = _textController.text.trim();
    if (text.isEmpty) return;
    Uint8List bytes = Uint8List.fromList(utf8.encode(text));
    for (String id in endpointMap.keys) Nearby().sendBytesPayload(id, bytes);
    await DatabaseService.insertMessage(sender: 'Ben', text: text, isMe: true);
    setState(() {
      messages.add(ChatMessage(sender: 'Ben', text: text, isMe: true));
      _textController.clear();
    });
  }

  void _toggleVoiceCall() {
    if (endpointMap.isEmpty) return;
    String targetId = endpointMap.keys.first;
    if (_isCalling) {
      Nearby().sendBytesPayload(targetId, Uint8List.fromList(utf8.encode('CMD:VOICE_STOP')));
      _voiceCallService.stopCall();
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
    } else {
      Nearby().sendBytesPayload(targetId, Uint8List.fromList(utf8.encode('CMD:VOICE_START')));
      _voiceCallService.startCall(targetId);
      setState(() { _isCalling = true; _activeCallEndpoint = targetId; });
    }
  }

  Future<void> _sendImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      for (String id in endpointMap.keys) Nearby().sendFilePayload(id, image.path);
      await DatabaseService.insertMessage(sender: 'Ben', text: '[Resim]', isMe: true, type: 'image', extraData: image.path);
      setState(() => messages.add(ChatMessage(sender: 'Ben', text: '[Resim]', isMe: true, type: 'image', extraData: image.path)));
    }
  }

  Future<void> _sendLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    String url = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
    String msg = '📍 Konum: $url';
    for (String id in endpointMap.keys) Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(msg)));
    await DatabaseService.insertMessage(sender: 'Ben', text: msg, isMe: true, type: 'location', extraData: url);
    setState(() => messages.add(ChatMessage(sender: 'Ben', text: msg, isMe: true, type: 'location', extraData: url)));
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        for (String id in endpointMap.keys) Nearby().sendFilePayload(id, path);
        await DatabaseService.insertMessage(sender: 'Ben', text: '[Sesli]', isMe: true, type: 'voice', extraData: path);
        setState(() => messages.add(ChatMessage(sender: 'Ben', text: '[Sesli]', isMe: true, type: 'voice', extraData: path)));
      }
    } else if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      await _audioRecorder.start(const RecordConfig(), path: '${dir.path}/v_${DateTime.now().ms}.m4a');
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTacticalHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: messages.length,
                itemBuilder: (context, i) => _buildMessageBubble(messages[i]),
              ),
            ),
            _buildTacticalInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.redAccent.withOpacity(0.1), child: const Icon(Icons.hub_rounded, color: Colors.redAccent, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isCalling ? 'ÇAĞRI AKTİF' : 'MESH SOHBET', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                Text('${endpointMap.length} Cihaz Bağlı', style: TextStyle(color: _isCalling ? Colors.greenAccent : Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isCalling ? Icons.call_end : Icons.call, color: _isCalling ? Colors.redAccent : Colors.greenAccent),
            onPressed: _toggleVoiceCall,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    bool isMe = msg.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.redAccent.withOpacity(0.9) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(msg.sender, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildContent(msg),
            const SizedBox(height: 4),
            Text(DateFormat('HH:mm').format(msg.timestamp), style: TextStyle(color: isMe ? Colors.white60 : Colors.white24, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ChatMessage msg) {
    if (msg.type == 'image') return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(msg.extraData!)));
    if (msg.type == 'location') return _buildLocationPreview(msg.extraData!);
    if (msg.type == 'voice') return Row(children: [const Icon(Icons.mic, size: 16, color: Colors.white70), const SizedBox(width: 8), const Text('Ses Mesajı', style: TextStyle(color: Colors.white, fontSize: 14)), IconButton(onPressed: () => _voiceCallService.playAudioFile(msg.extraData!), icon: const Icon(Icons.play_arrow, color: Colors.white))]);
    return Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14));
  }

  Widget _buildLocationPreview(String url) {
    return InkWell(
      onTap: () async { if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url)); },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
        child: const Row(children: [Icon(Icons.location_on, color: Colors.redAccent), SizedBox(width: 8), Text('Konumu Gör', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildTacticalInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F0F0F), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          IconButton(onPressed: _showAddMenu, icon: const Icon(Icons.add_box_outlined, color: Colors.white54)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
              child: TextField(controller: _textController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Mesaj Gönder...', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none)),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _toggleRecording, icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic, color: _isRecording ? Colors.redAccent : Colors.white54)),
          IconButton(onPressed: sendMessage, icon: const Icon(Icons.send_rounded, color: Colors.redAccent)),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1A1A1A), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (context) => Padding(padding: const EdgeInsets.all(32), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _buildAddIcon(Icons.image, 'Resim', Colors.orange, _sendImage),
      _buildAddIcon(Icons.location_on, 'Konum', Colors.blue, _sendLocation),
    ])));
  }

  Widget _buildAddIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: () { Navigator.pop(context); onTap(); }, child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]));
  }
}

class ChatMessage {
  final String sender;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final String type; // 'text', 'image', 'location', 'voice'
  final String? extraData;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.isMe,
    DateTime? timestamp,
    this.type = 'text',
    this.extraData,
  }) : timestamp = timestamp ?? DateTime.now();
}

extension DateTimeMs on DateTime { int get ms => millisecondsSinceEpoch; }
