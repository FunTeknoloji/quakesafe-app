import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'notification_service.dart';
import '../models/node.dart';
import '../models/message.dart' as model;
import 'package:uuid/uuid.dart';

class P2PConnectionService extends ChangeNotifier {
  static final P2PConnectionService _instance = P2PConnectionService._internal();
  factory P2PConnectionService() => _instance;
  P2PConnectionService._internal() {
    _startQueueProcessor();
  }

  static const String _serviceId = "com.quakesafe.app.mesh";
  Strategy strategy = Strategy.P2P_CLUSTER;
  Map<String, Node> nodes = {};
  late Node _selfNode;

  Map<String, int> connectionQuality = {}; // Stability score
  bool isAdvertising = false;
  bool isDiscovery = false;
  bool isInitializing = false;
  String? _currentUserName;
  Function(String, ConnectionInfo)? _onInitCallback;

  final Map<String, Completer<bool>> _pendingAcks = {};
  final Queue<model.Message> _messageQueue = Queue<model.Message>();

  void _startQueueProcessor() {
    Timer.periodic(const Duration(seconds: 2), (timer) {
      _processMessageQueue();
    });
    _startBatteryOptimization();
    _startMeshKeepAlive();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (nodes.isEmpty) return;
      _selfNode.batteryLevel = await Battery().batteryLevel;
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    var payload = {
      'type': 'HEARTBEAT',
      'node': _selfNode.toJson(),
    };
    sendProtocolMessage('all', payload);
  }

