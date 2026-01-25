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
  String userName = 'User_${Random().nextInt(10000)}';

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
      setState(() {
        userName = name;
      });
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
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: onConnectionInitiated,
        onConnectionResult: (id, status) {
          debugPrint('Connection Status: $status');
        },
        onDisconnected: (id) {
          setState(() {
            endpointMap.remove(id);
          });
        },
      );
      debugPrint('Advertising: $a');
    } catch (e) {
      debugPrint('Error Advertising: $e');
    }
  }

  void startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          // Auto connect to anyone found for easier "offline emergency chat"
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: onConnectionInitiated,
            onConnectionResult: (id, status) {
              debugPrint('Discovery Connection Status: $status');
            },
            onDisconnected: (id) {
              setState(() {
                endpointMap.remove(id);
              });
            },
          );
        },
        onEndpointLost: (id) {
          debugPrint('Endpoint lost: $id');
        },
      );
      debugPrint('Discovery: $a');
    } catch (e) {
      debugPrint('Error Discovery: $e');
    }
  }

  void onConnectionInitiated(String id, ConnectionInfo info) {
    setState(() {
      endpointMap[id] = info;
    });
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (id, payload) async {
        if (payload.type == PayloadType.BYTES) {
          Uint8List bytes = payload.bytes!;
          // Check if it's audio data (very short and frequent, or marked)
          // For simplicity, let's assume if we are in a call, it's audio.
          // In a real app, we'd use a prefix byte.
          if (_isCalling && _activeCallEndpoint == id) {
             _voiceCallService.receiveAudio(bytes);
             return;
          }

          String str = utf8.decode(bytes);
          if (str.startsWith('CMD:VOICE_START')) {
            setState(() {
              _isCalling = true;
              _activeCallEndpoint = id;
            });
            _voiceCallService.startCall(id);
            return;
          } else if (str.startsWith('CMD:VOICE_STOP')) {
            setState(() {
              _isCalling = false;
              _activeCallEndpoint = null;
            });
            _voiceCallService.stopCall();
            return;
          }

          String sender = endpointMap[id]?.endpointName ?? 'Bilinmeyen';
          String type = 'text';
          String? extraData;

          if (str.startsWith('📍 Konum:')) {
            type = 'location';
            extraData = str.split('📍 Konum: ').last;
          }

          await DatabaseService.insertMessage(
            sender: sender,
            text: str,
            isMe: false,
            type: type,
            extraData: extraData,
          );

          setState(() {
            messages.add(ChatMessage(
              sender: sender,
              text: str,
              isMe: false,
              timestamp: DateTime.now(),
              type: type,
              extraData: extraData,
            ));
          });
        } else if (payload.type == PayloadType.FILE) {
          String path = payload.filePath!;
          String sender = endpointMap[id]?.endpointName ?? 'Bilinmeyen';

          // Determine if it's image or voice based on some logic or metadata
          // For now, let's assume if it ends with .m4a it's voice, else image
          String type = path.endsWith('.m4a') ? 'voice' : 'image';

          await DatabaseService.insertMessage(
            sender: sender,
            text: type == 'voice' ? '[Sesli Mesaj]' : '[Resim]',
            isMe: false,
            type: type,
            extraData: path,
          );

          setState(() {
            messages.add(ChatMessage(
              sender: sender,
              text: type == 'voice' ? '[Sesli Mesaj]' : '[Resim]',
              isMe: false,
              timestamp: DateTime.now(),
              type: type,
              extraData: path,
            ));
          });
        }
      },
    );
  }

  void sendMessage() async {
    String text = _textController.text.trim();
    if (text.isEmpty) return;

    Uint8List bytes = Uint8List.fromList(utf8.encode(text));
    for (String endpointId in endpointMap.keys) {
      Nearby().sendBytesPayload(endpointId, bytes);
    }

    await DatabaseService.insertMessage(
      sender: 'Ben ($userName)',
      text: text,
      isMe: true,
    );
    setState(() {
      messages.add(ChatMessage(
        sender: 'Ben ($userName)',
        text: text,
        isMe: true,
        timestamp: DateTime.now(),
      ));
      _textController.clear();
    });
  }

  void _toggleVoiceCall() {
    if (endpointMap.isEmpty) return;
    String targetId = endpointMap.keys.first;

    if (_isCalling) {
      _sendControlMsg('CMD:VOICE_STOP', targetId);
      _voiceCallService.stopCall();
      setState(() {
        _isCalling = false;
        _activeCallEndpoint = null;
      });
    } else {
      _sendControlMsg('CMD:VOICE_START', targetId);
      _voiceCallService.startCall(targetId);
      setState(() {
        _isCalling = true;
        _activeCallEndpoint = targetId;
      });
    }
  }

  void _sendControlMsg(String msg, String endpointId) {
    Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(msg)));
  }

  Future<void> _sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      for (String id in endpointMap.keys) {
        Nearby().sendFilePayload(id, image.path);
      }
      await DatabaseService.insertMessage(
        sender: 'Ben ($userName)',
        text: '[Resim]',
        isMe: true,
        type: 'image',
        extraData: image.path,
      );
      setState(() {
        messages.add(ChatMessage(
          sender: 'Ben ($userName)',
          text: '[Resim]',
          isMe: true,
          timestamp: DateTime.now(),
          type: 'image',
          extraData: image.path,
        ));
      });
    }
  }

  Future<void> _sendLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    String locUrl = 'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
    String locMsg = '📍 Konum: $locUrl';

    Uint8List bytes = Uint8List.fromList(utf8.encode(locMsg));
    for (String id in endpointMap.keys) {
      Nearby().sendBytesPayload(id, bytes);
    }

    await DatabaseService.insertMessage(
      sender: 'Ben ($userName)',
      text: locMsg,
      isMe: true,
      type: 'location',
      extraData: locUrl,
    );
    setState(() {
      messages.add(ChatMessage(
        sender: 'Ben ($userName)',
        text: locMsg,
        isMe: true,
        timestamp: DateTime.now(),
        type: 'location',
        extraData: locUrl,
      ));
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        for (String id in endpointMap.keys) {
          Nearby().sendFilePayload(id, path);
        }
        await DatabaseService.insertMessage(
          sender: 'Ben ($userName)',
          text: '[Sesli Mesaj]',
          isMe: true,
          type: 'voice',
          extraData: path,
        );
        setState(() {
          messages.add(ChatMessage(
            sender: 'Ben ($userName)',
            text: '[Sesli Mesaj]',
            isMe: true,
            timestamp: DateTime.now(),
            type: 'voice',
            extraData: path,
          ));
        });
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _downloadChat() async {
    String chatLog = messages.map((m) => '${m.sender}: ${m.text}').join('\n');
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/quakesafe_chat_log.txt');
    await file.writeAsString(chatLog);

    await Share.shareXFiles([XFile(file.path)], text: 'QuakeSafe Sohbet Geçmişi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.redAccent, Colors.red.shade900]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.group_rounded, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCalling ? '📞 Görüşme Aktif' : 'ÇEVRİMDIŞI SOHBET',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                ),
                Text(
                  '${endpointMap.length} cihaz bağlandı',
                  style: TextStyle(color: _isCalling ? Colors.greenAccent : Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isCalling ? Icons.call_end_rounded : Icons.call_rounded, color: _isCalling ? Colors.redAccent : Colors.greenAccent),
            onPressed: _toggleVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded, color: Colors.white70),
            onPressed: _downloadChat,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    bool isMe = msg.isMe;
    String timeStr = DateFormat('HH:mm').format(msg.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.redAccent : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 20),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                msg.sender,
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            if (!isMe) const SizedBox(height: 6),
            _buildMessageContent(msg),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(color: isMe ? Colors.white60 : Colors.white24, fontSize: 10),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg) {
    if (msg.type == 'image' && msg.extraData != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(msg.extraData!)),
          ),
          const SizedBox(height: 8),
          const Text('Resim Gönderildi', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
    } else if (msg.type == 'location' && msg.extraData != null) {
      return InkWell(
        onTap: () async {
          final url = Uri.parse(msg.extraData!);
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Konum Paylaşıldı', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Haritada Aç', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      );
    } else if (msg.type == 'voice' && msg.extraData != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('Sesli Mesaj', style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            onPressed: () {
              _voiceCallService.playAudioFile(msg.extraData!);
            },
          ),
        ],
      );
    } else {
      return Text(
        msg.text,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      );
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white54),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.grey[900],
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                builder: (context) => _buildAddMenu(),
              );
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Bir mesaj yazın...',
                  hintStyle: TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          IconButton(
            icon: Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                     color: _isRecording ? Colors.redAccent : Colors.white54),
            onPressed: _toggleRecording,
          ),
          const SizedBox(width: 5),
          Container(
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMenu() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAddOption(Icons.image_rounded, 'Resim', Colors.orangeAccent, () {
            Navigator.pop(context);
            _sendImage();
          }),
          _buildAddOption(Icons.location_on_rounded, 'Konum', Colors.blueAccent, () {
            Navigator.pop(context);
            _sendLocation();
          }),
          _buildAddOption(Icons.insert_drive_file_rounded, 'Dosya', Colors.greenAccent, () {}),
        ],
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
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
