import 'supabase.dart';

Future<void> sendNotification({
  required String toUserId,
  required String type,
  String? postId,
  String? message,
}) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null || uid == toUserId) return;
  try {
    await supabase.from('notifications').insert({
      'user_id': toUserId,
      'actor_id': uid,
      'type': type,
      'post_id': postId,
      'message': message,
    });
  } catch (_) {
    // Retry without message column in case migration hasn't been run
    try {
      final data = <String, dynamic>{
        'user_id': toUserId,
        'actor_id': uid,
        'type': type,
      };
      if (postId != null) data['post_id'] = postId;
      await supabase.from('notifications').insert(data);
    } catch (_) {}
  }
}
