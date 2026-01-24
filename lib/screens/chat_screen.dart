import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String userName = 'User_${Random().nextInt(10000)}';

  Map<String, ConnectionInfo> endpointMap = {};
  List<ChatMessage> messages = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    startDiscovery();
    startAdvertising();
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
      onPayLoadRecieved: (id, payload) {
        if (payload.type == PayloadType.BYTES) {
          String str = String.fromCharCodes(payload.bytes!);
          setState(() {
            messages.add(ChatMessage(
              sender: endpointMap[id]?.endpointName ?? 'Unknown',
              text: str,
              isMe: false,
            ));
          });
        }
      },
    );
  }

  void sendMessage() {
    String text = _textController.text.trim();
    if (text.isEmpty) return;

    Uint8List bytes = Uint8List.fromList(text.codeUnits);
    for (String endpointId in endpointMap.keys) {
      Nearby().sendBytesPayload(endpointId, bytes);
    }

    setState(() {
      messages.add(ChatMessage(
        sender: 'Ben ($userName)',
        text: text,
        isMe: true,
      ));
      _textController.clear();
    });
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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

  ChatMessage({required this.sender, required this.text, required this.isMe});
}
