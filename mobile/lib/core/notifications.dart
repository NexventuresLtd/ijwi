import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'supabase.dart';

final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
RealtimeChannel? _notifChannel;

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const settings = InitializationSettings(android: android, iOS: ios);
  await _localNotifs.initialize(settings);

  // Request permissions on iOS
  await _localNotifs.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  await _localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
}

void startNotificationListener() {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return;
  stopNotificationListener();

  _notifChannel = supabase.channel('user-notifs-$uid')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
      callback: (payload) {
        final record = payload.newRecord;
        _showLocalNotification(
          title: _notifTitle(record['type'] as String?),
          body: record['message'] as String? ?? 'New notification',
        );
      },
    ).subscribe();
}

void stopNotificationListener() {
  _notifChannel?.unsubscribe();
  _notifChannel = null;
}

String _notifTitle(String? type) {
  switch (type) {
    case 'follow': return 'New Follower';
    case 'comment': return 'New Comment';
    case 'reaction': return 'New Like';
    case 'mention': return 'You were mentioned';
    case 'event': return 'Event Update';
    case 'repost': return 'Post Reposted';
    case 'message': return 'New Message';
    default: return 'Ijwi';
  }
}

Future<void> _showLocalNotification({required String title, required String body}) async {
  const android = AndroidNotificationDetails(
    'ijwi_notifications',
    'Ijwi Notifications',
    channelDescription: 'Notifications for likes, comments, messages, and more',
    importance: Importance.high,
    priority: Priority.high,
  );
  const ios = DarwinNotificationDetails();
  const details = NotificationDetails(android: android, iOS: ios);
  await _localNotifs.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
}
