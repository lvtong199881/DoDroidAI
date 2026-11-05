import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin appNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await appNotifications.initialize(settings);
}

Future<void> showTaskNotification(String title, String body) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'scheduled_tasks',
      '定时任务',
      channelDescription: '定时任务提醒',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  await appNotifications.show(0, title, body, details);
}
