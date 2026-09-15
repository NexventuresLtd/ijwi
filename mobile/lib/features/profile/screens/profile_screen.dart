import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';
import '../widgets/share_profile_sheet.dart';
import '../../sparks/screens/sparks_viewer_screen.dart';
import 'qr_scanner_screen.dart';
import 'package:video_player/video_player.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _reposts = [];
  int _followers = 0, _following = 0;
  bool _isFollowing = false, _isOwn = false;
  bool _loading = true;
  late TabController _tabCtrl;
  Set<String> _selected = {};
  bool _selectMode = false;

  String get _targetId => widget.userId ?? supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) { if (mounted) setState(() => _loading = false); return; }
      final isOwn = widget.userId == null || widget.userId == uid;
      final profile = await supabase.from('profiles').select('*').eq('id', _targetId).maybeSingle();
      if (profile == null) { if (mounted) setState(() => _loading = false); return; }
      final fc = await supabase.from('follows').select('follower_id').eq('following_id', _targetId);
      final fgc = await supabase.from('follows').select('following_id').eq('follower_id', _targetId);
      final allPosts = await supabase.from('posts')
          .select('id, title, body, content_type, created_at, reaction_fire, video_url')
          .eq('author_id', _targetId)
          .order('created_at', ascending: false)
          .limit(30);
      List repostData = [];
      try {
        repostData = await supabase.from('reposts')
            .select('id, created_at, post:posts(id, title, body, content_type, created_at, author:profiles!posts_author_id_fkey(voice_name, is_revealed, real_name))')
            .eq('user_id', _targetId)
            .order('created_at', ascending: false);
      } catch (_) {}
      bool following = false;
      if (uid != null && !isOwn) {
        final f = await supabase.from('follows').select('follower_id').eq('follower_id', uid).eq('following_id', _targetId).maybeSingle();
        following = f != null;
      }
      final posts = allPosts.where((p) => p['content_type'] != 'short').toList();
      final videos = allPosts.where((p) => p['content_type'] == 'short').toList();
      if (mounted) setState(() {
        _profile = profile; _followers = fc.length; _following = fgc.length;
        _posts = List<Map<String, dynamic>>.from(posts);
        _videos = List<Map<String, dynamic>>.from(videos);
        _reposts = List<Map<String, dynamic>>.from(repostData);
        _isFollowing = following; _isOwn = isOwn; _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteRepost(String repostId) async {
    await supabase.from('reposts').delete().eq('id', repostId);
    setState(() => _reposts.removeWhere((r) => r['id'] == repostId));
  }

  Future<void> _toggleFollow() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (_isFollowing) {
      await supabase.from('follows').delete().match({'follower_id': uid, 'following_id': _targetId});
      setState(() { _isFollowing = false; _followers--; });
    } else {
      await supabase.from('follows').insert({'follower_id': uid, 'following_id': _targetId});
      setState(() { _isFollowing = true; _followers++; });
      sendNotification(toUserId: _targetId, type: 'follow', message: 'started following you');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return Scaffold(body: Center(child: Text('Profile not found', style: TextStyle(color: text3))));

    final p = _profile!;
    final name = (p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name'];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(child: Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(children: [
                  if (widget.userId != null)
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: text3.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.arrow_left, size: 16, color: text3),
                            const SizedBox(width: 4),
                            Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text3)),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_isOwn)
                    IconButton(
                      icon: Icon(LucideIcons.scan_line, size: IjwiSizes.iconMd, color: text3),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
                      },
                    ),
                  if (_isOwn) IconButton(icon: Icon(LucideIcons.settings, size: IjwiSizes.iconMd, color: text3), onPressed: () => context.push('/settings')),
                ]),
              ),

              // Profile header: avatar left, info right
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Avatar
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.12), border: Border.all(color: gold, width: 2.5)),
                    child: ClipOval(
                      child: p['avatar_url'] != null && (p['avatar_url'] as String).startsWith('http')
                          ? CachedNetworkImage(imageUrl: p['avatar_url'], width: 72, height: 72, fit: BoxFit.cover)
                          : Center(child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: gold))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Name + stats
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _MiniStat(value: _posts.length + _videos.length, label: 'Posts'),
                      const SizedBox(width: 14),
                      _MiniStat(value: _followers, label: 'Listeners', onTap: () => _showFollowsSheet(0)),
                      const SizedBox(width: 14),
                      _MiniStat(value: _following, label: 'Listening', onTap: () => _showFollowsSheet(1)),
                    ]),
                  ])),
                ]),
              ),

              // Bio
              if (p['bio'] != null && (p['bio'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(p['bio'], style: TextStyle(fontSize: 13, color: text3, height: 1.5), maxLines: 5, overflow: TextOverflow.ellipsis),
                  ),
                ),

              const SizedBox(height: 14),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isOwn
                    ? Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: () => context.push('/settings'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                          child: const Text('Edit profile'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: ElevatedButton.icon(
                          onPressed: () => showShareProfileSheet(
                            context,
                            userId: _targetId,
                            name: name,
                            avatarUrl: p['avatar_url'],
                            bio: p['bio'],
                          ),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                          icon: const Icon(LucideIcons.share_2, size: 15),
                          label: const Text('Share profile'),
                        )),
                      ])
                    : Row(children: [
                        Expanded(child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? Colors.transparent : gold,
                            side: _isFollowing ? BorderSide(color: border) : null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(_isFollowing ? 'Listening ✓' : 'Listen', style: TextStyle(color: _isFollowing ? text3 : null)),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => context.push('/dms/$_targetId'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                          icon: const Icon(LucideIcons.message_circle, size: 16),
                          label: const Text('Message'),
                        )),
                      ]),
              ),
              const SizedBox(height: 16),
            ])),

            // Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: _selectMode ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2, width: 0.3),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _PillTab(label: 'Posts', active: _tabCtrl.index == 0, gold: gold, onTap: () { _tabCtrl.animateTo(0); setState(() {}); }),
                          _PillTab(label: 'Videos', active: _tabCtrl.index == 1, gold: gold, onTap: () { _tabCtrl.animateTo(1); setState(() {}); }),
                          _PillTab(label: 'Reposts', active: _tabCtrl.index == 2, gold: gold, onTap: () { _tabCtrl.animateTo(2); setState(() {}); }),
                        ]),
                      ),
                      if (_selectMode) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: _deleteSelected,
                          child: Text('Delete (${_selected.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() { _selectMode = false; _selected.clear(); }),
                          child: Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text3)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(controller: _tabCtrl, children: [
            // Posts grid
            _posts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.pen_line, size: 32, color: text3), const SizedBox(height: 8), Text(_isOwn ? 'No posts yet' : 'No posts', style: TextStyle(color: text3))]))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 3, mainAxisSpacing: 3),
                    itemCount: _posts.length,
                    itemBuilder: (_, i) => _buildSelectableGrid(_posts[i], gold, false, index: i, totalCount: _posts.length, crossAxisCount: 2),
                  ),
            // Videos grid
            _videos.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.video, size: 32, color: text3), const SizedBox(height: 8), Text(_isOwn ? 'No videos yet' : 'No videos', style: TextStyle(color: text3))]))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 3, mainAxisSpacing: 3, childAspectRatio: 9 / 16),
                    itemCount: _videos.length,
                    itemBuilder: (_, i) => _buildSelectableGrid(_videos[i], gold, true, index: i, totalCount: _videos.length, crossAxisCount: 2),
                  ),
            // Reposts grid
            _reposts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.repeat_2, size: 32, color: text3), const SizedBox(height: 8), Text(_isOwn ? 'No reposts yet' : 'No reposts', style: TextStyle(color: text3))]))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 3, mainAxisSpacing: 3),
                    itemCount: _reposts.length,
                    itemBuilder: (_, i) {
                      final post = _reposts[i]['post'] as Map<String, dynamic>?;
                      if (post == null) return const SizedBox.shrink();
                      return _buildSelectableGrid({'id': _reposts[i]['id'], ...post}, gold, false, isRepost: true, index: i, totalCount: _reposts.length, crossAxisCount: 2);
                    },
                  ),
          ]),
        ),
      ),
    );
  }
  Widget _buildSelectableGrid(Map<String, dynamic> post, Color gold, bool isVideo, {bool isRepost = false, int index = 0, int totalCount = 1, int crossAxisCount = 2}) {
    final id = post['id'] as String;
    final selected = _selected.contains(id);
    final borderRadius = getInstagramGridBorderRadius(index, totalCount, crossAxisCount: crossAxisCount);
    final tile = isVideo ? VideoGridTile(post: post, gold: gold, borderRadius: borderRadius) : PostGridTile(post: post, gold: gold, borderRadius: borderRadius);

    return GestureDetector(
      onTap: _selectMode
          ? () => setState(() { if (selected) _selected.remove(id); else _selected.add(id); })
          : () {
              if (!isRepost) {
                if (isVideo) {
                  // Open full-screen Sparks viewer
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SparksViewerScreen(
                      initialIndex: _videos.indexWhere((v) => v['id'] == post['id']).clamp(0, _videos.length - 1),
                      preloadedSparks: _videos,
                    ),
                    fullscreenDialog: true,
                  ));
                } else {
                  context.push('/post/${post['id']}');
                }
              } else {
                final origId = post['id'];
                if (origId != null) context.push('/post/$origId');
              }
            },
      onLongPress: _isOwn ? () => setState(() { _selectMode = true; _selected.add(id); }) : null,
      child: Stack(children: [
        tile,
        if (isRepost) Positioned(top: 4, right: 4, child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
          child: Icon(LucideIcons.repeat_2, size: 10, color: Colors.white),
        )),
        if (_selectMode) Positioned(top: 4, left: 4, child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? gold : Colors.black38, border: Border.all(color: Colors.white, width: 1.5)),
          child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
        )),
      ]),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selected.length} item${_selected.length > 1 ? 's' : ''}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    for (final id in _selected) {
      try { await supabase.from('posts').delete().eq('id', id); } catch (_) {}
      try { await supabase.from('reposts').delete().eq('id', id); } catch (_) {}
    }
    setState(() { _selectMode = false; _selected.clear(); });
    _load();
  }

  void _showFollowsSheet(int initialTab) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _FollowsSheet(
        targetId: _targetId,
        initialTab: initialTab,
        gold: gold,
        bg: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
        text3: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3,
        border: isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2,
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color gold;
  final VoidCallback onTap;
  const _PillTab({required this.label, required this.active, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: active ? Colors.white : (isDark ? IjwiColors.darkText2 : IjwiColors.lightText2))),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;
  const _MiniStat({required this.value, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final w = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$value', style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
    ]);
    if (onTap == null) return w;
    return GestureDetector(onTap: onTap, child: w);
  }
}

