import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/theme_notifier.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _avatarUrl;
  String _initial = '?';
  String _name = '';
  String _handle = '';
  bool _showCreate = false;
  int _unreadDms = 0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() { super.initState(); _loadProfile(); _loadUnread(); _subscribeUnread(); }

  Future<void> _loadUnread() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await supabase.from('direct_messages').select('id').eq('receiver_id', uid).isFilter('read_at', null);
      if (mounted) setState(() => _unreadDms = (res as List).length);
    } catch (_) {}
  }

  void _subscribeUnread() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    supabase.channel('unread-badge-$uid')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert, schema: 'public', table: 'direct_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: uid),
        callback: (_) { if (mounted) setState(() => _unreadDms++); },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update, schema: 'public', table: 'direct_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: uid),
        callback: (_) => _loadUnread(),
      ).subscribe();
  }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final res = await supabase.from('profiles').select('avatar_url, voice_name').eq('id', uid).maybeSingle();
    if (res != null && mounted) setState(() {
      _avatarUrl = res['avatar_url'];
      _name = res['voice_name'] ?? '?';
      _initial = _name[0].toUpperCase();
      _handle = '@${_name.toLowerCase().replaceAll(' ', '')}';
    });
  }

  int _idx(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/feed')) return 0;
    if (loc.startsWith('/events')) return 1;
    if (loc.startsWith('/dms')) return 3;
    if (loc.startsWith('/profile') || loc.startsWith('/notifications') || loc.startsWith('/settings')) return 4;
    return 0;
  }

  List<Widget> _buildCreateMenu(BuildContext context, Color gold, bool isDark, Color surface) {
    final bg = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;
    return [
      // Tap-away dismiss
      Positioned.fill(child: GestureDetector(
        onTap: () => setState(() => _showCreate = false),
        child: Container(color: Colors.black.withValues(alpha: 0.3)),
      )),
      // Menu above the create button
      Positioned(
        bottom: 110,
        left: 0, right: 0,
        child: Center(child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (_, v, child) => Transform.translate(
            offset: Offset(0, 20 * (1 - v)),
            child: Opacity(opacity: v, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 0.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _CreateOption(icon: LucideIcons.pen_line, label: 'Voice', color: gold, onTap: () { setState(() => _showCreate = false); context.push('/write'); }),
              _CreateOption(icon: LucideIcons.message_square, label: 'Question', color: gold, onTap: () { setState(() => _showCreate = false); context.push('/write'); }),
              _CreateOption(icon: LucideIcons.video, label: 'Spark', color: gold, onTap: () { setState(() => _showCreate = false); context.push('/sparks/create'); }),
            ]),
          ),
        )),
      ),
    ];
  }


  Widget _buildDrawer(BuildContext context, Color gold, bool isDark, Color surface, Color text3) {
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final bg = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final scaffoldBg = isDark ? IjwiColors.darkBg : IjwiColors.lightBg;

    return Drawer(
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.12), border: Border.all(color: gold, width: 2)),
                alignment: Alignment.center,
                child: Text(_initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: gold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(_handle, style: TextStyle(fontSize: 12, color: text3)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(LucideIcons.x, size: 20, color: text3),
              ),
            ]),
          ),
          Divider(height: 1, color: border),

          // Items
          Expanded(child: ListView(padding: const EdgeInsets.only(top: 8), children: [
            _DrawerItem(icon: LucideIcons.user, label: 'Edit profile', sub: 'Update your info & photo', onTap: () { Navigator.pop(context); context.push('/settings'); }),
            _DrawerItem(icon: LucideIcons.crown, label: 'Ijwi Pro', sub: 'Unlock all features', color: gold, onTap: () { Navigator.pop(context); context.push('/pro'); }),
            _DrawerItem(icon: LucideIcons.calendar_check, label: 'My Events', sub: 'Pinned & upcoming', onTap: () { Navigator.pop(context); context.go('/events'); }),
            _DrawerItem(icon: LucideIcons.bookmark, label: 'Saved Posts', onTap: () { Navigator.pop(context); context.push('/saved'); }),
            Divider(height: 1, indent: 20, endIndent: 20, color: border),
            _DrawerItem(icon: LucideIcons.bell, label: 'Notifications', sub: 'Manage alerts', onTap: () { Navigator.pop(context); context.push('/notification-prefs'); }),
            _DrawerItem(icon: LucideIcons.lock, label: 'Privacy & security', onTap: () { Navigator.pop(context); context.push('/privacy'); }),
            _DrawerItem(icon: LucideIcons.settings, label: 'Settings', onTap: () { Navigator.pop(context); context.push('/settings'); }),
            // Theme toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2),
                  child: Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 17, color: gold),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text('Dark mode', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500))),
                GestureDetector(
                  onTap: () => themeNotifier.toggle(),
                  child: Container(
                    width: 48, height: 28,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark ? gold : (isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                      border: Border.all(color: isDark ? gold : border, width: 0.5),
                    ),
                    alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(width: 22, height: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)])),
                  ),
                ),
              ]),
            ),
            Divider(height: 1, indent: 20, endIndent: 20, color: border),
            _DrawerItem(icon: LucideIcons.log_out, label: 'Sign out', color: Colors.redAccent, onTap: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
              if (context.mounted) context.go('/auth/login');
            }),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idx = _idx(context);
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final bg2 = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final border2 = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, gold, isDark, surface, text3),
      drawerEdgeDragWidth: 40,
      extendBody: true,
      body: Stack(children: [
        widget.child,
        // Create menu overlay
        if (_showCreate) ..._buildCreateMenu(context, gold, isDark, surface),
      ]),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 74,
              decoration: BoxDecoration(
                color: surface.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: gold.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(children: [
                _NavItem(icon: LucideIcons.house, label: 'Home', active: idx == 0, gold: gold, text3: text3, onTap: () => context.go('/feed')),
                _NavItem(icon: LucideIcons.calendar, label: 'Events', active: idx == 1, gold: gold, text3: text3, onTap: () => context.go('/events')),
                Expanded(child: Center(child: GestureDetector(
                  onTap: () => setState(() => _showCreate = !_showCreate),
                  child: Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: gold, boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 4))]),
                    child: AnimatedRotation(
                      turns: _showCreate ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 24),
                    ),
                  ),
                ))),
                _NavItem(icon: LucideIcons.message_circle, label: 'Inbox', active: idx == 3, gold: gold, text3: text3, badge: _unreadDms, onTap: () => context.go('/dms')),
                _NavMe(avatarUrl: _avatarUrl, initial: _initial, active: idx == 4, gold: gold, text3: text3, onTap: () => context.go('/profile')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color gold, text3;
  final int badge;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.gold, required this.text3, this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          Icon(icon, size: 23, color: active ? gold : text3),
          if (badge > 0) Positioned(
            top: -4, right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(8)),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text('$badge', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? gold : text3, letterSpacing: 0.2)),
      ]),
    ));
  }
}

class _NavMe extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final bool active;
  final Color gold, text3;
  final VoidCallback onTap;
  const _NavMe({required this.avatarUrl, required this.initial, required this.active, required this.gold, required this.text3, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? gold : Colors.transparent, width: 2)),
          child: ClipOval(child: avatarUrl != null && avatarUrl!.startsWith('http')
              ? CachedNetworkImage(imageUrl: avatarUrl!, width: 24, height: 24, fit: BoxFit.cover)
              : Container(color: gold.withValues(alpha: 0.15), alignment: Alignment.center, child: Text(initial, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gold)))),
        ),
        const SizedBox(height: 4),
        Text('Me', style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? gold : text3, letterSpacing: 0.2)),
      ]),
    ));
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final Color? color;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, this.sub, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? IjwiColors.darkText : IjwiColors.lightText);
    final bg2 = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: color == Colors.redAccent ? Colors.redAccent.withValues(alpha: 0.08) : bg2),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
            if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: text3)),
          ])),
          Icon(LucideIcons.chevron_right, size: 16, color: text3),
        ]),
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CreateOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12), border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
