import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';

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
    _tabCtrl.addListener(() => setState(() { _selectMode = false; _selected.clear(); }));
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
    final voiceRole = (p['voice_role'] as String?)?.replaceAll('_', ' ') ?? 'voice';
    final isPro = p['is_pro'] == true;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(child: Column(children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(children: [
                  if (widget.userId != null) IconButton(icon: const Icon(LucideIcons.arrow_left, size: 22), onPressed: () => Navigator.maybePop(context)),
                  const Spacer(),
                  if (_isOwn) IconButton(icon: Icon(LucideIcons.settings, size: 20, color: text3), onPressed: () => context.push('/settings')),
                ]),
              ),

              // Avatar
              const SizedBox(height: 8),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.12), border: Border.all(color: gold, width: 2.5)),
                child: ClipOval(
                  child: p['avatar_url'] != null && (p['avatar_url'] as String).startsWith('http')
                      ? CachedNetworkImage(imageUrl: p['avatar_url'], width: 80, height: 80, fit: BoxFit.cover)
                      : Center(child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: gold))),
                ),
              ),
              const SizedBox(height: 12),

              // Name + role
              Text(name, style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: gold.withValues(alpha: 0.25))),
                  child: Text(voiceRole[0].toUpperCase() + voiceRole.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: gold)),
                ),
                if (isPro) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [gold, const Color(0xFFF0C060)]), borderRadius: BorderRadius.circular(99)),
                    child: const Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ],
              ]),
              if (p['bio'] != null) Padding(
                padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
                child: Text(p['bio'], style: TextStyle(fontSize: 13, color: text3, height: 1.5), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),

              // Stats
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
                child: Row(children: [
                  _Stat(value: _posts.length + _videos.length, label: 'Posts'),
                  Container(width: 0.5, height: 30, color: border),
                  _Stat(value: _followers, label: 'Listeners'),
                  Container(width: 0.5, height: 30, color: border),
                  _Stat(value: _following, label: 'Following'),
                ]),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isOwn
                    ? Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => context.push('/settings'),
                          icon: const Icon(LucideIcons.pen_line, size: 14),
                          label: const Text('Edit profile'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        )),
                        if (!isPro) ...[
                          const SizedBox(width: 10),
                          Expanded(child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(LucideIcons.crown, size: 14),
                            label: const Text('Go Pro'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          )),
                        ],
                      ])
                    : SizedBox(width: double.infinity, child: ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? Colors.transparent : gold,
                          side: _isFollowing ? BorderSide(color: border) : null,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(_isFollowing ? 'Listening ✓' : 'Listen', style: TextStyle(color: _isFollowing ? text3 : null)),
                      )),
              ),
              const SizedBox(height: 20),
            ])),

            // Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2, width: 0.5),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _PillTab(label: 'Posts', active: _tabCtrl.index == 0, gold: gold, onTap: () => _tabCtrl.animateTo(0)),
                          _PillTab(label: 'Videos', active: _tabCtrl.index == 1, gold: gold, onTap: () => _tabCtrl.animateTo(1)),
                          _PillTab(label: 'Reposts', active: _tabCtrl.index == 2, gold: gold, onTap: () => _tabCtrl.animateTo(2)),
                        ]),
                      ),
                    ),
                    if (_selectMode) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _deleteSelected,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                          child: Text('${_selected.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() { _selectMode = false; _selected.clear(); }),
                        child: Icon(LucideIcons.x, size: 18, color: text3),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ],
          body: TabBarView(controller: _tabCtrl, children: [
            // Posts grid
            _posts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.pen_line, size: 32, color: text3), const SizedBox(height: 8), Text(_isOwn ? 'No posts yet' : 'No posts', style: TextStyle(color: text3))]))
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                    itemCount: _posts.length,
                    itemBuilder: (_, i) => _buildSelectableGrid(_posts[i], gold, false),
                  ),
            // Videos grid
            _videos.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.video, size: 32, color: text3), const SizedBox(height: 8), Text(_isOwn ? 'No videos yet' : 'No videos', style: TextStyle(color: text3))]))
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 9 / 16),
                    itemCount: _videos.length,
                    itemBuilder: (_, i) => _buildSelectableGrid(_videos[i], gold, true),
                  ),
            // Reposts grid
            _reposts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.repeat_2, size: 32, color: text3), const SizedBox(height: 8), Text(_isOwn ? 'No reposts yet' : 'No reposts', style: TextStyle(color: text3))]))
                : GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                    itemCount: _reposts.length,
                    itemBuilder: (_, i) {
                      final post = _reposts[i]['post'] as Map<String, dynamic>?;
                      if (post == null) return const SizedBox.shrink();
                      return _buildSelectableGrid({'id': _reposts[i]['id'], ...post}, gold, false, isRepost: true);
                    },
                  ),
          ]),
        ),
      ),
    );
  }
  Widget _buildSelectableGrid(Map<String, dynamic> post, Color gold, bool isVideo, {bool isRepost = false}) {
    final id = post['id'] as String;
    final selected = _selected.contains(id);
    final tile = isVideo ? _VideoGridTile(post: post, gold: gold) : _PostGridTile(post: post, gold: gold);

    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          setState(() { if (selected) _selected.remove(id); else _selected.add(id); });
        } else {
          if (!isRepost) {
            context.push('/post/${post['id']}');
          } else {
            final origId = post['id'];
            if (origId != null) context.push('/post/$origId');
          }
        }
      },
      onLongPress: _isOwn ? () => setState(() { _selectMode = true; _selected.add(id); }) : null,
      child: Stack(children: [
        tile,
        if (isRepost) Positioned(top: 4, left: 4, child: Icon(LucideIcons.repeat_2, size: 12, color: Colors.white70)),
        if (_selectMode) Positioned(top: 4, right: 4, child: Container(
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : (isDark ? IjwiColors.darkText2 : IjwiColors.lightText2))),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text('$value', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
    ]));
  }
}