BorderRadius getInstagramGridBorderRadius(int index, int totalCount, {int crossAxisCount = 2}) {
  return BorderRadius.zero;
}

class PostGridTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final Color gold;
  final BorderRadius? borderRadius;
  const PostGridTile({required this.post, required this.gold, this.borderRadius});

  static Map<String, dynamic> _cfg(String type) {
    switch (type) {
      case 'devotional':     return {'icon': LucideIcons.sunrise,                'label': 'Devotional',  'colors': [const Color(0xFF1a1200), const Color(0xFFb8860b)]};
      case 'spoken_word':    return {'icon': LucideIcons.mic,                    'label': 'Spoken Word', 'colors': [const Color(0xFF200122), const Color(0xFF8B0000)]};
      case 'prayer_request': return {'icon': LucideIcons.hand_heart,             'label': 'Prayer',      'colors': [const Color(0xFF0a1628), const Color(0xFF1E40AF)]};
      case 'question':       return {'icon': LucideIcons.circle_question_mark,   'label': 'Question',    'colors': [const Color(0xFF1f1c2c), const Color(0xFF5B4F7C)]};
      case 'encouragement':  return {'icon': LucideIcons.sun,                    'label': 'Encourage',   'colors': [const Color(0xFF0d2410), const Color(0xFF166534)]};
      case 'letter':         return {'icon': LucideIcons.mail,                   'label': 'Letter',      'colors': [const Color(0xFF1a0a00), const Color(0xFF9A3412)]};
      default:               return {'icon': LucideIcons.book_open,              'label': 'Story',       'colors': [const Color(0xFF1a1040), const Color(0xFF6B46C1)]};
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (post['content_type'] ?? 'story').toString();
    final cfg = _cfg(type);
    final colors = cfg['colors'] as List<Color>;
    final icon = cfg['icon'] as IconData;
    final label = cfg['label'] as String;
    final coverUrl = post['cover_image_url'] as String?;
    final titleText = post['title'] as String?;
    final bodyText = post['body'] as String?;
    final previewText = bodyText != null ? bodyText.replaceAll('\n', ' ').trim() : '';

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(fit: StackFit.expand, children: [
        // Background: cover image or gradient
        coverUrl != null
            ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
            : Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
                alignment: Alignment.center,
                child: Text(
                  titleText ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.merriweather(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

        // Dark gradient overlay at bottom
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              stops: const [0.4, 1.0],
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)]),
          ),
        ),

        // Type badge — top left
        Positioned(top: 5, left: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 8, color: Colors.white70),
              const SizedBox(width: 3),
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.4)),
            ]),
          )),

        // Text preview — bottom
        if (previewText.isNotEmpty)
          Positioned(bottom: 5, left: 5, right: 5,
            child: Text(previewText,
              style: const TextStyle(fontSize: 8.5, color: Colors.white70, height: 1.3, fontWeight: FontWeight.w400, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class VideoGridTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final Color gold;
  final BorderRadius? borderRadius;
  const VideoGridTile({required this.post, required this.gold, this.borderRadius});
  @override
  Widget build(BuildContext context) {
    final coverUrl = post['cover_image_url'] as String?;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(fit: StackFit.expand, children: [
        // Background
        coverUrl != null
            ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
            : post['video_url'] != null
                ? _ProfileVideoPreview(url: post['video_url'])
                : Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0f0c29), Color(0xFF302b63)]))),

        // Subtle gradient overlay
        DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: const [0.5, 1.0],
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)])
        )),

        // Play icon
        Center(child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5)),
          child: const Icon(LucideIcons.play, color: Colors.white, size: 24)
        )),

        // Text preview — bottom
        if (post['body'] != null || post['title'] != null)
          Positioned(bottom: 8, left: 8, right: 8,
            child: Text(post['title'] ?? post['body'] ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.2, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              maxLines: 2, overflow: TextOverflow.ellipsis)),

        // Spark label
        Positioned(top: 5, left: 5, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.zap, size: 8, color: Colors.white70),
            const SizedBox(width: 3),
            const Text('SPARK', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.4)),
          ]))),

        // Fire count — bottom right
        if ((post['reaction_fire'] ?? 0) > 0)
          Positioned(bottom: 5, right: 5, child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.flame, size: 10, color: Colors.orangeAccent),
            const SizedBox(width: 2),
            Text('${post['reaction_fire']}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ])),
      ]),
    );
  }
}

