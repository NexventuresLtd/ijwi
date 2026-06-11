import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';
import '../../../shared/widgets/mention_text.dart';
import '../widgets/echo_sheet.dart';

void showEchoSheet(BuildContext context, Map<String, dynamic> post) {
  final gold = Theme.of(context).colorScheme.primary;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EchoSheet(post: post, gold: gold, isDark: isDark),
  );
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _activeTab = 'all';
  Set<String> _myReactions = {};
  Set<String> _mySaves = {};
  Set<String> _myReposts = {};

  final _tabs = [
    {'key': 'all', 'label': 'For You'},
    {'key': 'voices', 'label': 'Voices'},
    {'key': 'question', 'label': 'Questions'},
    {'key': 'short', 'label': '✦ Sparks'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      final res = await supabase
          .from('posts')
          .select(
            '*, author:profiles!posts_author_id_fkey(id, voice_name, avatar_url, is_revealed, real_name)',
          )
          .or('status.eq.published,status.is.null')
          .order('created_at', ascending: false)
          .limit(30);
      if (uid != null) {
        final postIds = (res as List).map((p) => p['id'] as String).toList();
        if (postIds.isNotEmpty) {
          try {
            final reactions = await supabase.from('reactions').select('post_id').eq('user_id', uid).inFilter('post_id', postIds);
            _myReactions = reactions.map<String>((r) => r['post_id'] as String).toSet();
          } catch (_) {}
          try {
            final saves = await supabase.from('saved_posts').select('post_id').eq('user_id', uid).inFilter('post_id', postIds);
            _mySaves = saves.map<String>((r) => r['post_id'] as String).toSet();
          } catch (_) {}
          try {
            final reposts = await supabase.from('reposts').select('post_id').eq('user_id', uid).inFilter('post_id', postIds);
            _myReposts = reposts.map<String>((r) => r['post_id'] as String).toSet();
          } catch (_) {}
        }
      }
      if (mounted)
        setState(() {
          _posts = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_activeTab == 'all') return _posts;
    if (_activeTab == 'short') {
      return _posts.where((p) =>
        p['content_type'] == 'short' ||
        (p['video_url'] != null && (p['video_url'] as String).isNotEmpty)
      ).toList();
    }
    if (_activeTab == 'voices') {
      return _posts.where((p) {
        final t = p['content_type'];
        return t != 'short' && t != 'question';
      }).toList();
    }
    return _posts.where((p) => p['content_type'] == _activeTab).toList();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: gold,
        onRefresh: _loadPosts,
        edgeOffset: 104,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.7),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () =>
                                      Scaffold.of(context).openDrawer(),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isDark
                                          ? IjwiColors.darkSurface
                                          : IjwiColors.lightSurface,
                                      border: Border.all(
                                        color: isDark
                                            ? IjwiColors.darkBorder2
                                            : IjwiColors.lightBorder2,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Icon(
                                      LucideIcons.menu,
                                      size: 18,
                                      color: isDark
                                          ? IjwiColors.darkText2
                                          : IjwiColors.lightText2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/explore'),
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? IjwiColors.darkBg2
                                            : IjwiColors.lightBg2,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: gold.withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: gold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Search Ijwi...',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 14,
                                              color: text3,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            LucideIcons.search,
                                            size: 16,
                                            color: text3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () => context.push('/notifications'),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? IjwiColors.darkSurface
                                          : IjwiColors.lightSurface,
                                      border: Border.all(
                                        color: isDark
                                            ? IjwiColors.darkBorder2
                                            : IjwiColors.lightBorder2,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          LucideIcons.bell,
                                          size: 18,
                                          color: isDark
                                              ? IjwiColors.darkText2
                                              : IjwiColors.lightText2,
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 9,
                                          child: Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: gold,
                                              border: Border.all(
                                                color: isDark
                                                    ? IjwiColors.darkSurface
                                                    : IjwiColors.lightSurface,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: _tabs.map((t) {
                                final active = _activeTab == t['key'];
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _activeTab = t['key']!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: active
                                              ? gold
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      t['label']!,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: active
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : text3,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? IjwiColors.darkGoldBg
                      : IjwiColors.lightGoldBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gold.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S VERSE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '"Trust in the LORD with all your heart and lean not on your own understanding."',
                      style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '\u2014 PROVERBS 3:5\u20136',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                        color: isDark
                            ? IjwiColors.darkGoldDim
                            : IjwiColors.lightGoldDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.message_circle,
                        size: 40,
                        color: Theme.of(context).hintColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No posts yet',
                        style: GoogleFonts.fraunces(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) =>
                      _PostCard(
                        post: _filtered[i],
                        onReact: _handleReaction,
                        onSave: _handleSave,
                        onRepost: _handleRepost,
                        isLiked: _myReactions.contains(_filtered[i]['id']),
                        isSaved: _mySaves.contains(_filtered[i]['id']),
                        isReposted: _myReposts.contains(_filtered[i]['id']),
                      ),
                  childCount: _filtered.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReaction(String postId, String type) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final alreadyReacted = _myReactions.contains(postId);
    setState(() {
      final idx = _posts.indexWhere((p) => p['id'] == postId);
      if (idx != -1) {
        if (alreadyReacted) {
          _myReactions.remove(postId);
          _posts[idx]['reaction_$type'] = ((_posts[idx]['reaction_$type'] ?? 1) - 1).clamp(0, 99999);
        } else {
          _myReactions.add(postId);
          _posts[idx]['reaction_$type'] = (_posts[idx]['reaction_$type'] ?? 0) + 1;
        }
      }
    });
    try {
      if (alreadyReacted) {
        await supabase.from('reactions').delete().match({'post_id': postId, 'user_id': uid});
      } else {
        await supabase.from('reactions').insert({'post_id': postId, 'user_id': uid, 'reaction_type': type});
        final post = _posts.firstWhere((p) => p['id'] == postId);
        final authorId = (post['author'] as Map<String, dynamic>?)?['id'] as String?;
        if (authorId != null) sendNotification(toUserId: authorId, type: 'reaction', postId: postId, message: 'liked your post');
      }
      final current = _posts.firstWhere((p) => p['id'] == postId)['reaction_$type'] ?? 0;
      await supabase.from('posts').update({'reaction_$type': current}).eq('id', postId);
    } catch (_) {
      setState(() {
        final idx = _posts.indexWhere((p) => p['id'] == postId);
        if (idx != -1) {
          if (alreadyReacted) {
            _myReactions.add(postId);
            _posts[idx]['reaction_$type'] = (_posts[idx]['reaction_$type'] ?? 0) + 1;
          } else {
            _myReactions.remove(postId);
            _posts[idx]['reaction_$type'] = ((_posts[idx]['reaction_$type'] ?? 1) - 1).clamp(0, 99999);
          }
        }
      });
    }
  }

  Future<void> _handleSave(String postId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final alreadySaved = _mySaves.contains(postId);
    setState(() {
      if (alreadySaved) { _mySaves.remove(postId); } else { _mySaves.add(postId); }
    });
    try {
      if (alreadySaved) {
        await supabase.from('saved_posts').delete().match({'post_id': postId, 'user_id': uid});
      } else {
        await supabase.from('saved_posts').insert({'post_id': postId, 'user_id': uid});
      }
    } catch (_) {
      setState(() {
        if (alreadySaved) { _mySaves.add(postId); } else { _mySaves.remove(postId); }
      });
    }
  }

  Future<void> _handleRepost(String postId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final alreadyReposted = _myReposts.contains(postId);
    setState(() {
      if (alreadyReposted) { _myReposts.remove(postId); } else { _myReposts.add(postId); }
    });
    try {
      if (alreadyReposted) {
        await supabase.from('reposts').delete().match({'post_id': postId, 'user_id': uid});
      } else {
        await supabase.from('reposts').insert({'post_id': postId, 'user_id': uid});
        final post = _posts.firstWhere((p) => p['id'] == postId);
        final authorId = (post['author'] as Map<String, dynamic>?)?['id'] as String?;
        if (authorId != null) sendNotification(toUserId: authorId, type: 'repost', postId: postId, message: 'reposted your post');
      }
    } catch (_) {
      setState(() {
        if (alreadyReposted) { _myReposts.add(postId); } else { _myReposts.remove(postId); }
      });
    }
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 104;
  @override
  double get maxExtent => 104;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => true;
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Future<void> Function(String postId, String type) onReact;
  final Future<void> Function(String postId) onSave;
  final Future<void> Function(String postId) onRepost;
  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  const _PostCard({required this.post, required this.onReact, required this.onSave, required this.onRepost, required this.isLiked, required this.isSaved, required this.isReposted});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>?;
    final name =
        (author?['is_revealed'] == true && author?['real_name'] != null)
        ? author!['real_name']
        : (author?['voice_name'] ?? 'Anonymous');
    final avatarUrl = author?['avatar_url'] as String?;
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final contentType = (post['content_type'] ?? 'story').toString().replaceAll(
      '_',
      ' ',
    );

    return GestureDetector(
      onTap: () => context.push('/post/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (author?['id'] != null) context.push('/profile/${author!['id']}');
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gold.withValues(alpha: 0.1),
                        border: Border.all(
                          color: gold.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl.startsWith('http')
                            ? Image.network(avatarUrl, width: 38, height: 38, fit: BoxFit.cover)
                            : Center(
                                child: Text(
                                  name.toString()[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: gold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (author?['id'] != null) context.push('/profile/${author!['id']}');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            timeago.format(DateTime.parse(post['created_at'])),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: gold.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      contentType,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: gold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['title'] != null)
                    Text(
                      post['title'],
                      style: GoogleFonts.fraunces(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (post['title'] != null) const SizedBox(height: 6),
                  if (post['body'] != null)
                    MentionText(
                      post['body'],
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: isDark
                            ? IjwiColors.darkText2
                            : IjwiColors.lightText2,
                        height: 1.6,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (post['video_url'] != null &&
                      (post['video_url'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _VideoPreview(url: post['video_url']),
                    ),
                ],
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: border, width: 0.5)),
              ),
              child: Row(
                children: [
                  _ReactionBtn(
                    icon: LucideIcons.heart,
                    label: 'Like',
                    count: (post['reaction_healed'] ?? 0) + (post['reaction_amen'] ?? 0),
                    active: isLiked,
                    onTap: () => onReact(post['id'], 'healed'),
                  ),
                  _ReactionBtn(
                    icon: LucideIcons.droplets,
                    label: 'Drop',
                    count: post['reaction_needed'] ?? 0,
                    active: false,
                    onTap: () => onReact(post['id'], 'needed'),
                  ),
                  _ReactionBtn(
                    icon: LucideIcons.repeat_2,
                    label: 'Repost',
                    count: 0,
                    active: isReposted,
                    onTap: () => onRepost(post['id']),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => onSave(post['id']),
                    child: Icon(
                      isSaved ? LucideIcons.bookmark_check : LucideIcons.bookmark,
                      size: 18,
                      color: isSaved ? gold : Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ActionBtn(
                    icon: LucideIcons.message_circle,
                    label: '${post['comment_count'] ?? 0}',
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: LucideIcons.share,
                    label: 'Echo',
                    onTap: () => showEchoSheet(context, post),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _ReactionBtn({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final hasCount = count > 0;
    final highlighted = active || hasCount;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: highlighted ? gold.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? gold : (hasCount ? gold : Theme.of(context).hintColor),
            ),
            if (hasCount) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text2 = isDark ? IjwiColors.darkText2 : IjwiColors.lightText2;
    final border2 = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border2, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: text2),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _playing = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _controller.setLooping(true);
    _controller.setVolume(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() => _playing = !_playing);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio.clamp(0.56, 2.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            if (!_playing)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  LucideIcons.play,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Icon(
                    _muted ? LucideIcons.volume_x : LucideIcons.volume_2,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
