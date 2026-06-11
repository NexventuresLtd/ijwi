import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final res = await supabase.from('notifications').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(50);
      if (mounted) setState(() { _notifs = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'follow': return LucideIcons.user_plus;
      case 'comment': return LucideIcons.message_circle;
      case 'reaction': return LucideIcons.heart;
      case 'mention': return LucideIcons.at_sign;
      case 'event': return LucideIcons.calendar;
      default: return LucideIcons.bell;
    }
  }

  Color _iconColor(String? type, Color gold) {
    switch (type) {
      case 'follow': return Colors.blue;
      case 'comment': return gold;
      case 'reaction': return Colors.redAccent;
      case 'event': return Colors.green;
      default: return gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Icon(LucideIcons.arrow_left, size: 22, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2),
            ),
            const SizedBox(width: 14),
            Text('Notifications', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w500)),
            const Spacer(),
            if (_notifs.isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final uid = supabase.auth.currentUser?.id;
                  if (uid == null) return;
                  await supabase.from('notifications').update({'read': true}).eq('user_id', uid).eq('read', false);
                  setState(() { for (final n in _notifs) n['read'] = true; });
                },
                child: Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: gold)),
              ),
          ]),
        ),

        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _notifs.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.08), border: Border.all(color: gold.withValues(alpha: 0.2))),
                        child: Icon(LucideIcons.bell_off, size: 28, color: gold),
                      ),
                      const SizedBox(height: 16),
                      Text('All caught up', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w400)),
                      const SizedBox(height: 6),
                      Text('No new notifications', style: TextStyle(fontSize: 13, color: text3)),
                    ]))
                  : RefreshIndicator(
                      color: gold,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _notifs.length,
                        itemBuilder: (_, i) {
                          final n = _notifs[i];
                          final type = n['type'] as String?;
                          final isRead = n['read'] == true || n['read_at'] != null;
                          final iconColor = _iconColor(type, gold);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isRead ? Colors.transparent : (isDark ? IjwiColors.darkGoldBg : IjwiColors.lightGoldBg),
                              borderRadius: BorderRadius.circular(14),
                              border: isRead ? null : Border.all(color: gold.withValues(alpha: 0.1)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor.withValues(alpha: 0.1)),
                                child: Icon(_icon(type), size: 18, color: iconColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(n['message'] ?? 'New notification', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: isRead ? FontWeight.w400 : FontWeight.w500, height: 1.4)),
                                const SizedBox(height: 4),
                                Text(timeago.format(DateTime.parse(n['created_at'])), style: TextStyle(fontSize: 12, color: text3)),
                              ])),
                              if (!isRead)
                                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: gold)),
                            ]),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