class _ProfileVideoPreview extends StatefulWidget {
  final String url;
  const _ProfileVideoPreview({required this.url});
  @override
  State<_ProfileVideoPreview> createState() => _ProfileVideoPreviewState();
}

class _ProfileVideoPreviewState extends State<_ProfileVideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _controller.setVolume(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0f0c29), Color(0xFF302b63)])));
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width > 0 ? _controller.value.size.width : 1080,
          height: _controller.value.size.height > 0 ? _controller.value.size.height : 1920,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabBarDelegate({required this.child});
  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => true;
}

class _RepostTile extends StatelessWidget {
  final Map<String, dynamic> repost;
  final Color gold;
  final bool isOwn;
  final VoidCallback onDelete;
  const _RepostTile({required this.repost, required this.gold, required this.isOwn, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final post = repost['post'] as Map<String, dynamic>?;
    if (post == null) return const SizedBox.shrink();
    final author = post['author'] as Map<String, dynamic>?;
    final name = (author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return GestureDetector(
      onTap: () => context.push('/post/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder, width: 0.3),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(LucideIcons.repeat_2, size: 14, color: gold),
            const SizedBox(width: 6),
            Text('Reposted', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (isOwn) GestureDetector(
              onTap: onDelete,
              child: Icon(LucideIcons.trash_2, size: 14, color: Colors.redAccent),
            ),
          ]),
          const SizedBox(height: 8),
          if (post['title'] != null) Text(post['title'], style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (post['body'] != null) Text(post['body'], style: TextStyle(fontSize: 13, color: text3, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('by $name', style: TextStyle(fontSize: 11, color: text3)),
        ]),
      ),
    );
  }
}

class _FollowsSheet extends StatefulWidget {
  final String targetId;
  final int initialTab;
  final Color gold, bg, text3, border;
  const _FollowsSheet({required this.targetId, required this.initialTab, required this.gold, required this.bg, required this.text3, required this.border});
  @override
  State<_FollowsSheet> createState() => _FollowsSheetState();
}

class _FollowsSheetState extends State<_FollowsSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  final _search = TextEditingController();
  
  List<Map<String, dynamic>> _listeners = [];
  List<Map<String, dynamic>> _listening = [];
  List<Map<String, dynamic>> _filteredListeners = [];
  List<Map<String, dynamic>> _filteredListening = [];
  Set<String> _myFollowingIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tabCtrl.addListener(() {
      _onSearch(_search.text);
      setState((){});
    });
    _load();
  }
  
