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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offline Sohbet: $userName', style: const TextStyle(fontSize: 16)),
            Text('${endpointMap.length} cihaz bağlı', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return ListTile(
                  title: Text(
                    msg.sender,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: msg.isMe ? Colors.blue : Colors.green),
                    textAlign: msg.isMe ? TextAlign.right : TextAlign.left,
                  ),
                  subtitle: Text(
                    msg.text,
                    textAlign: msg.isMe ? TextAlign.right : TextAlign.left,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(hintText: 'Mesaj yazın...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
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
