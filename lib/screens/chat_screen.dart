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
import 'package:path/path.dart' as p;
import '../services/database_service.dart';
import '../services/profile_service.dart';
import '../services/voice_call_service.dart';
import '../services/p2p_connection_service.dart';
import 'voice_call_screen.dart';
import 'incoming_call_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String userName = 'Kullanıcı';

  List<ChatMessage> messages = [];
  final TextEditingController _textController = TextEditingController();
  final VoiceCallService _voiceCallService = VoiceCallService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final P2PConnectionService _p2p = P2PConnectionService();

  bool _isCalling = false;
  bool _isRecording = false;
  String? _activeCallEndpoint;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _p2p.addListener(_onP2PChange);
    _initChat();
  }

  void _onP2PChange() {
    if (mounted) setState(() {
      if (_p2p.endpointMap.isNotEmpty) _isScanning = false;
    });
  }

  Future<void> _initChat() async {
    String? name = await ProfileService.getUsername();
    if (name != null && name.isNotEmpty) {
      setState(() => userName = name);
    }
    await _loadMessages();
    await _voiceCallService.init();
    _p2p.startDiscovery(userName, onConnectionInitiated);
    _p2p.startAdvertising(userName, onConnectionInitiated);
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
    _p2p.removeListener(_onP2PChange);
    super.dispose();
  }

  Map<int, Map<String, dynamic>> _incomingFileMeta = {};

  void onConnectionInitiated(String id, ConnectionInfo info) {
    Nearby().acceptConnection(id,
      onPayLoadRecieved: (id, payload) async {
        if (payload.type == PayloadType.BYTES) {
          Uint8List bytes = payload.bytes!;

          // Audio data check (no prefix, raw bytes)
          if (bytes.length >= 1024 && _isCalling && _activeCallEndpoint == id) {
             _voiceCallService.receiveAudio(bytes);
             return;
          }

          String str = utf8.decode(bytes);

          if (str.startsWith('CMD:')) {
            _handleCommand(id, str);
            return;
          }

          if (str.startsWith('{')) {
            try {
              var data = jsonDecode(str);
              if (data['type'] == 'FILE_META') {
                _incomingFileMeta[data['payloadId']] = data;
                return;
              }
            } catch (e) {}
          }

          String sender = _p2p.endpointMap[id]?.endpointName ?? 'Bilinmeyen';
          String type = str.startsWith('📍 Konum:') ? 'location' : 'text';
          String? extra = type == 'location' ? str.split('📍 Konum: ').last : null;
          await DatabaseService.insertMessage(sender: sender, text: str, isMe: false, type: type, extraData: extra);
          setState(() => messages.add(ChatMessage(sender: sender, text: str, isMe: false, type: type, extraData: extra)));
        } else if (payload.type == PayloadType.FILE) {
          // We wait for meta to arrive or use a default
          _handleFilePayload(id, payload);
        }
      },
    );
  }

  void _handleCommand(String id, String cmd) {
    if (cmd == 'CMD:VOICE_START') {
      _showIncomingCallUI(id);
    } else if (cmd == 'CMD:VOICE_ACCEPT') {
      _initiateCall(id);
    } else if (cmd == 'CMD:VOICE_REJECT') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çağrı reddedildi')));
    } else if (cmd == 'CMD:VOICE_STOP') {
      if (_isCalling) Navigator.pop(context);
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
      _voiceCallService.stopCall();
    }
  }

  void _showIncomingCallUI(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => IncomingCallScreen(
      callerName: _p2p.endpointMap[id]?.endpointName ?? 'Bilinmeyen',
      onAccept: () {
        Navigator.pop(context);
        Nearby().sendBytesPayload(id, Uint8List.fromList('CMD:VOICE_ACCEPT'.codeUnits));
        _initiateCall(id);
      },
      onReject: () {
        Navigator.pop(context);
        Nearby().sendBytesPayload(id, Uint8List.fromList('CMD:VOICE_REJECT'.codeUnits));
      },
    )));
  }

  void _handleFilePayload(String id, Payload payload) async {
    String path = payload.filePath!;
    String sender = _p2p.endpointMap[id]?.endpointName ?? 'Bilinmeyen';

    // Polling for metadata if not arrived yet
    int retries = 0;
    while (!_incomingFileMeta.containsKey(payload.id) && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    var meta = _incomingFileMeta[payload.id];
    String fileType = meta?['fileType'] ?? (path.endsWith('.m4a') ? 'voice' : 'image');
    String originalName = meta?['fileName'] ?? p.basename(path);

    final appDir = await getApplicationDocumentsDirectory();
    final newPath = p.join(appDir.path, originalName);

    try {
      if (await File(path).exists()) {
        await File(path).copy(newPath);
        await DatabaseService.insertMessage(sender: sender, text: fileType == 'voice' ? '[Sesli]' : '[Resim]', isMe: false, type: fileType, extraData: newPath);
        setState(() => messages.add(ChatMessage(sender: sender, text: fileType == 'voice' ? '[Sesli]' : '[Resim]', isMe: false, type: fileType, extraData: newPath)));
      }
    } catch (e) {
      debugPrint('File error: $e');
    }
  }

  void _startIncomingCall(String id) {
    setState(() { _isCalling = true; _activeCallEndpoint = id; });
    Navigator.push(context, MaterialPageRoute(builder: (context) => VoiceCallScreen(
      endpointId: id,
      endpointName: _p2p.endpointMap[id]?.endpointName ?? 'Bilinmeyen',
      voiceCallService: _voiceCallService,
    ))).then((_) {
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
    });
  }

  void _requestCall(String targetId) {
    Nearby().sendBytesPayload(targetId, Uint8List.fromList('CMD:VOICE_START'.codeUnits));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çağrı isteği gönderildi...')));
  }

  void sendMessage() async {
    String text = _textController.text.trim();
    if (text.isEmpty) return;
    Uint8List bytes = Uint8List.fromList(utf8.encode(text));
    for (String id in _p2p.endpointMap.keys) Nearby().sendBytesPayload(id, bytes);
    await DatabaseService.insertMessage(sender: 'Ben', text: text, isMe: true);
    setState(() {
      messages.add(ChatMessage(sender: 'Ben', text: text, isMe: true));
      _textController.clear();
    });
  }

  void _toggleVoiceCall() {
    if (_p2p.endpointMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlı cihaz yok')));
      return;
    }

    if (_p2p.endpointMap.length == 1) {
      _requestCall(_p2p.endpointMap.keys.first);
    } else {
      _showDevicePicker();
    }
  }

  void _showDevicePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('ARANACAK CİHAZI SEÇİN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ..._p2p.endpointMap.entries.map((e) => ListTile(
            leading: const Icon(Icons.phone_android, color: Colors.redAccent),
            title: Text(e.value.endpointName, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _requestCall(e.key);
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _initiateCall(String targetId) {
    setState(() { _isCalling = true; _activeCallEndpoint = targetId; });
    Navigator.push(context, MaterialPageRoute(builder: (context) => VoiceCallScreen(
      endpointId: targetId,
      endpointName: _p2p.endpointMap[targetId]?.endpointName ?? 'Bilinmeyen',
      voiceCallService: _voiceCallService,
    ))).then((_) {
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
    });
  }

  Future<void> _sendImage() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      for (String id in _p2p.endpointMap.keys) {
        int payloadId = await Nearby().sendFilePayload(id, image.path);
        _sendFileMeta(id, payloadId, image.path, 'image');
      }
      await DatabaseService.insertMessage(sender: 'Ben', text: '[Resim]', isMe: true, type: 'image', extraData: image.path);
      setState(() => messages.add(ChatMessage(sender: 'Ben', text: '[Resim]', isMe: true, type: 'image', extraData: image.path)));
    }
  }

  void _sendFileMeta(String to, int payloadId, String path, String type) {
    var meta = {
      'type': 'FILE_META',
      'payloadId': payloadId,
      'fileName': p.basename(path),
      'fileType': type
    };
    Nearby().sendBytesPayload(to, Uint8List.fromList(utf8.encode(jsonEncode(meta))));
  }

  Future<void> _sendLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    String url = 'https://www.google.com/maps?q=${pos.latitude},${pos.longitude}';
    String msg = '📍 Konum: $url';
    for (String id in _p2p.endpointMap.keys) Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(msg)));
    await DatabaseService.insertMessage(sender: 'Ben', text: msg, isMe: true, type: 'location', extraData: url);
    setState(() => messages.add(ChatMessage(sender: 'Ben', text: msg, isMe: true, type: 'location', extraData: url)));
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        for (String id in _p2p.endpointMap.keys) {
          int payloadId = await Nearby().sendFilePayload(id, path);
          _sendFileMeta(id, payloadId, path, 'voice');
        }
        await DatabaseService.insertMessage(sender: 'Ben', text: '[Sesli]', isMe: true, type: 'voice', extraData: path);
        setState(() => messages.add(ChatMessage(sender: 'Ben', text: '[Sesli]', isMe: true, type: 'voice', extraData: path)));
      }
    } else if (await _audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/v_${DateTime.now().ms}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
            if (_isScanning && _p2p.endpointMap.isEmpty) _buildScanningOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.redAccent),
          const SizedBox(height: 24),
          const Text('CİHAZLAR TARANIYOR...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          const Text('Lütfen yakındaki bir cihazın da tarama\nyaptığından emin olun.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 40),
          TextButton(onPressed: () => setState(() => _isScanning = false), child: const Text('ÇEVRİMDIŞI MODDA DEVAM ET', style: TextStyle(color: Colors.redAccent))),
        ],
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
                Text('${_p2p.endpointMap.length} Cihaz Bağlı', style: TextStyle(color: _isCalling ? Colors.greenAccent : Colors.white38, fontSize: 11)),
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