  @override
  void dispose() {
    _tabCtrl.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser!.id;
    // Get target's listeners (followers)
    final fc = await supabase.from('follows').select('follower_id').eq('following_id', widget.targetId);
    final fIds = fc.map((e) => e['follower_id'] as String).toSet();
    
    // Get target's listening (following)
    final fgc = await supabase.from('follows').select('following_id').eq('follower_id', widget.targetId);
    final fgIds = fgc.map((e) => e['following_id'] as String).toSet();
    
    final allIds = <String>{...fIds, ...fgIds};
    List<Map<String, dynamic>> profiles = [];
    if (allIds.isNotEmpty) {
      final pRes = await supabase.from('profiles').select('id, voice_name, real_name, is_revealed, avatar_url').inFilter('id', allIds.toList()).order('voice_name');
      profiles = List<Map<String, dynamic>>.from(pRes);
    }
    
    final lsnrs = profiles.where((p) => fIds.contains(p['id'])).toList();
    final lsng = profiles.where((p) => fgIds.contains(p['id'])).toList();
    
    final myFgc = await supabase.from('follows').select('following_id').eq('follower_id', uid);
    final myFollowing = myFgc.map((e) => e['following_id'] as String).toSet();
    
    if (mounted) {
      setState(() {
        _listeners = lsnrs;
        _listening = lsng;
        _filteredListeners = lsnrs;
        _filteredListening = lsng;
        _myFollowingIds = myFollowing;
        _loading = false;
      });
    }
  }

