import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../core/theme_notifier.dart';
import '../../core/verses.dart';
import '../../core/notifications.dart';

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
  bool _showingVerse = false;
  bool _isSharing = false;
  bool _isBottomNavVisible = true;
  final GlobalKey _verseKey = GlobalKey();
  int _unreadDms = 0;

  bool _showingLive = false;
  int _liveTimer = 5;
  Timer? _liveCountdown;
  StreamSubscription<String?>? _notifSub;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() { 
    super.initState(); 
    _loadProfile(); 
    _loadUnread(); 
    _subscribeUnread(); 
    _checkDailyVerse();

    _notifSub = notificationTapStream.stream.listen((payload) {
      if (payload != null && mounted) {
        try {
          final data = jsonDecode(payload);
          final type = data['type'];
          if (type == 'follow' && data['actor_id'] != null) {
            context.push('/profile/${data['actor_id']}');
          } else if (data['post_id'] != null) {
            context.push('/post/${data['post_id']}');
          } else if (type == 'message' && data['actor_id'] != null) {
            context.push('/dms/${data['actor_id']}');
          } else if (type == 'event' && data['post_id'] != null) {
            context.push('/events/${data['post_id']}');
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _liveCountdown?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  void _showLiveOverlay() {
    setState(() {
      _showingLive = true;
      _liveTimer = 5;
    });
    _liveCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_liveTimer > 1) {
        setState(() => _liveTimer--);
      } else {
        timer.cancel();
        setState(() => _showingLive = false);
        _triggerLiveAction();
      }
    });
  }

  void _cancelLive() {
    _liveCountdown?.cancel();
    setState(() => _showingLive = false);
  }

  Future<void> _triggerLiveAction() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final res = await supabase.from('events').insert({
        'title': 'Quick Live',
        'description': 'Live stream session',
        'event_date': DateTime.now().toIso8601String(),
        'is_free': true,
        'is_virtual': true,
        'stream_url': null,
        'organizer_id': uid,
        'ticket_currency': 'RWF',
        'is_live': true,
      }).select('id').single();
      
      final eventId = res['id'];
      
      await supabase.from('live_streams').insert({
        'event_id': eventId,
        'status': 'live',
      });
      
      if (mounted) context.push('/events/$eventId/live');
    } catch (e) {
      debugPrint('Failed to start quick live: $e');
    }
  }

  Future<void> _checkDailyVerse() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastVerseDate = prefs.getString('last_verse_date');
    if (lastVerseDate != today) {
      await prefs.setString('last_verse_date', today);
      if (mounted) setState(() => _showingVerse = true);
    }
  }

  Future<void> _shareVerse() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      final boundary = _verseKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ijwi_verse.png');
      await file.writeAsBytes(pngBytes);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Today\'s Verse 🕊️\n\nShared via Ijwi');
    } catch (e) {
      debugPrint('Error sharing verse: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

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

  void _onTabTap(int targetIdx, String route) {
    setState(() => _showCreate = false);
    if (_idx(context) != targetIdx) {
      context.go(route);
    }
  }

  Widget _buildLiveOverlay(BuildContext context, Color gold) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                '$_liveTimer',
                style: GoogleFonts.poppins(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Going Live in...',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _cancelLive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerseOverlay(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final verse = Verses.todaysVerse();
    return Positioned.fill(
      child: Stack(
        children: [
          RepaintBoundary(
            key: _verseKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Dim the whole app
                GestureDetector(
                  onTap: () => setState(() => _showingVerse = false),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: isDark 
                        ? Colors.black.withValues(alpha: _isSharing ? 1.0 : 0.85) 
                        : Colors.white.withValues(alpha: _isSharing ? 1.0 : 0.85)
                    ),
                  ),
                ),
                // Content visible alone
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TODAY\'S VERSE',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0, color: textColor.withValues(alpha: 0.5)),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              '"${verse['text']}"',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                fontStyle: FontStyle.italic,
                                color: textColor,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '— ${verse['reference']?.toUpperCase()}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: textColor.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                      if (!_isSharing)
                        // Amen button
                        GestureDetector(
                          onTap: () => setState(() => _showingVerse = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1.5),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text('Amen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                          ),
                        ),
                      const SizedBox(height: 120), // Space for share button
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_isSharing)
            // Share Button at the bottom nav spot
            Positioned(
              bottom: 28,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: _shareVerse,
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.share, color: textColor, size: 20),
                      const SizedBox(width: 12),
                      Text('Share to Status', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCreateMenu(BuildContext context, Color gold, bool isDark, Color surface) {
    return [
      // Tap-away dismiss with blur
      Positioned.fill(child: GestureDetector(
        onTap: () => setState(() => _showCreate = false),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
      )),
      // Horizontal animated items above the create button
      Positioned(
        bottom: 110,
        left: 0, right: 0,
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _AnimatedCreateItem(index: 0, icon: LucideIcons.pen_line, label: 'Voice', gold: gold, isDark: isDark, onTap: () { setState(() => _showCreate = false); context.push('/write'); }),
          _AnimatedCreateItem(index: 1, icon: LucideIcons.book_open, label: 'Essay', gold: gold, isDark: isDark, onTap: () { setState(() => _showCreate = false); context.push('/essay/create'); }),
          _AnimatedCreateItem(index: 2, icon: LucideIcons.video, label: 'Spark', gold: gold, isDark: isDark, onTap: () { setState(() => _showCreate = false); context.push('/sparks/create'); }),
        ])),
      ),
    ];
  }


  Widget _buildDrawer(BuildContext context, Color gold, bool isDark, Color surface, Color text3) {
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final bg = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final scaffoldBg = isDark ? IjwiColors.darkBg : IjwiColors.lightBg;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            color: bg.withValues(alpha: 0.75),
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
                clipBehavior: Clip.antiAlias,
                child: _avatarUrl != null 
                    ? CachedNetworkImage(imageUrl: _avatarUrl!, width: 48, height: 48, fit: BoxFit.cover)
                    : Text(_initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: gold)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(_handle, style: TextStyle(fontSize: 12, color: text3)),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(LucideIcons.x, size: IjwiSizes.iconMd, color: text3),
              ),
            ]),
          ),
          Divider(height: 1, color: border),

          // Items
          Expanded(child: ListView(padding: const EdgeInsets.only(top: 8), children: [
            _DrawerItem(icon: LucideIcons.user, label: 'Edit profile', sub: 'Update your info & photo', onTap: () { Navigator.pop(context); context.push('/settings'); }),
            _DrawerItem(icon: LucideIcons.calendar_check, label: 'My Events', sub: 'Find Your Events', onTap: () { Navigator.pop(context); context.push('/my-events'); }),
            _DrawerItem(icon: LucideIcons.wallet, label: 'Wallet', sub: 'Earnings & Cashouts', onTap: () { Navigator.pop(context); context.push('/wallet'); }),
            _DrawerItem(icon: LucideIcons.bookmark, label: 'Saved Posts', onTap: () { Navigator.pop(context); context.push('/saved'); }),
            Divider(height: 1, indent: 20, endIndent: 20, color: border),
            _DrawerItem(icon: LucideIcons.bell, label: 'Notifications', sub: 'Manage alerts', onTap: () { Navigator.pop(context); context.push('/notification-prefs'); }),
            _DrawerItem(icon: LucideIcons.lock, label: 'Privacy & security', onTap: () { Navigator.pop(context); context.push('/privacy'); }),
            _DrawerItem(icon: LucideIcons.settings, label: 'Settings', onTap: () { Navigator.pop(context); context.push('/settings'); }),
            // Theme toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(children: [
                SizedBox(
                  width: 36, height: 36,
                  child: Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 20, color: gold),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text('Dark mode', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500))),
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
          ),
        ),
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
    // Dark mode: always white inactive. Light mode: always black
    final navInactive = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context, gold, isDark, surface, text3),
      drawerEdgeDragWidth: 40,
      extendBody: true,
      body: Stack(children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (idx != 0) return false;
            if (notification.direction == ScrollDirection.forward) {
              if (!_isBottomNavVisible) setState(() => _isBottomNavVisible = true);
            } else if (notification.direction == ScrollDirection.reverse) {
              if (_isBottomNavVisible) setState(() => _isBottomNavVisible = false);
            }
            return false;
          },
          child: widget.child,
        ),
        if (_showCreate && !_showingVerse) ..._buildCreateMenu(context, gold, isDark, surface),
        if (_showingVerse) _buildVerseOverlay(isDark),
        if (_showingLive) _buildLiveOverlay(context, gold),
      ]),
      bottomNavigationBar: _showingVerse ? null : AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: (_isBottomNavVisible || idx != 0) ? Offset.zero : const Offset(0, 1.5),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: surface.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: gold.withValues(alpha: 0.18), width: 0.8),
              ),
              child: Row(children: [
                _NavItem(icon: LucideIcons.house, label: 'Home', active: idx == 0, gold: gold, text3: navInactive, onTap: () => _onTabTap(0, '/feed')),
                _NavItem(icon: LucideIcons.calendar, label: 'Events', active: idx == 1, gold: gold, text3: navInactive, onTap: () => _onTabTap(1, '/events')),
                Expanded(child: Center(child: GestureDetector(
                  onTap: () => setState(() => _showCreate = !_showCreate),
                  onLongPress: _showLiveOverlay,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: gold, boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: AnimatedRotation(
                      turns: _showCreate ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(LucideIcons.plus, color: Colors.white, size: IjwiSizes.iconMd),
                    ),
                  ),
                ))),
                _NavItem(icon: LucideIcons.message_circle, label: 'Inbox', active: idx == 3, gold: gold, text3: navInactive, badge: _unreadDms, onTap: () => _onTabTap(3, '/dms')),
                _NavMe(avatarUrl: _avatarUrl, initial: _initial, active: idx == 4, gold: gold, text3: navInactive, onTap: () => _onTabTap(4, '/profile')),
              ]),
            ),
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
          Icon(icon, size: IjwiSizes.iconMd, color: active ? gold : text3),
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
        Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? gold : text3, letterSpacing: 0.2)),
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
    final labelColor = active ? gold : text3;
    return Expanded(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? gold : text3, width: active ? 2 : 1)),
          child: ClipOval(child: avatarUrl != null && avatarUrl!.startsWith('http')
              ? CachedNetworkImage(imageUrl: avatarUrl!, width: 24, height: 24, fit: BoxFit.cover)
              : Container(color: gold.withValues(alpha: 0.15), alignment: Alignment.center, child: Text(initial, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gold)))),
        ),
        const SizedBox(height: 4),
        Text('Me', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: labelColor, letterSpacing: 0.2)),
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
          SizedBox(
            width: 36, height: 36,
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
            if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: text3)),
          ])),
          Icon(LucideIcons.chevron_right, size: 16, color: text3),
        ]),
      ),
    );
  }
}

class _AnimatedCreateItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final Color gold;
  final bool isDark;
  final VoidCallback onTap;
  const _AnimatedCreateItem({required this.index, required this.icon, required this.label, required this.gold, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Dark mode: white icons + text. Light mode: gold fill + white text
    final iconBg = isDark ? Colors.white : gold;
    final iconColor = isDark ? const Color(0xFF1A1814) : Colors.white;
    final labelColor = Colors.white;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index * 80)),
      curve: Curves.easeOut,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
          ]),
        ),
      ),
    );
  }
}
