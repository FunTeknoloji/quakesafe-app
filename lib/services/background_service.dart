import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
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
        initialNotificationTitle: 'QuakeSafe Aktif',
        initialNotificationContent: 'Mesh ağı taranıyor...',
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
      Nearby().stopAdvertising();
      Nearby().stopDiscovery();
      Nearby().stopAllEndpoints();
    });

    service.on('setBackground').listen((event) {
      isForeground = false;
      // Restart Nearby in background if needed
    });

    service.on('sendMessage').listen((event) {
      if (event != null) {
        String id = event['id'];
        String msg = event['msg'];
        Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(msg)));
      }
    });

    // Load user settings
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final String userName = prefs.getString('username') ?? 'User';

    void startNearby() {
      if (isForeground) return;
      try {
        Nearby().startDiscovery(
          userName,
          Strategy.P2P_CLUSTER,
          onEndpointFound: (id, name, serviceId) {
            Nearby().requestConnection(
              userName,
              id,
              onConnectionInitiated: (id, info) {
                Nearby().acceptConnection(
                  id,
                  onPayLoadRecieved: (id, payload) async {
                    if (payload.type == PayloadType.BYTES) {
                      String str = String.fromCharCodes(payload.bytes!);
                      if (notificationsEnabled) {
                        NotificationService.showNotification(
                          id: id.hashCode,
                          title: 'Yeni Mesaj: $name',
                          body: str,
                        );
                      }
                      DatabaseService.insertMessage(sender: name, text: str, isMe: false);
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
          Strategy.P2P_CLUSTER,
          onConnectionInitiated: (id, info) {
            Nearby().acceptConnection(
              id,
              onPayLoadRecieved: (id, payload) async {
                if (payload.type == PayloadType.BYTES) {
                  String str = String.fromCharCodes(payload.bytes!);
                  if (notificationsEnabled) {
                    NotificationService.showNotification(
                      id: id.hashCode,
                      title: 'Yeni Mesaj: ${info.endpointName}',
                      body: str,
                    );
                  }
                  DatabaseService.insertMessage(sender: info.endpointName, text: str, isMe: false);
                }
              },
            );
          },
          onConnectionResult: (id, status) {},
          onDisconnected: (id) {},
        );
      } catch (e) {}
    }

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "QuakeSafe Mesh Aktif",
            content: "Bağlantılar taranıyor ve korunuyor.",
          );
        }
      }
    });
  }
}
