import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/notify_helper.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../shared/widgets/mention_text.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../feed/widgets/echo_sheet.dart';
import '../../profile/widgets/profile_dm_sheet.dart';

class SparksViewerScreen extends StatefulWidget {
  final int initialIndex;
  final String? initialPostId;
  final List<Map<String, dynamic>>? preloadedSparks;
  final Set<String>? initialReactions;
  final bool isEmbedded;
  final VoidCallback? onBack;
  const SparksViewerScreen({super.key, this.initialIndex = 0, this.initialPostId, this.preloadedSparks, this.initialReactions, this.isEmbedded = false, this.onBack});
  @override
  State<SparksViewerScreen> createState() => _SparksViewerScreenState();
}

class _SparksViewerScreenState extends State<SparksViewerScreen> {
  late PageController _pageCtrl;
  List<Map<String, dynamic>> _sparks = [];
  bool _loading = true;
  int _currentIndex = 0;

  Set<String> _myReactions = {};
  Set<String> _myReposts = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    if (!widget.isEmbedded) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    
    if (widget.initialReactions != null) {
      _myReactions = Set.from(widget.initialReactions!);
    }

    if (widget.preloadedSparks != null) {
      _sparks = widget.preloadedSparks!;
      _fetchUserInteractions().then((_) {
        if (mounted) {
          setState(() {
            _loading = false;
            _jumpToInitialPost();
          });
        }
      });
    } else {
      _load();
    }
  }

  Future<void> _fetchUserInteractions() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || _sparks.isEmpty) return;
      final postIds = _sparks.map((e) => e['id'] as String).toList();
      
      if (widget.initialReactions == null) {
        final reactions = await supabase.from('reactions').select('post_id').eq('user_id', uid).inFilter('post_id', postIds);
        _myReactions = reactions.map((e) => e['post_id'] as String).toSet();
      }
      
      final reposts = await supabase.from('reposts').select('post_id').eq('user_id', uid).inFilter('post_id', postIds);
      _myReposts = reposts.map((e) => e['post_id'] as String).toSet();
    } catch (_) {}
  }

  void _jumpToInitialPost() {
    if (widget.initialPostId != null && _sparks.isNotEmpty) {
      final idx = _sparks.indexWhere((p) => p['id'] == widget.initialPostId);
      if (idx != -1) {
        _currentIndex = idx;
        _pageCtrl = PageController(initialPage: idx);
      }
    }
  }

  Future<void> _load() async {
    try {
      final res = await supabase
          .from('posts')
          .select('*, author:profiles!posts_author_id_fkey(id, voice_name, avatar_url, is_revealed, real_name)')
          .eq('content_type', 'short')
          .or('status.eq.published,status.is.null')
          .not('video_url', 'is', null)
          .order('created_at', ascending: false)
          .limit(50);
      _sparks = List<Map<String, dynamic>>.from(res); 

      if (widget.initialPostId != null) {
        final existingIdx = _sparks.indexWhere((p) => p['id'] == widget.initialPostId);
        if (existingIdx == -1) {
          try {
            final target = await supabase
                .from('posts')
                .select('*, author:profiles!posts_author_id_fkey(id, voice_name, avatar_url, is_revealed, real_name)')
                .eq('id', widget.initialPostId!)
                .maybeSingle();
            if (target != null) {
              _sparks.insert(0, Map<String, dynamic>.from(target));
            }
          } catch (_) {}
        }
      }

      await _fetchUserInteractions();

      if (mounted) {
        setState(() { 
          _loading = false; 
          _jumpToInitialPost();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _globalMuted = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    if (!widget.isEmbedded) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    if (_loading) {
      return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: gold)));
    }
    if (_sparks.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: Column(children: [
          IconButton(
            icon: const Icon(LucideIcons.arrow_left, color: Colors.white),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.video, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            const Text('No Sparks yet', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Be the first to share a Spark', style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => context.push('/sparks/create'), child: const Text('Share a Spark')),
          ]))),
        ])),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: _sparks.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) => _SparkPage(
              spark: _sparks[i],
              isActive: i == _currentIndex,
              totalCount: _sparks.length,
              currentIndex: _currentIndex,
              initialLiked: _myReactions.contains(_sparks[i]['id']),
              initialReposted: _myReposts.contains(_sparks[i]['id']),
              onBack: widget.onBack,
              isMuted: _globalMuted,
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  _CircleBtn(
                    onTap: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: const Icon(LucideIcons.arrow_left, size: 18, color: Colors.white),
                  ),
                  const Spacer(),
                  Text('Sparks', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3)),
                  const Spacer(),
                  _CircleBtn(
                    onTap: () => setState(() => _globalMuted = !_globalMuted),
                    child: Icon(_globalMuted ? LucideIcons.volume_x : LucideIcons.volume_2, size: 18, color: Colors.white),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single Spark Page ────────────────────────────────────────────────────────
class _SparkPage extends StatefulWidget {
  final Map<String, dynamic> spark;
  final bool isActive;
  final int totalCount;
  final int currentIndex;
  final bool initialLiked;
  final bool initialReposted;
  final VoidCallback? onBack;
  final bool isMuted;
  const _SparkPage({required this.spark, required this.isActive, required this.totalCount, required this.currentIndex, this.initialLiked = false, this.initialReposted = false, this.onBack, required this.isMuted});
  @override
  State<_SparkPage> createState() => _SparkPageState();
}

class _SparkPageState extends State<_SparkPage> with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _showCaption = false;
  bool _liked = false;
  bool _reposted = false;
  int _likes = 0;
  int _reposts = 0;
  bool _paused = false;

  @override
  bool get wantKeepAlive => true;

  void _init() {
    _ctrl?.dispose();
    _initialized = false;
    _paused = false;
    _liked = widget.initialLiked;
    _reposted = widget.initialReposted;
    _likes = (widget.spark['reaction_healed'] ?? 0) + (widget.spark['reaction_amen'] ?? 0);
    _reposts = widget.spark['reaction_needed'] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _init();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.spark['video_url'] as String?;
    if (url == null || url.isEmpty) return;
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(widget.isMuted ? 0 : 1);
      if (widget.isActive) ctrl.play();
      if (mounted) setState(() { _ctrl = ctrl; _initialized = true; });
    } catch (_) {}
  }

  @override
  void didUpdateWidget(_SparkPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        if (!_paused) _ctrl?.play();
      } else {
        _ctrl?.pause();
        _ctrl?.seekTo(Duration.zero);
      }
    }
    if (widget.isMuted != old.isMuted) {
      _ctrl?.setVolume(widget.isMuted ? 0 : 1);
    }
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  void _togglePlay() {
    setState(() => _paused = !_paused);
    _paused ? _ctrl?.pause() : _ctrl?.play();
  }

  void _toggleLike() async {
    setState(() { _liked = !_liked; _likes += _liked ? 1 : -1; });
    try { 
      await supabase.from('posts').update({'reaction_healed': _likes.clamp(0, 999999)}).eq('id', widget.spark['id']); 
      final uid = supabase.auth.currentUser!.id;
      if (_liked) {
        await supabase.from('reactions').insert({'post_id': widget.spark['id'], 'user_id': uid, 'reaction_type': 'healed'});
      } else {
        await supabase.from('reactions').delete().match({'post_id': widget.spark['id'], 'user_id': uid});
      }
    } catch (_) {}
    if (_liked && widget.spark['author_id'] != null) {
      sendNotification(toUserId: widget.spark['author_id'], type: 'reaction', postId: widget.spark['id'], message: 'liked your spark');
    }
  }

  void _toggleRepost() async {
    setState(() { _reposted = !_reposted; _reposts += _reposted ? 1 : -1; });
    try { 
      await supabase.from('posts').update({'reaction_needed': _reposts.clamp(0, 999999)}).eq('id', widget.spark['id']); 
      final uid = supabase.auth.currentUser!.id;
      if (_reposted) {
        await supabase.from('reposts').insert({'post_id': widget.spark['id'], 'user_id': uid});
      } else {
        await supabase.from('reposts').delete().match({'post_id': widget.spark['id'], 'user_id': uid});
      }
    } catch (_) {}
    if (_reposted && widget.spark['author_id'] != null) {
      sendNotification(toUserId: widget.spark['author_id'], type: 'repost', postId: widget.spark['id'], message: 'reposted your spark');
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => _CommentsSheet(postId: widget.spark['id'], authorId: widget.spark['author_id'], gold: Theme.of(context).colorScheme.primary),
    );
  }

  void _sharePost() {
    _ctrl?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => EchoSheet(post: widget.spark, gold: Theme.of(context).colorScheme.primary, isDark: Theme.of(context).brightness == Brightness.dark),
    ).then((_) {
      if (!_paused) _ctrl?.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gold = Theme.of(context).colorScheme.primary;
    final author = widget.spark['author'] as Map<String, dynamic>?;
    final isAnonymous = widget.spark['is_anonymous'] == true;
    final name = isAnonymous ? 'Anonymous' : ((author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous'));
    final handle = isAnonymous ? 'anonymous' : (author?['voice_name'] ?? 'anonymous');
    final avatarUrl = isAnonymous ? null : (author?['avatar_url'] as String?);
    final caption = widget.spark['body'] ?? '';
    final title = widget.spark['title'] as String?;
    final tags = (widget.spark['tags'] as List?)?.cast<String>() ?? [];

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: () {
        if (!_liked) _toggleLike();
      },
      child: Stack(children: [
        // ── Video / Background ──────────────────────────────────────
        Positioned.fill(
          child: _initialized && _ctrl != null && _ctrl!.value.isInitialized
              ? (_ctrl!.value.aspectRatio > 1.0
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _ctrl!.value.aspectRatio > 0 ? _ctrl!.value.aspectRatio : 16 / 9,
                        child: VideoPlayer(_ctrl!),
                      ),
                    )
                  : SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _ctrl!.value.size.width > 0 ? _ctrl!.value.size.width : 1080,
                          height: _ctrl!.value.size.height > 0 ? _ctrl!.value.size.height : 1920,
                          child: VideoPlayer(_ctrl!),
                        ),
                      ),
                    ))
              : Container(
                  color: const Color(0xFF0D0D0D),
                  child: Center(child: CircularProgressIndicator(color: gold, strokeWidth: 2)),
                ),
        ),

        // ── Gradient overlay ────────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.65, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
        ),

        // ── Paused indicator ────────────────────────────────────────
        if (_paused)
          Center(child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
            child: const Icon(LucideIcons.play, color: Colors.white, size: 30),
          )),


        // ── Right action column ─────────────────────────────────────
        Positioned(
          right: 10,
          bottom: 30,
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Author avatar
              GestureDetector(
                onTap: () { if (!isAnonymous && author?['id'] != null) context.push('/profile/${author!['id']}'); },
                child: Container(
                  width: 50, height: 50,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: gold.withValues(alpha: 0.2),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl.startsWith('http')
                        ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover)
                        : Center(child: Text(name[0].toUpperCase(), style: TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 18))),
                  ),
                ),
              ),

              // Like
              _SideActionBtn(
                icon: LucideIcons.heart,
                activeIcon: Icons.favorite,
                label: _formatCount(_likes),
                active: _liked,
                activeColor: gold,
                onTap: _toggleLike,
              ),
              const SizedBox(height: 24),

              // Repost
              _SideActionBtn(
                icon: LucideIcons.repeat_2,
                label: _formatCount(_reposts),
                active: _reposted,
                activeColor: gold,
                onTap: _toggleRepost,
              ),
              const SizedBox(height: 24),

              // Comments
              _SideActionBtn(
                icon: LucideIcons.message_circle,
                label: _formatCount(widget.spark['comment_count'] ?? 0),
                active: false,
                activeColor: Colors.white,
                onTap: _openComments,
              ),
              const SizedBox(height: 24),

              // Echo
              _SideActionBtn(
                icon: LucideIcons.share,
                label: 'Echo',
                active: false,
                activeColor: Colors.white,
                onTap: _sharePost,
              ),
            ]),
          ),
        ),

        // ── Bottom caption + author ─────────────────────────────────
        Positioned(
          left: 0, right: 78, bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                // Author row
                GestureDetector(
                  onTap: () { if (!isAnonymous && author?['id'] != null) context.push('/profile/${author!['id']}'); },
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white24, border: Border.all(color: Colors.white, width: 1.5)),
                      clipBehavior: Clip.antiAlias,
                      child: avatarUrl != null && avatarUrl.startsWith('http')
                          ? CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover)
                          : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    ),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
                  ]),
                ),

                if (title != null && title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15, shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _showCaption = !_showCaption),
                    child: Text(
                      caption,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45, shadows: [Shadow(blurRadius: 6, color: Colors.black)]),
                      maxLines: _showCaption ? null : 2,
                      overflow: _showCaption ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: tags.take(4).map((t) =>
                    Text('#$t', style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w600, shadows: const [Shadow(blurRadius: 6, color: Colors.black)])),
                  ).toList()),
                ],
              ]),
            ),
          ),
        ),

        // ── Progress bar ────────────────────────────────────────────
        if (_initialized && _ctrl != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: _VideoProgressBar(ctrl: _ctrl!, gold: gold)),
      ]),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─── TikTok-style Comments Sheet ──────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String? authorId;
  final Color gold;
  const _CommentsSheet({required this.postId, this.authorId, required this.gold});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Map<String, dynamic>? _replyingTo;
  Set<String> _likedComments = {};
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _ctrl.dispose(); _focusNode.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await supabase
          .from('comments')
          .select('*, author:profiles!comments_author_id_fkey(id, voice_name, real_name, is_revealed, avatar_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true)
          .limit(60);
      if (mounted) setState(() { _comments = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      final comment = await supabase.from('comments')
          .insert({
            'post_id': widget.postId, 
            'author_id': uid, 
            'body': text,
            if (_replyingTo != null) 'parent_id': _replyingTo!['id']
          })
          .select('*, author:profiles!comments_author_id_fkey(id, voice_name, real_name, is_revealed, avatar_url)')
          .single();
      _ctrl.clear();
      if (mounted) setState(() { 
        _comments.add(Map<String, dynamic>.from(comment)); 
        _sending = false; 
        _replyingTo = null;
      });
      if (widget.authorId != null) {
        sendNotification(toUserId: widget.authorId!, type: 'comment', postId: widget.postId, message: 'commented on your spark');
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final liked = _likedComments.contains(commentId);
    setState(() { if (liked) _likedComments.remove(commentId); else _likedComments.add(commentId); });
    try {
      if (liked) {
        await supabase.from('comment_likes').delete().eq('comment_id', commentId).eq('user_id', uid);
      } else {
        await supabase.from('comment_likes').insert({'comment_id': commentId, 'user_id': uid});
      }
    } catch (_) {
      if (mounted) {
        setState(() { if (liked) _likedComments.add(commentId); else _likedComments.remove(commentId); });
      }
    }
  }

  void _replyTo(Map<String, dynamic> c) {
    setState(() => _replyingTo = c);
    _focusNode.requestFocus();
  }

  Widget _buildComment(Map<String, dynamic> c, Color gold, BuildContext context, bool isDark) {
    final ca = c['author'] as Map<String, dynamic>?;
    final cn = (ca?['is_revealed'] == true && ca?['real_name'] != null) ? ca!['real_name'] : (ca?['voice_name'] ?? 'Anon');
    final caAvatar = ca?['avatar_url'] as String?;
    final isLiked = _likedComments.contains(c['id']);
    final replies = _comments.where((r) => r['parent_id'] == c['id']).toList();
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () { if (ca?['id'] != null) { Navigator.pop(context); context.push('/profile/${ca!['id']}'); } },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)),
              child: ClipOval(
                child: caAvatar != null && caAvatar.startsWith('http')
                    ? CachedNetworkImage(imageUrl: caAvatar, width: 32, height: 32, fit: BoxFit.cover)
                    : Center(child: Text(cn.toString()[0].toUpperCase(), style: TextStyle(fontSize: 12, color: gold))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () { if (ca?['id'] != null) { Navigator.pop(context); context.push('/profile/${ca!['id']}'); } },
                child: Text(cn, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: textColor)),
              ),
              const SizedBox(width: 8),
              Text(c['created_at'] != null ? timeago.format(DateTime.parse(c['created_at'])) : '', style: TextStyle(fontSize: 11, color: hintColor)),
            ]),
            const SizedBox(height: 3),
            MentionText(c['body'] ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor)),
            const SizedBox(height: 6),
            // Like + Reply actions
            Row(children: [
              GestureDetector(
                onTap: () => _toggleCommentLike(c['id']),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isLiked ? Icons.favorite : LucideIcons.heart, size: 14, color: isLiked ? gold : hintColor),
                  const SizedBox(width: 4),
                  Text(isLiked ? 'Liked' : 'Like', style: TextStyle(fontSize: 11, color: isLiked ? gold : hintColor, fontWeight: isLiked ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _replyTo(c),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.reply, size: 14, color: hintColor),
                  const SizedBox(width: 4),
                  Text('Reply', style: TextStyle(fontSize: 11, color: hintColor)),
                ]),
              ),
            ]),
          ])),
        ]),
        // Replies
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 8),
            child: Column(children: replies.map((r) => _buildComment(r, gold, context, isDark)).toList()),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(children: [
        // Handle + header
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(99)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            Text('Comments', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(width: 8),
            Text('${_comments.length}', style: TextStyle(color: text3, fontSize: 14)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(LucideIcons.x, size: 20, color: text3)),
          ]),
        ),
        Divider(height: 1, color: border),

        // Comments list
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: widget.gold, strokeWidth: 2))
              : _comments.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.message_circle, size: 36, color: text3),
                      const SizedBox(height: 10),
                      Text('No comments yet\nBe the first!', textAlign: TextAlign.center, style: TextStyle(color: text3, fontSize: 14)),
                    ]))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: _comments.where((c) => c['parent_id'] == null).map((c) => _buildComment(c, widget.gold, context, isDark)).toList(),
                    ),
        ),

        // Reply Indicator
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: widget.gold.withValues(alpha: 0.1),
            child: Row(children: [
              Icon(LucideIcons.reply, size: 14, color: widget.gold),
              const SizedBox(width: 8),
              Expanded(child: Text('Replying to ${(_replyingTo!['author']?['is_revealed'] == true && _replyingTo!['author']?['real_name'] != null) ? _replyingTo!['author']!['real_name'] : (_replyingTo!['author']?['voice_name'] ?? 'Anon')}', style: TextStyle(fontSize: 12, color: widget.gold, fontWeight: FontWeight.w600))),
              GestureDetector(
                onTap: () => setState(() => _replyingTo = null),
                child: Icon(LucideIcons.x, size: 16, color: widget.gold),
              ),
            ]),
          ),

        // Input bar
        Container(
          padding: EdgeInsets.only(left: 16, right: 12, top: 10, bottom: MediaQuery.of(context).viewInsets.bottom + 14),
          decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: border, width: 0.5))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _replyingTo != null ? 'Write a reply...' : 'Add a comment…',
                  hintStyle: TextStyle(color: text3, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide(color: widget.gold, width: 1.5)),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold),
                child: _sending
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.send, size: 18, color: Colors.white),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────
class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController ctrl;
  final Color gold;
  const _VideoProgressBar({required this.ctrl, required this.gold});
  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}
class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override
  void initState() { super.initState(); widget.ctrl.addListener(_update); }
  void _update() { if (mounted) setState(() {}); }
  @override
  void dispose() { widget.ctrl.removeListener(_update); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final pos = widget.ctrl.value.position.inMilliseconds.toDouble();
    final dur = widget.ctrl.value.duration.inMilliseconds.toDouble();
    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.white.withValues(alpha: 0.18),
      valueColor: AlwaysStoppedAnimation<Color>(widget.gold),
      minHeight: 2.5,
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleBtn({required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.45)),
      child: Center(child: child),
    ),
  );
}

class _SideActionBtn extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _SideActionBtn({required this.icon, this.activeIcon, required this.label, required this.active, required this.activeColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : Colors.white;
    final displayIcon = (active && activeIcon != null) ? activeIcon! : icon;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedScale(
          scale: active ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Icon(displayIcon, size: 30, color: color, shadows: const [Shadow(blurRadius: 10, color: Colors.black)]),
        ),
        const SizedBox(height: 3),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(label, key: ValueKey(label), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, shadows: const [Shadow(blurRadius: 6, color: Colors.black)])),
        ),
      ]),
    );
  }
}
