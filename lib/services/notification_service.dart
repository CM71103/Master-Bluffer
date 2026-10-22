import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows device notifications (room confirmed, game started, results).
/// Notifications are not supported on web, so every call is a no-op there.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<void> show(String title, String body) async {
    if (kIsWeb || !_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'bluff_master_channel',
        'Bluff Master',
        channelDescription: 'Room and game updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(_id++, title, body, details);
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }
}
