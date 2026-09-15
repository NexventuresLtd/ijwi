import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';
import '../../../shared/widgets/verse_refresh_control.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';
import '../../../shared/widgets/mention_text.dart';
import '../../sparks/screens/sparks_viewer_screen.dart';
import '../../essay/services/essay_service.dart';
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

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _essays = [];
  bool _loading = true;
  Set<String> _myReactions = {};
  Set<String> _mySaves = {};
  Set<String> _myReposts = {};


  RealtimeChannel? _postsChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadPosts();
    _setupRealtime();
  }

  void _setupRealtime() {
    _postsChannel = supabase.channel('public:posts')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        callback: (payload) {
          if (!mounted) return;
          final updatedPost = payload.newRecord;
          setState(() {
            final idx = _posts.indexWhere((p) => p['id'] == updatedPost['id']);
            if (idx != -1) {
              _posts[idx] = { ..._posts[idx], ...updatedPost };
            }
          });
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      final essaysFuture = EssayService.getPublishedEssays();
      final res = await supabase
          .from('posts')
          .select(
            '*, cover_image_url, author:profiles!posts_author_id_fkey(id, voice_name, avatar_url, is_revealed, real_name)',
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
      final essaysRes = await essaysFuture;
      if (mounted)
        setState(() {
          _posts = List<Map<String, dynamic>>.from(res);
          _essays = essaysRes;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildTabContent(String tabKey, Color gold) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Map<String, dynamic>> filtered = [];
    if (tabKey == 'all') {
      filtered = _posts;
    } else if (tabKey == 'short') {
      filtered = _posts.where((p) =>
        p['content_type'] == 'short' ||
        (p['video_url'] != null && (p['video_url'] as String).isNotEmpty)
      ).toList();
    } else if (tabKey == 'voices') {
      filtered = _posts.where((p) {
        final t = p['content_type'];
        return t != 'short' && t != 'essay';
      }).toList();
    } else if (tabKey == 'essay') {
      filtered = [
        ..._essays,
        ..._posts.where((p) => p['content_type'] == 'essay' && !_essays.any((e) => e['id'] == p['id']))
      ];
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.message_circle, size: 40, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text('No posts yet', style: GoogleFonts.poppins(fontSize: 18)),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        VerseRefreshControl(onRefresh: _loadPosts),
        if (tabKey == 'short')
          SliverFillRemaining(
            child: SparksViewerScreen(
              preloadedSparks: filtered,
              initialReactions: _myReactions,
              isEmbedded: true,
              onBack: () {
                _tabController.animateTo(0);
              },
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final item = filtered[i];
                if (tabKey == 'essay' || item.containsKey('reading_time_mins') || item['content_type'] == 'essay') {
                  return _EssayCard(essay: item);
                }
                final allSparks = filtered.where((p) => p['content_type'] == 'short' || p['video_url'] != null).toList();
                final sparkIndex = allSparks.indexWhere((p) => p['id'] == item['id']);
                return _PostCard(
                  post: item,
                  onReact: _handleReaction,
                  onSave: _handleSave,
                  onRepost: _handleRepost,
                  isLiked: _myReactions.contains(item['id']),
                  isSaved: _mySaves.contains(item['id']),
                  isReposted: _myReposts.contains(item['id']),
                  allSparks: allSparks.isNotEmpty ? allSparks : null,
                  initialSparkIndex: sparkIndex >= 0 ? sparkIndex : null,
                );
              },
              childCount: filtered.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    final isSparks = _tabController.index == 3;

    return SafeArea(
      bottom: false,
      top: !isSparks,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          if (isSparks) return [];
          return [
            SliverAppBar(
                automaticallyImplyLeading: false,
                floating: true,
                snap: true,
                pinned: false,
                elevation: 0,
                backgroundColor: Colors.transparent,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7)),
                  ),
                ),
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Icon(LucideIcons.menu, size: 22, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/explore'),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.search, size: IjwiSizes.iconSm, color: text3),
                                const SizedBox(width: 8),
                                Text('Search Ijwi...', style: GoogleFonts.poppins(fontSize: 14, color: text3)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          children: [
                            Icon(LucideIcons.bell, size: 22, color: isDark ? Colors.white : Colors.black),
                            Positioned(
                              top: 0, right: 0,
                              child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: gold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicatorPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                          labelColor: isDark ? Colors.black : Colors.white,
                          unselectedLabelColor: text3,
                          dividerColor: Colors.transparent,
                          labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: -0.2),
                          tabs: const [
                            Tab(text: 'For You'),
                            Tab(text: 'Voices'),
                            Tab(text: 'Essays'),
                            Tab(text: '✦ Sparks'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent('all', gold),
              _buildTabContent('voices', gold),
              _buildTabContent('essay', gold),
              _buildTabContent('short', gold),
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _TabBarDelegate({required this.child});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => true;
}

/// Thumbnail card for the 2-column Sparks grid.
class _SparkThumbnail extends StatelessWidget {
  final Map<String, dynamic> spark;
  const _SparkThumbnail({required this.spark});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = spark['author'] as Map<String, dynamic>?;
    final name = author?['voice_name'] ?? 'Anonymous';
    final caption = spark['body'] ?? '';
    String? coverUrl = spark['cover_image_url'] as String?;
    if (coverUrl == null && spark['media_urls'] != null) {
      final m = spark['media_urls'] as List<dynamic>;
      if (m.isNotEmpty) coverUrl = m.first.toString();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background — cover or placeholder
          coverUrl != null
              ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildPlaceholder(isDark, gold))
              : _buildPlaceholder(isDark, gold),
          // Gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1.0],
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
              ),
            ),
          ),
          // Play button
          Center(
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black45,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: const Icon(LucideIcons.play, color: Colors.white, size: 18),
            ),
          ),
          // Caption at bottom
          Positioned(
            left: 8, right: 8, bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('@$name', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                if (caption.isNotEmpty)
                  Text(caption,
                    style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark, Color gold) {
    return Container(
      color: isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3,
      child: Center(child: Icon(LucideIcons.video, size: IjwiSizes.iconXl, color: gold.withValues(alpha: 0.5))),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Future<void> Function(String postId, String type) onReact;
  final Future<void> Function(String postId) onSave;
  final Future<void> Function(String postId) onRepost;
  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  final List<Map<String, dynamic>>? allSparks;
  final int? initialSparkIndex;
  const _PostCard({required this.post, required this.onReact, required this.onSave, required this.onRepost, required this.isLiked, required this.isSaved, required this.isReposted, this.allSparks, this.initialSparkIndex});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>?;
    final isAnonymous = post['is_anonymous'] == true;
    final name = isAnonymous ? 'Anonymous' : ((author?['is_revealed'] == true && author?['real_name'] != null)
        ? author!['real_name']
        : (author?['voice_name'] ?? 'Anonymous'));
    final avatarUrl = author?['avatar_url'] as String?;
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final contentType = (post['content_type'] ?? 'story').toString().replaceAll('_', ' ');

    final bool hasVideo = post['video_url'] != null && (post['video_url'] as String).isNotEmpty;
    final bool hasImage = post['cover_image_url'] != null;
    final bool hasMedia = hasImage || hasVideo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (post['content_type'] == 'short' || post['video_url'] != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SparksViewerScreen(
              initialIndex: initialSparkIndex ?? 0, 
              preloadedSparks: allSparks ?? [post]
            ),
            fullscreenDialog: true,
          ));
        } else {
          context.push('/post/${post['id']}');
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: ClipOval(
                            child: isAnonymous
                                ? Icon(LucideIcons.user, size: 20, color: gold)
                                : (avatarUrl != null && avatarUrl.startsWith('http')
                                    ? Image.network(avatarUrl, width: 38, height: 38, fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          name.toString()[0].toUpperCase(),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gold),
                                        ),
                                      )),
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
                              Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(timeago.format(DateTime.parse(post['created_at'])), style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Text(contentType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gold, letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                  if (!hasVideo && post['title'] != null) ...[
                    const SizedBox(height: 12),
                    Text(post['title'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, height: 1.45), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (!hasVideo && post['body'] != null) ...[
                    const SizedBox(height: 10),
                    MentionText(post['body'], style: GoogleFonts.montserrat(fontSize: 13.5, height: 1.6), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  if (hasMedia) const SizedBox(height: 12),
                ],
              ),
            ),
            
            // MIDDLE BODY (Media)
            if (hasMedia)
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasImage && !hasVideo)
                        SizedBox(
                          height: 250,
                          child: CachedNetworkImage(
                            imageUrl: post['cover_image_url'],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      if (hasVideo)
                        SizedBox(
                          height: 450,
                          child: ClipRect(child: _VideoPreview(url: post['video_url'])),
                        ),
                    ],
                  ),
                  if (hasVideo && (post['title'] != null || post['body'] != null))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (post['title'] != null)
                                Text(
                                  post['title'],
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (post['body'] != null) ...[
                                if (post['title'] != null) const SizedBox(height: 4),
                                Text(
                                  post['body'],
                                  style: GoogleFonts.montserrat(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text("Read more", style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            // BOTTOM ACTIONS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _ReactionBtn(
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    label: 'Like',
                    count: (post['reaction_healed'] ?? 0) + (post['reaction_amen'] ?? 0),
                    active: isLiked,
                    onTap: () => onReact(post['id'], 'healed'),
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
                      color: isSaved ? gold : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ActionBtn(icon: LucideIcons.message_circle, label: '${post['comment_count'] ?? 0}'),
                  const SizedBox(width: 4),
                  _ActionBtn(icon: LucideIcons.share, label: 'Echo', onTap: () => showEchoSheet(context, post)),
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
  final IconData? activeIcon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _ReactionBtn({required this.icon, this.activeIcon, required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasCount = count > 0;
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white54 : Colors.black54;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? gold.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active && activeIcon != null ? activeIcon : icon, size: 16, color: active ? gold : defaultColor),
            if (hasCount) ...[
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? gold : defaultColor)),
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
    final defaultColor = isDark ? Colors.white54 : Colors.black54;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: IjwiSizes.iconSm, color: defaultColor),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: defaultColor)),
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
    if (_playing) _controller.pause();
    else _controller.play();
    setState(() => _playing = !_playing);
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction > 0.6 && !_playing) {
      _controller.play();
      setState(() => _playing = true);
    } else if (info.visibleFraction <= 0.2 && _playing) {
      _controller.pause();
      setState(() => _playing = false);
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      );
    }
    return VisibilityDetector(
      key: Key(widget.url),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: _togglePlay,
        child: ClipRect(
          child: Container(
            color: Colors.black,
            child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                ),
                child: const Icon(LucideIcons.play, color: Colors.white, size: 20),
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
                  child: Icon(_muted ? LucideIcons.volume_x : LucideIcons.volume_2, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    )));
  }
}

class _EssayCard extends StatelessWidget {
  final Map<String, dynamic> essay;
  const _EssayCard({required this.essay});

  @override
  Widget build(BuildContext context) {
    final author = essay['author'] as Map<String, dynamic>?;
    final isAnonymous = essay['is_anonymous'] == true;
    final name = isAnonymous ? 'Anonymous' : (author?['voice_name'] ?? 'Anonymous');
    final avatarUrl = author?['avatar_url'] as String?;
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final coverUrl = essay['cover_image_url'] as String?;
    final readingTime = essay['reading_time_mins'] as int? ?? 1;

    return GestureDetector(
      onTap: () {
        context.push('/post/${essay['id']}');
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(6, 0, 6, 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gold.withValues(alpha: 0.1),
                      border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: ClipOval(
                      child: isAnonymous
                          ? Icon(LucideIcons.user, size: 20, color: gold)
                          : (avatarUrl != null && avatarUrl.startsWith('http')
                              ? Image.network(avatarUrl, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    name.toString()[0].toUpperCase(),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gold),
                                  ),
                                )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          timeago.format(DateTime.parse(essay['published_at'] ?? essay['created_at'] ?? DateTime.now().toIso8601String())),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: gold.withValues(alpha: 0.2), width: 0.5),
                    ),
                    child: Text(
                      'ESSAY • $readingTime min',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gold, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),

            // MIDDLE AREA (Cover Image + Title)
            if (coverUrl != null)
              SizedBox(
                height: 250,
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    essay['title'] ?? 'Untitled Essay',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Read full essay...',
                    style: GoogleFonts.montserrat(
                      fontSize: 13.5,
                      color: gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // FOOTER (Read more)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Text("Read more", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: gold)),
                  const Spacer(),
                  Icon(LucideIcons.arrow_right, color: gold, size: 16),
                ]
              )
            )
          ],
        ),
      ),
    );
  }
}
