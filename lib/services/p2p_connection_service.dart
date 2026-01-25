import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:battery_plus/battery_plus.dart';
import 'database_service.dart';

class P2PConnectionService extends ChangeNotifier {
  static final P2PConnectionService _instance = P2PConnectionService._internal();
  factory P2PConnectionService() => _instance;
  P2PConnectionService._internal() {
    _startQueueProcessor();
  }

  final Strategy strategy = Strategy.P2P_CLUSTER;
  Map<String, ConnectionInfo> endpointMap = {};
  Map<String, int> connectionQuality = {}; // Stability score
  bool isAdvertising = false;
  bool isDiscovery = false;
  String? _currentUserName;
  Function(String, ConnectionInfo)? _onInitCallback;

  final Map<String, Completer<bool>> _pendingAcks = {};

  void _startQueueProcessor() {
    Timer.periodic(const Duration(seconds: 10), (timer) {
      _retryPendingMessages();
    });
    _startBatteryOptimization();
  }

  void _startBatteryOptimization() {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      int level = await Battery().batteryLevel;
      if (level < 15) {
        // Extreme power save: stop everything if no active connections
        if (endpointMap.isEmpty) {
          Nearby().stopDiscovery();
          Nearby().stopAdvertising();
          isDiscovery = false;
          isAdvertising = false;
          notifyListeners();
        }
      } else if (level < 30) {
        // Low power: toggle discovery to save battery
        if (isDiscovery) {
          Nearby().stopDiscovery();
          isDiscovery = false;
        } else {
          if (_currentUserName != null && _onInitCallback != null) {
            startDiscovery(_currentUserName!, _onInitCallback!);
          }
        }
        notifyListeners();
      }
    });
  }

  Future<void> _retryPendingMessages() async {
    if (endpointMap.isEmpty) return;
    final messages = await DatabaseService.getMessages();
    final pending = messages.where((m) => m['isMe'] == 1 && m['status'] == 'pending').toList();

    for (var msg in pending) {
      String receiverId = msg['receiver_id'];
      if (receiverId == 'broadcast' || endpointMap.containsKey(receiverId)) {
        _sendRaw(msg['id'], receiverId, msg['text'], msg['priority'], msg['message_id']);
      }
    }
  }

  Future<void> sendMessage({
    required String text,
    String priority = 'normal',
    String receiverId = 'broadcast',
  }) async {
    int id = await DatabaseService.insertMessage(
      sender: 'Ben',
      text: text,
      isMe: true,
      status: 'pending',
      priority: priority,
      receiverId: receiverId,
    );

    _sendRaw(id, receiverId, text, priority, null);
  }

  Future<void> _sendRaw(int dbId, String receiverId, String text, String priority, String? messageId) async {
    String msgId = messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    var payload = {
      'type': 'MSG',
      'id': msgId,
      'text': text,
      'priority': priority,
    };

    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));

    bool success = false;
    if (receiverId == 'broadcast') {
      for (String eid in endpointMap.keys) {
        await Nearby().sendBytesPayload(eid, bytes);
      }
      success = true; // For broadcast we don't strictly wait for ACKs from all to mark as sent
    } else if (endpointMap.containsKey(receiverId)) {
      await Nearby().sendBytesPayload(receiverId, bytes);
      // Wait for ACK
      success = await _waitForAck(msgId);
    }

    if (success) {
      await DatabaseService.updateMessageStatus(dbId, 'sent');
      if (receiverId != 'broadcast') {
        connectionQuality[receiverId] = (connectionQuality[receiverId] ?? 10) + 1;
      }
    } else {
      await DatabaseService.incrementRetryCount(dbId);
      if (receiverId != 'broadcast') {
        connectionQuality[receiverId] = (connectionQuality[receiverId] ?? 10) - 2;
      }
    }
  }

  Future<bool> _waitForAck(String msgId) async {
    final completer = Completer<bool>();
    _pendingAcks[msgId] = completer;

    // Timeout after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        _pendingAcks.remove(msgId);
        completer.complete(false);
      }
    });

    return completer.future;
  }

  Future<void> _syncWithPeer(String peerId) async {
    final messages = await DatabaseService.getMessages();
    if (messages.isEmpty) return;

    var syncPayload = {
      'type': 'SYNC_CHECK',
      'recentIds': messages.skip(messages.length > 5 ? messages.length - 5 : 0).map((m) => m['message_id']).toList()
    };
    Nearby().sendBytesPayload(peerId, Uint8List.fromList(utf8.encode(jsonEncode(syncPayload))));
  }

  void handleIncomingPayload(String id, Payload payload) async {
    if (payload.type != PayloadType.BYTES) return;

    try {
      String str = utf8.decode(payload.bytes!);
      if (str.startsWith('{')) {
        var data = jsonDecode(str);

        if (data['type'] == 'SYNC_CHECK') {
          List<dynamic> peerIds = data['recentIds'] ?? [];
          final myMessages = await DatabaseService.getMessages();

          int oneHourAgo = DateTime.now().millisecondsSinceEpoch - (3600 * 1000);
          var missingForPeer = myMessages.where((m) =>
            m['timestamp'] > oneHourAgo &&
            !peerIds.contains(m['message_id'])
          ).toList();

          for (var msg in missingForPeer) {
            _sendRaw(msg['id'], id, msg['text'], msg['priority'], msg['message_id']);
          }
          return;
        }

        if (data['type'] == 'ACK') {
          String ackId = data['id'];
          if (_pendingAcks.containsKey(ackId)) {
            _pendingAcks[ackId]!.complete(true);
            _pendingAcks.remove(ackId);
          }
          return;
        }

        if (data['type'] == 'MSG') {
          // Send ACK
          var ack = {'type': 'ACK', 'id': data['id']};
          Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(jsonEncode(ack))));

          // Check if already received (duplicate prevention)
          final existing = await DatabaseService.getMessages();
          if (existing.any((m) => m['message_id'] == data['id'])) return;

          String sender = endpointMap[id]?.endpointName ?? 'Bilinmeyen';
          await DatabaseService.insertMessage(
            sender: sender,
            text: data['text'],
            isMe: false,
            priority: data['priority'] ?? 'normal',
            messageId: data['id'],
          );

          if (data['priority'] == 'critical') {
            // High priority logic handled in UI via stream listener
          }
        }
      }
    } catch (e) {
      debugPrint('Payload Handle Error: $e');
    }
  }

  void startAdvertising(String userName, Function(String, ConnectionInfo) onInit) async {
    _currentUserName = userName;
    _onInitCallback = onInit;
    if (isAdvertising) return;
    try {
      isAdvertising = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: (id, info) {
          endpointMap[id] = info;
          notifyListeners();
          onInit(id, info);
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _syncWithPeer(id);
          } else {
            endpointMap.remove(id);
            notifyListeners();
          }
        },
        onDisconnected: (id) {
          endpointMap.remove(id);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Adv Error: $e');
    }
  }

  void startDiscovery(String userName, Function(String, ConnectionInfo) onInit) async {
    _currentUserName = userName;
    _onInitCallback = onInit;
    if (isDiscovery) return;
    try {
      isDiscovery = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (id, info) {
              endpointMap[id] = info;
              notifyListeners();
              onInit(id, info);
            },
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                _syncWithPeer(id);
              } else {
                endpointMap.remove(id);
                notifyListeners();
              }
            },
            onDisconnected: (id) {
              endpointMap.remove(id);
              notifyListeners();
            },
          );
        },
        onEndpointLost: (id) {},
      );
    } catch (e) {
      debugPrint('Disc Error: $e');
    }
  }

  void broadcast(String message) {
    sendMessage(text: message, receiverId: 'broadcast');
  }

  void stopAll() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    endpointMap.clear();
    isAdvertising = false;
    isDiscovery = false;
    notifyListeners();
  }
}