  void _startMeshKeepAlive() {
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (nodes.isEmpty && !isInitializing && _currentUserName != null) {
        debugPrint('Mesh Keep-Alive: No connections found, restarting mesh...');
        initMesh(_currentUserName!, _onInitCallback ?? (id, info) {});
      }
    });
  }

  void _startBatteryOptimization() {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        int level = await Battery().batteryLevel;
        _selfNode.batteryLevel = level;

        if (level < 15) {
          // Extreme power save: stop everything if no active connections
          if (nodes.isEmpty) {
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
      } catch (e) {}
    });
  }

  void _processMessageQueue() async {
    if (_messageQueue.isEmpty) return;

    // Sort queue by priority
    List<model.Message> sortedMessages = _messageQueue.toList();
    sortedMessages.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    _messageQueue.clear();
    _messageQueue.addAll(sortedMessages);

    final message = _messageQueue.removeFirst();
    await _sendRaw(message);
  }

  Future<void> sendMessage({
    required String text,
    model.MessagePriority priority = model.MessagePriority.Chat,
    String receiverId = 'broadcast',
  }) async {
    final message = model.Message(
      messageId: const Uuid().v4(),
      senderId: _selfNode.nodeId,
      receiverId: receiverId,
      content: text,
      priority: priority,
      timestamp: DateTime.now(),
    );
    _messageQueue.add(message);
  }

  Future<void> _sendRaw(model.Message message) async {
    var messageJson = message.toJson();
    var hash = sha256.convert(utf8.encode(jsonEncode(messageJson))).toString();

    var payload = {
      'type': 'MSG',
      'message': messageJson,
      'hash': hash,
    };

    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    bool success = false;

    if (message.receiverId == 'broadcast') {
      final relays = _selectRelays(2);
      if (relays.isEmpty && nodes.isNotEmpty) {
        for (String eid in nodes.keys) {
          await Nearby().sendBytesPayload(eid, bytes);
        }
      } else {
        for (var node in relays) {
          await Nearby().sendBytesPayload(node.nodeId, bytes);
        }
      }
      success = true;
    } else if (nodes.containsKey(message.receiverId)) {
      await Nearby().sendBytesPayload(message.receiverId, bytes);
      success = await _waitForAck(message.messageId);
    }

    // Local DB update can be added here if needed
  }

  List<Node> _selectRelays(int maxRelays) {
    if (nodes.isEmpty) return [];

    var sortedNodes = nodes.values.toList();
    sortedNodes.sort((a, b) {
      int scoreA = a.batteryLevel + (connectionQuality[a.nodeId] ?? 0);
      int scoreB = b.batteryLevel + (connectionQuality[b.nodeId] ?? 0);
      return scoreB.compareTo(scoreA); // Descending order
    });

    return sortedNodes.take(maxRelays).toList();
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

        switch (data['type']) {
          case 'HEARTBEAT':
            if (nodes.containsKey(id)) {
              nodes[id]!.batteryLevel = data['node']['batteryLevel'];
              nodes[id]!.nodeRole = NodeRole.values[data['node']['nodeRole']];
              nodes[id]!.lastSeen = DateTime.now();
              notifyListeners();
            }
            break;

          case 'SYNC_CHECK':
            List<dynamic> peerIds = data['recentIds'] ?? [];
            final myMessages = await DatabaseService.getMessages();

            int oneHourAgo = DateTime.now().millisecondsSinceEpoch - (3600 * 1000);
            var missingForPeer = myMessages.where((m) =>
                m['timestamp'] > oneHourAgo && !peerIds.contains(m['message_id']))
                .toList();

            for (var msg in missingForPeer) {
              final message = model.Message(
                messageId: msg['message_id'],
                senderId: _selfNode.nodeId,
                receiverId: id,
                content: msg['text'],
                priority: model.MessagePriority.values.firstWhere(
                  (e) => e.toString().split('.').last == msg['priority'],
                  orElse: () => model.MessagePriority.Chat,
                ),
                timestamp: DateTime.fromMillisecondsSinceEpoch(msg['timestamp']),
              );
              _sendRaw(message);
            }
            break;

          case 'ACK':
            String ackId = data['id'];
            if (_pendingAcks.containsKey(ackId)) {
              _pendingAcks[ackId]!.complete(true);
              _pendingAcks.remove(ackId);
            }
            break;

          case 'MSG':
            var ack = {'type': 'ACK', 'id': data['id']};
            Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(jsonEncode(ack))));

            final existing = await DatabaseService.getMessages();
            if (existing.any((m) => m['message_id'] == data['id'])) return;

            String sender = nodes[id]?.nodeId ?? 'Bilinmeyen';
            await DatabaseService.insertMessage(
              sender: sender,
              text: data['text'],
              isMe: false,
              priority: data['priority'] ?? 'normal',
              messageId: data['id'],
            );

            NotificationService.showNotification(
              id: data['id'].hashCode,
              title: 'Yeni Mesaj: $sender',
              body: data['text'],
            );
            break;
        }
      }
    } catch (e) {
      debugPrint('Payload Handle Error: $e');
    }
  }

  Future<void> initMesh(String userName, Function(String, ConnectionInfo) onInit) async {
    if (isInitializing) return;
    isInitializing = true;
    _currentUserName = userName;
    _onInitCallback = onInit;

    var uuid = const Uuid();
    _selfNode = Node(
      nodeId: uuid.v4(),
      lastSeen: DateTime.now(),
      batteryLevel: await Battery().batteryLevel,
    );

    final prefs = await SharedPreferences.getInstance();
    bool useBT = prefs.getBool('mesh_use_bluetooth') ?? true;
    bool useWifi = prefs.getBool('mesh_use_wifi') ?? true;

    if (useBT && !useWifi) {
      strategy = Strategy.P2P_CLUSTER;
    } else if (useWifi) {
      strategy = Strategy.P2P_STAR;
    } else {
      strategy = Strategy.P2P_CLUSTER;
    }

    await stopAll();

    await startAdvertising(userName, onInit);
    await startDiscovery(userName, onInit);

    isInitializing = false;
    notifyListeners();
  }

  Future<void> startAdvertising(String userName, Function(String, ConnectionInfo) onInit) async {
    _currentUserName = userName;
    _onInitCallback = onInit;
    if (isAdvertising) return;
    try {
      bool success = await Nearby().startAdvertising(
        userName,
        strategy,
        serviceId: _serviceId,
        onConnectionInitiated: (id, info) {
          debugPrint('Connection Initiated: $id');
          nodes[id] = Node(nodeId: info.endpointName, lastSeen: DateTime.now());
          notifyListeners();
          onInit(id, info);
        },
        onConnectionResult: (id, status) {
          debugPrint('Connection Result for $id: $status');
          if (status == Status.CONNECTED) {
            _syncWithPeer(id);
            _sendHeartbeat();
          } else {
            nodes.remove(id);
          }
          notifyListeners();
        },
        onDisconnected: (id) {
          debugPrint('Disconnected: $id');
          nodes.remove(id);
          notifyListeners();
        },
      );
      isAdvertising = success;
    } catch (e) {
      debugPrint('Adv Error: $e');
    }
  }

  Future<void> startDiscovery(String userName, Function(String, ConnectionInfo) onInit) async {
    _currentUserName = userName;
    _onInitCallback = onInit;
    if (isDiscovery) return;
    try {
      bool success = await Nearby().startDiscovery(
        userName,
        strategy,
        serviceId: _serviceId,
        onEndpointFound: (id, name, serviceId) {
          debugPrint('Endpoint Found: $id ($name)');
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: (id, info) {
              debugPrint('Connection Initiated: $id');
              nodes[id] = Node(nodeId: info.endpointName, lastSeen: DateTime.now());
              notifyListeners();
              onInit(id, info);
            },
            onConnectionResult: (id, status) {
              debugPrint('Connection Result for $id: $status');
              if (status == Status.CONNECTED) {
                _syncWithPeer(id);
                 _sendHeartbeat();
              } else {
                nodes.remove(id);
              }
              notifyListeners();
            },
            onDisconnected: (id) {
              debugPrint('Disconnected: $id');
              nodes.remove(id);
              notifyListeners();
            },
          );
        },
        onEndpointLost: (id) {
          debugPrint('Endpoint Lost: $id');
        },
      );
      isDiscovery = success;
    } catch (e) {
      debugPrint('Disc Error: $e');
    }
  }

  void broadcast(String message) {
    sendMessage(text: message, receiverId: 'broadcast');
  }

  Future<void> sendProtocolMessage(String targetId, Map<String, dynamic> data) async {
    String jsonStr = jsonEncode(data);
    Uint8List bytes = Uint8List.fromList(utf8.encode(jsonStr));
    if (targetId == 'all') {
      for (var eid in nodes.keys) {
        await Nearby().sendBytesPayload(eid, bytes);
      }
    } else {
      await Nearby().sendBytesPayload(targetId, bytes);
    }
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    nodes.clear();
    isAdvertising = false;
    isDiscovery = false;
    notifyListeners();
  }
}
