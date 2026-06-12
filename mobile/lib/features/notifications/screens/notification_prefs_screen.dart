import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});
  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool _likes = true;
  bool _comments = true;
  bool _follows = true;
  bool _messages = true;
  bool _reposts = true;
  bool _events = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _likes = prefs.getBool('notif_likes') ?? true;
      _comments = prefs.getBool('notif_comments') ?? true;
      _follows = prefs.getBool('notif_follows') ?? true;
      _messages = prefs.getBool('notif_messages') ?? true;
      _reposts = prefs.getBool('notif_reposts') ?? true;
      _events = prefs.getBool('notif_events') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text('Notifications', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: gold.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withValues(alpha: 0.2))),
          child: Row(children: [
            Icon(LucideIcons.bell_ring, size: 18, color: gold),
            const SizedBox(width: 10),
            Expanded(child: Text('Choose which notifications you receive. These settings apply to both in-app and push notifications.', style: TextStyle(fontSize: 12, color: text3, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 20),

        _PrefTile(icon: LucideIcons.heart, title: 'Likes', subtitle: 'When someone likes your post', value: _likes, gold: gold, surface: surface, border: border, onChanged: (v) { setState(() => _likes = v); _save('notif_likes', v); }),
        _PrefTile(icon: LucideIcons.message_circle, title: 'Comments', subtitle: 'When someone comments on your post', value: _comments, gold: gold, surface: surface, border: border, onChanged: (v) { setState(() => _comments = v); _save('notif_comments', v); }),
        _PrefTile(icon: LucideIcons.user_plus, title: 'New followers', subtitle: 'When someone follows you', value: _follows, gold: gold, surface: surface, border: border, onChanged: (v) { setState(() => _follows = v); _save('notif_follows', v); }),
        _PrefTile(icon: LucideIcons.mail, title: 'Messages', subtitle: 'When you receive a new DM', value: _messages, gold: gold, surface: surface, border: border, onChanged: (v) { setState(() => _messages = v); _save('notif_messages', v); }),
        _PrefTile(icon: LucideIcons.repeat_2, title: 'Reposts', subtitle: 'When someone reposts your content', value: _reposts, gold: gold, surface: surface, border: border, onChanged: (v) { setState(() => _reposts = v); _save('notif_reposts', v); }),
        _PrefTile(icon: LucideIcons.calendar, title: 'Events', subtitle: 'Event reminders and updates', value: _events, gold: gold, surface: surface, border: border, onChanged: (v) { setState(() => _events = v); _save('notif_events', v); }),
      ]),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final Color gold, surface, border;
  final ValueChanged<bool> onChanged;
  const _PrefTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.gold, required this.surface, required this.border, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
      child: Row(children: [
        Icon(icon, size: 18, color: gold),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        ])),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: gold),
      ]),
    );
  }
}