class _PostGridTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final Color gold;
  const _PostGridTile({required this.post, required this.gold});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = (post['content_type'] ?? 'story').toString();
    final gradients = {
      'story': [const Color(0xFF2D1B69), const Color(0xFF11998e)],
      'devotional': [const Color(0xFF1a1a2e), const Color(0xFFb8860b)],
      'spoken_word': [const Color(0xFF200122), const Color(0xFF6f0000)],
      'prayer_request': [const Color(0xFF0f2027), const Color(0xFF2c5364)],
      'question': [const Color(0xFF1f1c2c), const Color(0xFF928DAB)],
      'encouragement': [const Color(0xFF134E5E), const Color(0xFF71B280)],
    };
    final colors = gradients[type] ?? gradients['story']!;

    return GestureDetector(
      onTap: () => context.push('/post/${post['id']}'),
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
        child: Stack(children: [
          // Gradient overlay
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)])))),
          // Type badge
          Positioned(top: 6, left: 6, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
            child: Text(type.replaceAll('_', ' '), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.3)),
          )),
          // Text preview
          Positioned(bottom: 6, left: 6, right: 6, child: Text(
            post['title'] ?? post['body'] ?? '',
            style: const TextStyle(fontSize: 9, color: Colors.white, height: 1.3, fontWeight: FontWeight.w500),
            maxLines: 3, overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    );
  }
}

class _VideoGridTile extends StatelessWidget {
  final Map<String, dynamic> post;
  final Color gold;
  const _VideoGridTile({required this.post, required this.gold});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post['id']}'),
      child: Container(
        color: Colors.black,
        child: Stack(children: [
          Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0f0c29), Color(0xFF302b63)])))),
          // Play icon
          const Center(child: Icon(LucideIcons.play, color: Colors.white70, size: 28)),
        ]),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
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
          border: Border.all(color: isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder, width: 0.5),
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
          if (post['title'] != null) Text(post['title'], style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (post['body'] != null) Text(post['body'], style: TextStyle(fontSize: 13, color: text3, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text('by $name', style: TextStyle(fontSize: 11, color: text3)),
        ]),
      ),
    );
  }
}
