import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import '../services/profile_service.dart';

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
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;

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
    // Auto accept connection
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (id, payload) async {
        if (payload.type == PayloadType.BYTES) {
          String str = utf8.decode(payload.bytes!);
          String sender = endpointMap[id]?.endpointName ?? 'Bilinmeyen';
          await DatabaseService.insertMessage(sender, str, false);
          setState(() {
            messages.add(ChatMessage(
              sender: sender,
              text: str,
              isMe: false,
            ));
          });
        } else if (payload.type == PayloadType.FILE) {
          // Handle voice message file
          String path = payload.filePath!;
          setState(() {
            messages.add(ChatMessage(
              sender: endpointMap[id]?.endpointName ?? 'Bilinmeyen',
              text: '[Sesli Mesaj]',
              isMe: false,
              isAudio: true,
              audioPath: path,
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

    await DatabaseService.insertMessage('Ben ($userName)', text, true);
    setState(() {
      messages.add(ChatMessage(
        sender: 'Ben ($userName)',
        text: text,
        isMe: true,
      ));
      _textController.clear();
    });
  }

  Future<void> _startVoiceCall() async {
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ses kaydediliyor...')),
      );
    }
  }

  Future<void> _stopAndSendVoiceCall() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null) {
      File file = File(path);
      for (String endpointId in endpointMap.keys) {
        Nearby().sendFilePayload(endpointId, file.path);
      }

      setState(() {
        messages.add(ChatMessage(
          sender: 'Ben ($userName)',
          text: '[Sesli Mesaj]',
          isMe: true,
          isAudio: true,
          audioPath: path,
        ));
      });
    }
  }

  Future<void> _playAudio(String path) async {
    await _audioPlayer.play(DeviceFileSource(path));
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: _downloadChat,
                  ),
                  IconButton(
                    icon: Icon(_isRecording ? Icons.stop : Icons.call, color: _isRecording ? Colors.red : Colors.greenAccent),
                    onPressed: _isRecording ? _stopAndSendVoiceCall : _startVoiceCall,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Offline Sohbet: $userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('${endpointMap.length} cihaz bağlı', style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Align(
                    alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: msg.isMe ? Colors.redAccent : Colors.grey[800],
                        borderRadius: BorderRadius.circular(15).copyWith(
                          bottomRight: msg.isMe ? const Radius.circular(0) : const Radius.circular(15),
                          bottomLeft: msg.isMe ? const Radius.circular(15) : const Radius.circular(0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.sender,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60),
                          ),
                          const SizedBox(height: 4),
                          if (msg.isAudio)
                            IconButton(
                              icon: const Icon(Icons.play_arrow, color: Colors.white),
                              onPressed: () => _playAudio(msg.audioPath!),
                            )
                          else
                            Text(
                              msg.text,
                              style: const TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Mesaj yazın...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String sender;
  final String text;
  final bool isMe;
  final bool isAudio;
  final String? audioPath;

  ChatMessage({
    required this.sender,
    required this.text,
    required this.isMe,
    this.isAudio = false,
    this.audioPath
  });
}
