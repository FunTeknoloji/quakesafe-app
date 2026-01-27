import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool isForeground = true;

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {},
    );

    // Create background channel explicitly
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'quakesafe_bg_channel',
      'QuakeSafe Arka Plan Servisi',
      description: 'Mesh ağı ve acil durum takibi için kullanılır.',
      importance: Importance.min,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId ?? 'quakesafe_channel',
      'QuakeSafe Notifications',
      channelDescription: 'Emergency notifications for QuakeSafe',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      fullScreenIntent: channelId == 'quakesafe_call_channel',
      category: channelId == 'quakesafe_call_channel' ? AndroidNotificationCategory.call : null,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    if (isForeground && channelId != 'quakesafe_call_channel') return;

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  static Future<void> showCallNotification({
    required int id,
    required String callerName,
    bool ongoing = true,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'quakesafe_call_channel',
      'Gelen Çağrılar',
      channelDescription: 'Acil durum sesli çağrıları',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ongoing: ongoing,
      autoCancel: !ongoing,
      color: const Color(0xFFFF5252),
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      'GELEN ÇAĞRI',
      '$callerName sizi arıyor...',
      platformChannelSpecifics,
    );
  }
}
