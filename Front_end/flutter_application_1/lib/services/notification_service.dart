import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    const channel = AndroidNotificationChannel(
      'proxisearch_promo',
      'Promotions à proximité',
      description: 'Alertes quand vous passez près d\'un stand avec une promo',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<bool> canShowNotifications() async {
    if (!Platform.isAndroid) return true;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await androidPlugin?.areNotificationsEnabled();
    if (enabled == true) return true;

    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> showPromoNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    if (!await canShowNotifications()) {
      debugPrint('[Notif] Permission refusée — notification non affichée');
      return false;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'proxisearch_promo',
        'Promotions à proximité',
        channelDescription:
            'Alertes quand vous passez près d\'un stand avec une promo',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
        ticker: 'Promo ProxiSearch',
        playSound: true,
        enableVibration: true,
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
    );

    debugPrint('[Notif] Affichée: $title — $body');
    return true;
  }
}
