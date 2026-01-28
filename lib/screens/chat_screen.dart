import 'dart:async';
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
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path/path.dart' as p;
import '../models/message.dart' as model;
import '../services/database_service.dart';
import '../services/notification_service.dart';
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
  final P2PConnectionService _p2p = P2PConnectionService();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  DateTime? _lastMessageTime;
  bool _isCalling = false;
  String? _activeCallEndpoint;
  bool _isScanning = true;
  StreamSubscription? _dbSub;
  late int _sessionStartTime;

  void _onP2PChange() {
    if (mounted) setState(() {
      if (_p2p.endpointMap.isNotEmpty) _isScanning = false;
    });
  }

  void _onNewMessage() async {
    final data = await DatabaseService.getMessages();
    // Filter messages belonging to THIS session
    final sessionMessages = data.where((m) => m['timestamp'] >= _sessionStartTime).toList();
    if (mounted) {
      setState(() {
        messages = sessionMessages.map((m) => ChatMessage(
          sender: m['sender'],
          text: m['text'],
          isMe: m['isMe'] == 1,
          timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp']),
          type: m['type'] ?? 'text',
          extraData: m['extraData'],
          status: m['status'] ?? 'sent',
          priority: m['priority'] ?? 'normal',
        )).toList();
      });
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when navigating to this screen if needed
  }

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
    _p2p.addListener(_onP2PChange);
    _dbSub = DatabaseService.onMessageAdded.listen((_) => _onNewMessage());
    _initChat();
    _initTts();
  }

  void _initTts() {
    _tts.setLanguage("tr-TR");
  }

  Future<void> _initChat() async {
    String? name = await ProfileService.getUsername();
    if (name != null && name.isNotEmpty) {
      setState(() => userName = name);
    }
    // "her çık gir yapınca yeni sohbet olacak" - so we don't load old messages into current list
    setState(() {
      messages = [];
    });
    await _voiceCallService.init();

    // Use the new robust initMesh
    _p2p.initMesh(userName, onConnectionInitiated);
  }

  @override
  void dispose() {
    _p2p.removeListener(_onP2PChange);
    _dbSub?.cancel();
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
             _voiceCallService.receiveAudio(id, bytes);
             return;
          }

          String str = utf8.decode(bytes);

          // Handle new JSON format in Service
          if (str.startsWith('{')) {
            try {
              var data = jsonDecode(str);
              if (data['type'] == 'FILE_META') {
                _incomingFileMeta[data['payloadId']] = data;
                return;
              }
              if (data['type'] == 'VOICE_SIG') {
                _handleVoiceSignaling(id, data['cmd']);
                return;
              }
              // Pass to reliable service
              _p2p.handleIncomingPayload(id, payload);
              return;
            } catch (e) {}
          }

          // Legacy plain text (still support for simplicity)
          String sender = _p2p.endpointMap[id]?.nodeId ?? 'Bilinmeyen';
          String type = str.startsWith('📍 Konum:') ? 'location' : 'text';
          String? extra = type == 'location' ? str.split('📍 Konum: ').last : null;
          await DatabaseService.insertMessage(sender: sender, text: str, isMe: false, type: type, extraData: extra);
        } else if (payload.type == PayloadType.FILE) {
          _handleFilePayload(id, payload);
        }
      },
    );
  }

  void _handleVoiceSignaling(String id, String cmd) {
    if (cmd == 'START') {
      String caller = _p2p.endpointMap[id]?.nodeId ?? 'Bilinmeyen';
      NotificationService.showCallNotification(id: id.hashCode, callerName: caller);
      _showIncomingCallUI(id);
    } else if (cmd == 'ACCEPT') {
      _initiateCall(id);
    } else if (cmd == 'REJECT') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çağrı reddedildi')));
    } else if (cmd == 'STOP') {
      if (_isCalling) Navigator.pop(context);
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
      _voiceCallService.stopCall();
      NotificationService.cancelNotification(id.hashCode);
    }
  }


  void _showIncomingCallUI(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => IncomingCallScreen(
      callerName: _p2p.endpointMap[id]?.nodeId ?? 'Bilinmeyen',
      onAccept: () {
        Navigator.pop(context);
        _p2p.sendProtocolMessage(id, {'type': 'VOICE_SIG', 'cmd': 'ACCEPT'});
        _initiateCall(id);
      },
      onReject: () {
        Navigator.pop(context);
        _p2p.sendProtocolMessage(id, {'type': 'VOICE_SIG', 'cmd': 'REJECT'});
      },
    )));
  }

  void _handleFilePayload(String id, Payload payload) async {
    String path = payload.filePath!;
    String sender = _p2p.endpointMap[id]?.nodeId ?? 'Bilinmeyen';

    // Polling for metadata if not arrived yet
    int retries = 0;
    while (!_incomingFileMeta.containsKey(payload.id) && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    var meta = _incomingFileMeta[payload.id];
    String fileType = meta?['fileType'] ?? 'image';
    String originalName = meta?['fileName'] ?? p.basename(path);

    final appDir = await getApplicationDocumentsDirectory();
    final newPath = p.join(appDir.path, originalName);

    try {
      if (await File(path).exists()) {
        await File(path).copy(newPath);
        await DatabaseService.insertMessage(sender: sender, text: '[Resim]', isMe: false, type: fileType, extraData: newPath);
      }
    } catch (e) {
      debugPrint('File error: $e');
    }
  }

  void _startIncomingCall(String id) {
    setState(() { _isCalling = true; _activeCallEndpoint = id; });
    Navigator.push(context, MaterialPageRoute(builder: (context) => VoiceCallScreen(
      endpointId: id,
      voiceCallService: _voiceCallService,
    ))).then((_) {
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
    });
  }

  void _requestCall(String targetId) {
    _p2p.sendProtocolMessage(targetId, {'type': 'VOICE_SIG', 'cmd': 'START'});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çağrı isteği gönderildi...')));
  }

  void sendMessage() async {
    String text = _textController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (_lastMessageTime != null) {
      final diff = now.difference(_lastMessageTime!).inSeconds;
      if (diff < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SPAM KORUMASI: Lütfen ${5 - diff} saniye bekleyin.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    _lastMessageTime = now;
    _p2p.sendMessage(text: text);
    _textController.clear();
  }

  void _toggleVoiceCall() {
    if (_p2p.endpointMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlı cihaz yok')));
      return;
    }

    // Call everyone in the mesh
    _p2p.sendProtocolMessage('all', {'type': 'VOICE_SIG', 'cmd': 'START'});
    _initiateCall('all');
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
            title: Text(e.value.username, style: const TextStyle(color: Colors.white)),
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
      voiceCallService: _voiceCallService,
    ))).then((_) {
      setState(() { _isCalling = false; _activeCallEndpoint = null; });
    });
  }

  Future<void> _sendLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    String lat = pos.latitude.toStringAsFixed(6);
    String lng = pos.longitude.toStringAsFixed(6);
    String url = 'https://www.google.com/maps?q=$lat,$lng';
    String msg = '📍 KONUM BİLGİSİ\nEnlem: $lat\nBoylam: $lng\nHarita: $url';

    for (String id in _p2p.endpointMap.keys) {
      Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(msg)));
    }

    await DatabaseService.insertMessage(sender: 'Ben', text: msg, isMe: true, type: 'location', extraData: url);
    setState(() => messages.add(ChatMessage(sender: 'Ben', text: msg, isMe: true, type: 'location', extraData: url)));
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

  Future<void> _toggleSpeech() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
            }
          });
        });
      }
    }
  }

  void _speak(String text) async {
    await _tts.speak(text);
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
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
      color: Colors.black.withOpacity(0.95),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
          const SizedBox(height: 32),
          const Text('MESH AĞI TARANIYOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 12)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Çevredeki aktif QuakeSafe cihazları aranıyor. Lütfen diğer cihazlarda da bu ekranın açık olduğundan emin olun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: const Color(0xFF0A0A0A), border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent, size: 20),
            onPressed: () {
              _p2p.initMesh(userName, onConnectionInitiated);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ağ yenileniyor...')));
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showConnectedDevicesPopup,
              child: Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_p2p.endpointMap.length} CİHAZ AKTİF',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                      ),
                      const Text('Bağlantıları görmek için dokunun', style: TextStyle(color: Colors.white24, fontSize: 9)),
                    ],
                  ),
                ],
              ),
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

  void _showConnectedDevicesPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('BAĞLI CİHAZLAR', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: _p2p.endpointMap.isEmpty
            ? const Text('Bağlı cihaz yok', style: TextStyle(color: Colors.white38))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _p2p.endpointMap.length,
                itemBuilder: (context, i) {
                  final e = _p2p.endpointMap.values.elementAt(i);
                  return ListTile(
                    leading: const Icon(Icons.phone_android_rounded, color: Colors.redAccent),
                    title: Text(e.username, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('P2P Mesh Bağlantısı', style: TextStyle(color: Colors.white24, fontSize: 11)),
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    bool isMe = msg.isMe;
    bool isCritical = msg.priority == 'critical';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
            ? (isCritical ? Colors.red : Colors.redAccent.withOpacity(0.9))
            : (isCritical ? Colors.orange.withOpacity(0.2) : const Color(0xFF1A1A1A)),
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
            if (isCritical)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.yellow, size: 12),
                    SizedBox(width: 4),
                    Text('ACİL MESAJ', style: TextStyle(color: Colors.yellow, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            _buildContent(msg),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('HH:mm').format(msg.timestamp), style: TextStyle(color: isMe ? Colors.white60 : Colors.white24, fontSize: 9)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(msg.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'pending': return const Icon(Icons.access_time, size: 10, color: Colors.white38);
      case 'sent': return const Icon(Icons.check, size: 10, color: Colors.white70);
      case 'failed': return const Icon(Icons.error_outline, size: 10, color: Colors.red);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildContent(ChatMessage msg) {
    if (msg.type == 'image') return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(msg.extraData!)));
    if (msg.type == 'location') return _buildLocationPreview(msg.text, msg.extraData!);
    if (msg.type == 'voice') return Row(children: [const Icon(Icons.mic, size: 16, color: Colors.white70), const SizedBox(width: 8), const Text('Ses Mesajı', style: TextStyle(color: Colors.white, fontSize: 14)), IconButton(onPressed: () => _voiceCallService.playAudioFile(msg.extraData!), icon: const Icon(Icons.play_arrow, color: Colors.white))]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildSmallButton(Icons.volume_up_rounded, "Dinle", () => _speak(msg.text)),
            const SizedBox(width: 8),
            _buildSmallButton(Icons.copy_rounded, "Kopyala", () => _copy(msg.text)),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallButton(IconData icon, String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPreview(String text, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            // Force open in Google Maps by using the URL
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_rounded, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Text('GOOGLE MAPS\'TE AÇ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
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
          IconButton(
            onPressed: _toggleSpeech,
            icon: Icon(_isListening ? Icons.stop_circle : Icons.mic, color: _isListening ? Colors.redAccent : Colors.white54)
          ),
          IconButton(onPressed: sendMessage, icon: const Icon(Icons.send_rounded, color: Colors.redAccent)),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildAddIcon(Icons.location_on, 'Konum Paylaş', Colors.blue, _sendLocation),
            _buildAddIcon(Icons.report_problem, 'Acil Durum Mesajı', Colors.red, _sendEmergencyMessage),
          ]
        )
      )
    );
  }

  void _sendEmergencyMessage() {
    _p2p.sendMessage(text: "🚨 ACİL DURUM YARDIMI GEREKLİ!", priority: model.MessagePriority.SOS);
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
  final String status;
  final String priority;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.isMe,
    DateTime? timestamp,
    this.type = 'text',
    this.extraData,
    this.status = 'sent',
    this.priority = 'normal',
  }) : timestamp = timestamp ?? DateTime.now();
}

extension DateTimeMs on DateTime { int get ms => millisecondsSinceEpoch; }