  void _onSearch(String q) {
    final qLower = q.trim().toLowerCase();
    setState(() {
      if (qLower.isEmpty) {
        _filteredListeners = _listeners;
        _filteredListening = _listening;
      } else {
        bool match(Map<String, dynamic> p) {
          final n = ((p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name']).toString().toLowerCase();
          return n.contains(qLower);
        }
        _filteredListeners = _listeners.where(match).toList();
        _filteredListening = _listening.where(match).toList();
      }
    });
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final uid = supabase.auth.currentUser!.id;
    if (_myFollowingIds.contains(targetUserId)) {
      await supabase.from('follows').delete().match({'follower_id': uid, 'following_id': targetUserId});
      setState(() => _myFollowingIds.remove(targetUserId));
    } else {
      await supabase.from('follows').insert({'follower_id': uid, 'following_id': targetUserId});
      setState(() => _myFollowingIds.add(targetUserId));
      sendNotification(toUserId: targetUserId, type: 'follow', message: 'started following you');
    }
  }

  Widget _buildList(List<Map<String, dynamic>> list, bool isListenersTab, ScrollController scrollController) {
    if (list.isEmpty) return Center(child: Text(_search.text.isEmpty ? 'No people found' : 'No results', style: TextStyle(color: widget.text3)));
    final uid = supabase.auth.currentUser!.id;
    
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p = list[i];
        final id = p['id'] as String;
        final name = (p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name'];
        final isMe = id == uid;
        final imFollowing = _myFollowingIds.contains(id);
        
        String btnText = 'Listen';
        if (imFollowing) {
          btnText = 'Listening ✓';
        } else if (isListenersTab) {
          btnText = 'Listen back';
        }
        
        return InkWell(
          onTap: () { Navigator.pop(context); context.push('/profile/$id'); },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold.withValues(alpha: 0.1), border: Border.all(color: widget.gold.withValues(alpha: 0.2), width: 1.5)),
                child: ClipOval(
                  child: p['avatar_url'] != null && (p['avatar_url'] as String).startsWith('http')
                    ? CachedNetworkImage(imageUrl: p['avatar_url'], fit: BoxFit.cover, width: 46, height: 46)
                    : Center(child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: widget.gold))),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              if (!isMe)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () => _toggleFollow(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: imFollowing ? Colors.transparent : widget.gold,
                      side: imFollowing ? BorderSide(color: widget.border) : null,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(btnText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: imFollowing ? widget.text3 : Colors.white)),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(color: widget.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: widget.text3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99)))),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(LucideIcons.search, size: 16, color: widget.text3),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: _onSearch,
            ),
          ),
          
          TabBar(
            controller: _tabCtrl,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: widget.gold,
            labelColor: widget.gold,
            unselectedLabelColor: widget.text3,
            tabs: const [Tab(text: 'Listeners'), Tab(text: 'Listening')],
          ),
          
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(_filteredListeners, true, scroll),
                    _buildList(_filteredListening, false, scroll),
                  ],
                ),
          ),
        ]),
      ),
    );
  }
}
