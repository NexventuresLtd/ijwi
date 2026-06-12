import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'supabase.dart';

final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
RealtimeChannel? _notifChannel;

Future<void> initNotifications() async {
  try {
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
  } catch (_) {}
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
      callback: (payload) async {
        final record = payload.newRecord;
        final type = record['type'] as String?;
        if (await _isNotifEnabled(type)) {
          _showLocalNotification(
            title: _notifTitle(type),
            body: record['message'] as String? ?? 'You have a new notification',
          );
        }
      },
    )
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'direct_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: uid),
      callback: (payload) async {
        if (!await _isNotifEnabled('message')) return;
        final record = payload.newRecord;
        final msg = (record['message'] ?? '').toString();
        final senderId = record['sender_id'] as String?;
        String body;
        if (RegExp(r'^\[post:[a-f0-9\-]+\]$').hasMatch(msg.trim())) {
          body = 'Sent you a post';
        } else if (msg.startsWith('http') && (msg.contains('/storage/v1/object/') || msg.endsWith('.jpg') || msg.endsWith('.png'))) {
          body = 'Sent you a photo';
        } else {
          body = msg.length > 50 ? '${msg.substring(0, 50)}...' : msg;
        }
        // Try to get sender name
        String title = 'New Message';
        if (senderId != null) {
          try {
            final profile = await supabase.from('profiles').select('voice_name').eq('id', senderId).maybeSingle();
            if (profile != null) title = profile['voice_name'] ?? 'New Message';
          } catch (_) {}
        }
        _showLocalNotification(title: title, body: body);
      },
    ).subscribe();
}

Future<bool> _isNotifEnabled(String? type) async {
  final prefs = await SharedPreferences.getInstance();
  switch (type) {
    case 'reaction': return prefs.getBool('notif_likes') ?? true;
    case 'comment': return prefs.getBool('notif_comments') ?? true;
    case 'follow': return prefs.getBool('notif_follows') ?? true;
    case 'message': return prefs.getBool('notif_messages') ?? true;
    case 'repost': return prefs.getBool('notif_reposts') ?? true;
    case 'event': return prefs.getBool('notif_events') ?? true;
    default: return true;
  }
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
  try {
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
  } catch (_) {}
}
