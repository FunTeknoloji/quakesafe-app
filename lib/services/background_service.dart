import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'database_service.dart';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'quakesafe_bg_channel',
        initialNotificationTitle: 'QuakeSafe Koruma Modu',
        initialNotificationContent: 'Mesh ağı ve acil durum takibi aktif.',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    try {
      _onStartLogic(service);
    } catch (e) {
      debugPrint('Background Service onStart Error: $e');
    }
  }

  static void _onStartLogic(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      Nearby().stopAdvertising();
      Nearby().stopDiscovery();
      Nearby().stopAllEndpoints();
      service.stopSelf();
    });

    bool isForeground = true;

    service.on('setForeground').listen((event) {
      isForeground = true;
      // We don't stop anymore, let UI manage it if it wants,
      // but BackgroundService should generally keep it alive if needed.
    });

    // Load user settings
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final String userName = prefs.getString('username') ?? 'User';

    void startNearby() async {
      debugPrint('Background startNearby called. isForeground: $isForeground');
      if (isForeground) return;

      final prefs = await SharedPreferences.getInstance();
      String stratStr = prefs.getString('mesh_strategy') ?? 'CLUSTER';
      Strategy strategy = Strategy.P2P_CLUSTER;
      if (stratStr == 'STAR') strategy = Strategy.P2P_STAR;
      if (stratStr == 'P2P') strategy = Strategy.P2P_POINT_TO_POINT;

      try {
        Nearby().startDiscovery(
          userName,
          strategy,
          onEndpointFound: (id, name, serviceId) {
            Nearby().requestConnection(
              userName,
              id,
              onConnectionInitiated: (id, info) {
                Nearby().acceptConnection(
                  id,
                  onPayLoadRecieved: (id, payload) async {
                    if (payload.type == PayloadType.BYTES) {
                      try {
                        String str = utf8.decode(payload.bytes!);
                        if (str.startsWith('{')) {
                          var data = jsonDecode(str);
                          if (data['type'] == 'MSG') {
                            if (notificationsEnabled && !isForeground) {
                              NotificationService.showNotification(
                                id: data['id'].hashCode,
                                title: 'Yeni Mesaj: $name',
                                body: data['text'],
                              );
                            }
                            DatabaseService.insertMessage(
                              sender: name,
                              text: data['text'],
                              isMe: false,
                              priority: data['priority'] ?? 'normal',
                              messageId: data['id'],
                            );
                          } else if (data['type'] == 'VOICE_SIG' && data['cmd'] == 'START') {
                            NotificationService.showCallNotification(
                              id: id.hashCode,
                              callerName: name,
                            );
                          }
                        }
                      } catch (e) {}
                    }
                  },
                );
              },
              onConnectionResult: (id, status) {},
              onDisconnected: (id) {},
            );
          },
          onEndpointLost: (id) {},
        );

        Nearby().startAdvertising(
          userName,
          strategy,
          onConnectionInitiated: (id, info) {
            Nearby().acceptConnection(
              id,
              onPayLoadRecieved: (id, payload) async {
                if (payload.type == PayloadType.BYTES) {
                      try {
                        String str = utf8.decode(payload.bytes!);
                        if (str.startsWith('{')) {
                          var data = jsonDecode(str);
                          if (data['type'] == 'MSG') {
                            if (notificationsEnabled && !isForeground) {
                              NotificationService.showNotification(
                                id: data['id'].hashCode,
                                title: 'Yeni Mesaj: ${info.endpointName}',
                                body: data['text'],
                              );
                            }
                            DatabaseService.insertMessage(
                              sender: info.endpointName,
                              text: data['text'],
                              isMe: false,
                              priority: data['priority'] ?? 'normal',
                              messageId: data['id'],
                            );
                          } else if (data['type'] == 'VOICE_SIG' && data['cmd'] == 'START') {
                            NotificationService.showCallNotification(
                              id: id.hashCode,
                              callerName: info.endpointName,
                            );
                          }
                        }
                      } catch (e) {}
                }
              },
            );
          },
          onConnectionResult: (id, status) {},
          onDisconnected: (id) {},
        );
      } catch (e) {}
    }

    service.on('setBackground').listen((event) {
      isForeground = false;
      startNearby();
    });

    service.on('sendMessage').listen((event) {
      if (event != null) {
        String id = event['id'];
        String msg = event['msg'];
        Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(msg)));
      }
    });

    // Update notification less frequently and with lower impact
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        if (service is AndroidServiceInstance) {
          if (await service.isForegroundService()) {
            // Keep it minimal as requested
            service.setForegroundNotificationInfo(
              title: "QuakeSafe Koruma Modu",
              content: "Acil durum ağı arka planda aktif.",
            );
          }
        }
      } catch (e) {}
    });
  }
}
