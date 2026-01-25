import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

class P2PConnectionService extends ChangeNotifier {
  static final P2PConnectionService _instance = P2PConnectionService._internal();
  factory P2PConnectionService() => _instance;
  P2PConnectionService._internal();

  final Strategy strategy = Strategy.P2P_CLUSTER;
  Map<String, ConnectionInfo> endpointMap = {};
  bool isAdvertising = false;
  bool isDiscovery = false;

  void startAdvertising(String userName, Function(String, ConnectionInfo) onInit) async {
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
          if (status != Status.CONNECTED) {
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
              if (status != Status.CONNECTED) {
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
    Uint8List bytes = Uint8List.fromList(utf8.encode(message));
    for (String id in endpointMap.keys) {
      Nearby().sendBytesPayload(id, bytes);
    }
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
