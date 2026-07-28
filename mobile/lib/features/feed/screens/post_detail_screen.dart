import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';
import '../widgets/echo_sheet.dart';
import '../../../shared/widgets/mention_overlay.dart';
import '../../../shared/widgets/mention_text_editing_controller.dart';
import '../../../shared/widgets/mention_text.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  final _commentCtrl = MentionTextEditingController();
  final _commentLink = LayerLink();
  bool _sending = false;
  bool _myReacted = false;
  bool _mySaved = false;
  bool _myReposted = false;
  Set<String> _likedComments = {};
  String? _replyToId;
  String? _replyToName;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _videoPlaying = false;
  bool _muted = true;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioPlaying = false;
  
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingPill = true;
  bool _showCommentInput = false;
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_showFloatingPill) setState(() => _showFloatingPill = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_showFloatingPill) setState(() => _showFloatingPill = true);
      }
    });
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final post = await supabase.from('posts')
          .select('*, author:profiles!posts_author_id_fkey(id, voice_name, real_name, is_revealed, avatar_url)')
          .eq('id', widget.postId).single();

      if (post['content_type'] == 'short' || post['content_type'] == 'spark' || (post['video_url'] != null && (post['video_url'] as String).isNotEmpty)) {
        if (mounted) {
          context.replace('/sparks?id=${widget.postId}');
        }
        return;
      }

      final comments = await supabase.from('comments')
          .select('*, author:profiles!comments_author_id_fkey(id, voice_name, real_name, is_revealed, avatar_url)')
          .eq('post_id', widget.postId).order('created_at');
      if (mounted) {
        setState(() { _post = post; _comments = List<Map<String, dynamic>>.from(comments); });
        _initVideo();
        _loadUserState();
      }
    } catch (e) {
      debugPrint('Error loading post details: $e');
    }
  }

  Future<void> _loadUserState() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final r = await supabase.from('reactions').select('id').eq('user_id', uid).eq('post_id', widget.postId).maybeSingle();
      if (mounted) setState(() => _myReacted = r != null);
    } catch (_) {}
    try {
      final s = await supabase.from('saved_posts').select('id').eq('user_id', uid).eq('post_id', widget.postId).maybeSingle();
      if (mounted) setState(() => _mySaved = s != null);
    } catch (_) {}
    try {
      final rp = await supabase.from('reposts').select('id').eq('user_id', uid).eq('post_id', widget.postId).maybeSingle();
      if (mounted) setState(() => _myReposted = rp != null);
    } catch (_) {}
  }

  void _initVideo() {
    final url = _post?['video_url'] as String?;
    if (url == null || url.isEmpty) return;
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoReady = true);
          _videoCtrl!.play();
          setState(() => _videoPlaying = true);
        }
      });
  }

  void _togglePlay() {
    if (_videoCtrl == null) return;
    if (_videoPlaying) {
      _videoCtrl!.pause();
    } else {
      _videoCtrl!.play();
    }
    setState(() => _videoPlaying = !_videoPlaying);
  }

  void _toggleMute() {
    if (_videoCtrl == null) return;
    setState(() => _muted = !_muted);
    _videoCtrl!.setVolume(_muted ? 0 : 1);
  }

  Future<void> _toggleAudio(String url) async {
    try {
      if (_isAudioPlaying) {
        await _audioPlayer.pause();
        setState(() => _isAudioPlaying = false);
      } else {
        if (url.startsWith('http')) {
          await _audioPlayer.play(UrlSource(url));
        } else {
          try {
            String assetPath = url;
            if (assetPath.startsWith('assets/')) {
              assetPath = assetPath.substring(7);
            }
            await _audioPlayer.play(AssetSource(assetPath));
          } catch (_) {
            await _audioPlayer.play(UrlSource('https://ijwi-orpin.vercel.app/$url'));
          }
        }
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        setState(() => _isAudioPlaying = true);
      }
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _sending = true);
    final data = <String, dynamic>{'post_id': widget.postId, 'author_id': userId, 'body': text};
    if (_replyToId != null) data['parent_id'] = _replyToId;
    await supabase.from('comments').insert(data);
    final authorId = (_post?['author'] as Map<String, dynamic>?)?['id'] as String?;
    if (authorId != null) sendNotification(toUserId: authorId, type: 'comment', postId: widget.postId, message: 'commented on your post');
    // Notify mentioned users
    notifyMentions(text, postId: widget.postId);
    _commentCtrl.clear();
    setState(() { _replyToId = null; _replyToName = null; });
    await _load();
    setState(() => _sending = false);
  }

  void _replyTo(Map<String, dynamic> comment) {
    final ca = comment['author'] as Map<String, dynamic>?;
    final name = (ca?['is_revealed'] == true && ca?['real_name'] != null) ? ca!['real_name'] : (ca?['voice_name'] ?? 'Anon');
    setState(() { _replyToId = comment['id']; _replyToName = name; });
    _commentCtrl.text = '@${ ca?['voice_name'] ?? ''} ';
    _commentCtrl.selection = TextSelection.collapsed(offset: _commentCtrl.text.length);
  }

  Future<void> _toggleCommentLike(String commentId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final liked = _likedComments.contains(commentId);
    setState(() { if (liked) _likedComments.remove(commentId); else _likedComments.add(commentId); });
    try {
      // Increment/decrement the comment's reaction_amen count
      final comment = _comments.firstWhere((c) => c['id'] == commentId, orElse: () => {});
      if (comment.isEmpty) return;
      final current = (comment['reaction_amen'] ?? 0) as int;
      final newVal = liked ? (current - 1).clamp(0, 99999) : current + 1;
      await supabase.from('comments').update({'reaction_amen': newVal}).eq('id', commentId);
      comment['reaction_amen'] = newVal;
    } catch (_) {
      setState(() { if (liked) _likedComments.add(commentId); else _likedComments.remove(commentId); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_post == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final author = _post!['author'] as Map<String, dynamic>?;
    final name = (author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous');
    final authorAvatar = author?['avatar_url'] as String?;
    final hasVideo = _post!['video_url'] != null && (_post!['video_url'] as String).isNotEmpty;
    final isLoggedIn = supabase.auth.currentUser != null;
    final isEssay = _post!['content_type'] == 'essay' || _post!['cover_color'] != null;
    final coverColorHex = _post!['cover_color'] as String?;
    final coverColor = coverColorHex != null && coverColorHex.startsWith('#') && coverColorHex.length == 7
        ? Color(int.parse('FF${coverColorHex.substring(1)}', radix: 16))
        : null;
    final musicUrl = _post!['music_url'] as String?;

    if (isEssay) return _buildEssayView(context, gold, isDark, author, name, authorAvatar, coverColor, musicUrl, isLoggedIn);

    final isOwn = supabase.auth.currentUser?.id == author?['id'];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Header: back + avatar + name + edit
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Icon(LucideIcons.arrow_left, size: 22, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () { if (author?['id'] != null) context.push('/profile/${author!['id']}'); },
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                  child: ClipOval(
                    child: authorAvatar != null && authorAvatar.startsWith('http')
                        ? Image.network(authorAvatar, width: 34, height: 34, fit: BoxFit.cover)
                        : Center(child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gold))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () { if (author?['id'] != null) context.push('/profile/${author!['id']}'); },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                  Text(timeago.format(DateTime.parse(_post!['created_at'])), style: TextStyle(fontSize: 11, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
                ]),
              )),
              if (isOwn)
                GestureDetector(
                  onTap: () => _editPost(context),
                  child: Icon(LucideIcons.pen_line, size: 18, color: gold),
                ),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Video player
            if (hasVideo) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: AspectRatio(
                    aspectRatio: _videoReady ? _videoCtrl!.value.aspectRatio.clamp(0.56, 2.0) : 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: _videoReady
                          ? Stack(children: [
                              Positioned.fill(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoCtrl!.value.size.width,
                                    height: _videoCtrl!.value.size.height,
                                    child: VideoPlayer(_videoCtrl!),
                                  ),
                                ),
                              ),
                            // Play/pause overlay
                            if (!_videoPlaying)
                              Positioned.fill(child: Container(
                                color: Colors.black38,
                                child: Center(child: Container(
                                  width: 56, height: 56,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54, border: Border.all(color: Colors.white70, width: 1.5)),
                                  child: const Icon(LucideIcons.play, color: Colors.white, size: 24),
                                )),
                              )),
                            // Mute/unmute button
                            Positioned(
                              bottom: 12, right: 12,
                              child: GestureDetector(
                                onTap: _toggleMute,
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54, border: Border.all(color: Colors.white30)),
                                  child: Icon(_muted ? LucideIcons.volume_x : LucideIcons.volume_2, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ])
                        : const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],

            // Title
            if (_post!['title'] != null) ...[
              const SizedBox(height: 20),
              Text(_post!['title'], style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w500)),
            ],

            // Body
            if (_post!['body'] != null && (_post!['body'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              MentionText(_post!['body'], style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.75, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2)),
            ],

            // Reactions + Share
            const SizedBox(height: 20),
            if (isLoggedIn) Row(children: [
              _DetailReactionBtn(icon: LucideIcons.heart, activeIcon: Icons.favorite, count: ((_post!['reaction_healed'] ?? 0) + (_post!['reaction_amen'] ?? 0)) as int, active: _myReacted, gold: gold, onTap: () => _react('healed')),
              const SizedBox(width: 6),
              _DetailReactionBtn(icon: LucideIcons.repeat_2, count: 0, active: _myReposted, gold: gold, onTap: _toggleRepost),
              const Spacer(),
              GestureDetector(
                onTap: _toggleSave,
                child: Icon(_mySaved ? LucideIcons.bookmark_check : LucideIcons.bookmark, size: 20, color: _mySaved ? gold : Theme.of(context).hintColor),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => EchoSheet(post: _post!, gold: gold, isDark: isDark),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2, width: 0.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(LucideIcons.share, size: 14, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2),
                    const SizedBox(width: 5),
                    Text('Echo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2)),
                  ]),
                ),
              ),
            ]),

            const SizedBox(height: 20),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 12),

            // Comments
            Text('Comments (${_comments.length})', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            ..._comments.where((c) => c['parent_id'] == null).map((c) => _buildComment(c, gold, context)),
            if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No comments yet', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))),
              ),
          ]),
        )),

        // Comment input (only for logged-in users)
        if (isLoggedIn)
          Column(mainAxisSize: MainAxisSize.min, children: [
            if (_replyToName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: gold.withValues(alpha: 0.05),
                child: Row(children: [
                  Text('Replying to ', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  Text(_replyToName!, style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(onTap: () => setState(() { _replyToId = null; _replyToName = null; }), child: Icon(LucideIcons.x, size: 14, color: Theme.of(context).hintColor)),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
              child: Row(children: [
                Expanded(child: MentionOverlay(
                  controller: _commentCtrl,
                  layerLink: _commentLink,
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: InputDecoration(hintText: _replyToName != null ? 'Reply...' : 'Write a comment...', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).dividerColor)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendComment,
                  child: CircleAvatar(radius: 20, backgroundColor: gold, child: Icon(LucideIcons.send, size: 16, color: isDark ? IjwiColors.darkBg : IjwiColors.lightBg)),
                ),
              ]),
            ),
          ]),
      ]),
      ),
    );
  }

  void _editPost(BuildContext context) {
    context.push('/write/edit/${widget.postId}');
  }

  void _showMoreOptions(BuildContext context, bool isOwn, Color gold, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            if (isOwn) ...[
              ListTile(
                leading: Icon(LucideIcons.pen_line, color: gold),
                title: const Text('Edit Essay'),
                onTap: () {
                  Navigator.pop(context);
                  _editPost(context);
                },
              ),
              ListTile(
                leading: Icon(LucideIcons.eye, color: gold),
                title: const Text('Change Visibility'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visibility options coming soon.')));
                },
              ),
            ],
            ListTile(
              leading: Icon(LucideIcons.link, color: gold),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: 'https://ijwi-orpin.vercel.app/post/${widget.postId}'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComment(Map<String, dynamic> c, Color gold, BuildContext context) {
    final ca = c['author'] as Map<String, dynamic>?;
    final cn = (ca?['is_revealed'] == true && ca?['real_name'] != null) ? ca!['real_name'] : (ca?['voice_name'] ?? 'Anon');
    final caAvatar = ca?['avatar_url'] as String?;
    final isLiked = _likedComments.contains(c['id']);
    final replies = _comments.where((r) => r['parent_id'] == c['id']).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () { if (ca?['id'] != null) context.push('/profile/${ca!['id']}'); },
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)),
              child: ClipOval(
                child: caAvatar != null && caAvatar.startsWith('http')
                    ? Image.network(caAvatar, width: 28, height: 28, fit: BoxFit.cover)
                    : Center(child: Text(cn.toString()[0].toUpperCase(), style: TextStyle(fontSize: 11, color: gold))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () { if (ca?['id'] != null) context.push('/profile/${ca!['id']}'); },
                child: Text(cn, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(timeago.format(DateTime.parse(c['created_at'])), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ]),
            const SizedBox(height: 3),
            MentionText(c['body'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            // Like + Reply actions
            Row(children: [
              GestureDetector(
                onTap: () => _toggleCommentLike(c['id']),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isLiked ? Icons.favorite : LucideIcons.heart, size: 14, color: isLiked ? gold : Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text(isLiked ? 'Liked' : 'Like', style: TextStyle(fontSize: 11, color: isLiked ? gold : Theme.of(context).hintColor, fontWeight: isLiked ? FontWeight.w600 : FontWeight.w400)),
                ]),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _replyTo(c),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.reply, size: 14, color: Theme.of(context).hintColor),
                  const SizedBox(width: 4),
                  Text('Reply', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                ]),
              ),
            ]),
          ])),
        ]),
        // Replies
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 8),
            child: Column(children: replies.map((r) => _buildComment(r, gold, context)).toList()),
          ),
      ]),
    );
  }


  String? _extractMusicName(String? url) {
    if (url == null) return null;
    final file = Uri.parse(url).pathSegments.lastOrNull ?? url;
    return file.replaceAll(RegExp(r'\(chosic\.com\)'), '').replaceAll('.mp3', '').replaceAll('-', ' ').replaceAll('_', ' ').trim();
  }
  Widget _buildEssayView(BuildContext context, Color gold, bool isDark, Map<String, dynamic>? author, String name, String? authorAvatar, Color? coverColor, String? musicUrl, bool isLoggedIn) {
    final bg = isDark ? IjwiColors.darkBg : IjwiColors.lightBg;
    final textColor = isDark ? IjwiColors.darkText : IjwiColors.lightText;
    final textMuted = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final divColor = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final isOwn = supabase.auth.currentUser?.id == author?['id'];
    
    final title = _post!['title'] ?? '';
    final subtitle = _post!['subtitle'] as String?;
    final body = _post!['body'] ?? '';
    final coverImageUrl = _post!['cover_image_url'] as String?;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Minimal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                          child: Icon(LucideIcons.chevron_left, size: 22, color: textColor),
                        ),
                      ),
                      Row(
                        children: [
                          if (musicUrl != null && musicUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () => _toggleAudio(musicUrl),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                                child: Icon(_isAudioPlaying ? Icons.pause : LucideIcons.play, size: 18, color: textColor),
                              ),
                            ),
                          GestureDetector(
                            onTap: () {
                               _showMoreOptions(context, isOwn, gold, isDark);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                              child: Icon(Icons.more_horiz, size: 18, color: textColor),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(title, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: textColor, height: 1.2, letterSpacing: -0.5)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(subtitle, style: GoogleFonts.poppins(fontSize: 18, color: textMuted, fontWeight: FontWeight.w500)),
                        ],
                        const SizedBox(height: 24),
                        
                        // Author Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text(timeago.format(DateTime.parse(_post!['created_at'])).toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () { if (author?['id'] != null) context.push('/profile/${author!['id']}'); },
                              child: ClipOval(
                                child: authorAvatar != null && authorAvatar.startsWith('http')
                                    ? Image.network(authorAvatar, width: 40, height: 40, fit: BoxFit.cover)
                                    : Container(width: 40, height: 40, color: gold.withValues(alpha: 0.2), child: Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: gold)))),
                              ),
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        Divider(color: divColor, height: 1),
                        const SizedBox(height: 24),
                        
                        // Image
                        if (coverImageUrl != null && coverImageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(0),
                            child: Image.network(coverImageUrl, width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Body
                        MentionText(body, style: GoogleFonts.lora(fontSize: 17, height: 1.8, color: textColor.withValues(alpha: 0.9))),
                        
                        const SizedBox(height: 60),
                        
                        // Comments Section
                        Text('Comments (${_comments.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ..._comments.where((c) => c['parent_id'] == null).map((c) => _buildComment(c, gold, context)),
                        if (_comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _showCommentInput = true);
                                  Future.delayed(const Duration(milliseconds: 100), () => _commentFocusNode.requestFocus());
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('Be the first to comment', style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
                                ),
                              )
                            )
                          ),
                          
                        const SizedBox(height: 100), // padding for the floating pill
                      ],
                    ),
                  ),
                ),
                
                // Comment input at bottom
                if (isLoggedIn && (_showCommentInput || _comments.isNotEmpty))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: divColor))),
                    child: Row(children: [
                      Expanded(child: MentionOverlay(
                        controller: _commentCtrl,
                        layerLink: _commentLink,
                        child: TextField(
                          focusNode: _commentFocusNode,
                          controller: _commentCtrl,
                          decoration: InputDecoration(hintText: _replyToName != null ? 'Reply...' : 'Write a comment...', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: divColor)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                          maxLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                        ),
                      )),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sending ? null : _sendComment,
                        child: CircleAvatar(radius: 20, backgroundColor: gold, child: Icon(LucideIcons.send, size: 16, color: isDark ? IjwiColors.darkBg : IjwiColors.lightBg)),
                      ),
                    ]),
                  ),
              ],
            ),
            
            // Floating Action Pill
            if (isLoggedIn)
              Positioned(
                bottom: 80, // Above comment bar
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedSlide(
                    offset: _showFloatingPill ? Offset.zero : const Offset(0, 2),
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedOpacity(
                      opacity: _showFloatingPill ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
                          border: Border.all(color: divColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Like
                        _buildPillAction(
                          icon: _myReacted ? Icons.favorite : LucideIcons.heart,
                          color: _myReacted ? gold : textColor,
                          count: ((_post!['reaction_healed'] ?? 0) + (_post!['reaction_amen'] ?? 0)) as int,
                          onTap: () => _react('healed')
                        ),
                        const SizedBox(width: 24),
                        // Comment
                        _buildPillAction(
                          icon: LucideIcons.message_circle,
                          color: textColor,
                          count: _comments.length,
                          onTap: () {
                             setState(() => _showCommentInput = true);
                             Future.delayed(const Duration(milliseconds: 100), () => _commentFocusNode.requestFocus());
                          }
                        ),
                        const SizedBox(width: 24),
                        // Repost
                        _buildPillAction(
                          icon: LucideIcons.repeat_2,
                          color: _myReposted ? gold : textColor,
                          count: (_post!['reaction_amen'] ?? 0) as int, // using reaction_amen for reposts or whatever exists
                          onTap: _toggleRepost
                        ),
                        const SizedBox(width: 24),
                        // Share
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => EchoSheet(post: _post!, gold: gold, isDark: isDark));
                          },
                          child: Icon(LucideIcons.upload, size: 20, color: textColor),
                        ),
                      ],
                    )
                  )
                )
              )
            )
           )
          ],
        ),
      ),
    );
  }

  Widget _buildPillAction({required IconData icon, required Color color, required int count, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(count.toString(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ]
        ],
      ),
    );
  }

  Future<void> _react(String type) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (_myReacted) {
      setState(() { _myReacted = false; _post!['reaction_$type'] = ((_post!['reaction_$type'] ?? 1) - 1).clamp(0, 99999); });
      try { await supabase.from('reactions').delete().match({'post_id': widget.postId, 'user_id': uid}); } catch (_) {
        setState(() { _myReacted = true; _post!['reaction_$type'] = (_post!['reaction_$type'] ?? 0) + 1; });
      }
    } else {
      setState(() { _myReacted = true; _post!['reaction_$type'] = (_post!['reaction_$type'] ?? 0) + 1; });
      try {
        await supabase.from('reactions').insert({'post_id': widget.postId, 'user_id': uid, 'reaction_type': type});
        await supabase.from('posts').update({'reaction_$type': _post!['reaction_$type']}).eq('id', widget.postId);
      } catch (_) {
        setState(() { _myReacted = false; _post!['reaction_$type'] = ((_post!['reaction_$type'] ?? 1) - 1).clamp(0, 99999); });
      }
    }
  }

  Future<void> _toggleSave() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _mySaved = !_mySaved);
    try {
      if (!_mySaved) {
        await supabase.from('saved_posts').delete().match({'post_id': widget.postId, 'user_id': uid});
      } else {
        await supabase.from('saved_posts').insert({'post_id': widget.postId, 'user_id': uid});
      }
    } catch (_) { setState(() => _mySaved = !_mySaved); }
  }

  Future<void> _toggleRepost() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _myReposted = !_myReposted);
    try {
      if (!_myReposted) {
        await supabase.from('reposts').delete().match({'post_id': widget.postId, 'user_id': uid});
      } else {
        await supabase.from('reposts').insert({'post_id': widget.postId, 'user_id': uid});
      }
    } catch (_) { setState(() => _myReposted = !_myReposted); }
  }
}


class _DetailReactionBtn extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final int count;
  final bool active;
  final Color gold;
  final VoidCallback onTap;
  const _DetailReactionBtn({required this.icon, this.activeIcon, required this.count, required this.active, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasCount = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: active ? gold.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? gold.withValues(alpha: 0.3) : Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(active && activeIcon != null ? activeIcon : icon, size: 18, color: active ? gold : Theme.of(context).hintColor),
          if (hasCount) ...[const SizedBox(width: 5), Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gold))],
        ]),
      ),
    );
  }
}


class _EssayMusicBar extends StatefulWidget {
  final String url;
  final String? name;
  final Color gold;
  const _EssayMusicBar({required this.url, this.name, required this.gold});
  @override
  State<_EssayMusicBar> createState() => _EssayMusicBarState();
}

class _EssayMusicBarState extends State<_EssayMusicBar> with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _muted = false;
  double _volume = 1.0;
  OverlayEntry? _volumeOverlay;
  late AnimationController _overlayAnim;
  late Animation<double> _overlayScale;
  late Animation<double> _overlayFade;

  @override
  void initState() {
    super.initState();
    _overlayAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _overlayScale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOutCubic));
    _overlayFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _overlayAnim, curve: Curves.easeOut));
    _startPlaying();
  }

  Future<void> _startPlaying() async {
    try {
      final url = widget.url;
      if (url.startsWith('http')) {
        await _player.play(UrlSource(url));
      } else {
        try {
          await _player.play(AssetSource(url));
        } catch (_) {
          await _player.play(UrlSource('https://ijwi-orpin.vercel.app/$url'));
        }
      }
      await _player.setReleaseMode(ReleaseMode.loop);
      if (mounted) setState(() => _playing = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _dismissVolumeOverlay();
    _overlayAnim.dispose();
    _player.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player.setVolume(_muted ? 0 : _volume);
  }

  void _toggle() {
    if (_playing) { _player.pause(); } else { _player.resume(); }
    setState(() => _playing = !_playing);
  }

  void _showVolumeOverlay() {
    if (_volumeOverlay != null) return;
    _volumeOverlay = OverlayEntry(builder: (ctx) {
      return _VolumeOverlay(
        gold: widget.gold,
        volume: _volume,
        fadeAnim: _overlayFade,
        scaleAnim: _overlayScale,
        onVolumeChanged: (v) {
          setState(() { _volume = v; _muted = v == 0; });
          _player.setVolume(v);
          _volumeOverlay?.markNeedsBuild();
        },
        onDismiss: _dismissVolumeOverlay,
      );
    });
    Overlay.of(context).insert(_volumeOverlay!);
    _overlayAnim.forward();
  }

  void _dismissVolumeOverlay() async {
    if (_volumeOverlay == null) return;
    await _overlayAnim.reverse();
    _volumeOverlay?.remove();
    _volumeOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final songName = widget.name ?? 'Background music';
    return GestureDetector(
      onLongPress: _showVolumeOverlay,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: IjwiSpacing.xl, vertical: IjwiSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: IjwiSizes.avatarMd, height: IjwiSizes.avatarMd,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold),
              child: Icon(_playing ? LucideIcons.pause : LucideIcons.play, size: IjwiSizes.iconSm, color: Colors.white),
            ),
          ),
          const SizedBox(width: IjwiSpacing.md),
          Icon(LucideIcons.music, size: IjwiSizes.iconSm, color: Colors.white54),
          const SizedBox(width: 6),
          Expanded(child: Text(
            _playing ? songName : 'Tap to play',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
            overflow: TextOverflow.ellipsis,
          )),
          GestureDetector(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_muted ? LucideIcons.volume_x : LucideIcons.volume_2, size: IjwiSizes.iconSm, color: _muted ? Colors.white38 : widget.gold),
                const SizedBox(width: IjwiSpacing.xs),
                Text(_muted ? 'Muted' : 'Sound', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _muted ? Colors.white38 : widget.gold)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Full-screen frosted glass overlay with a tall vertical volume slider.
class _VolumeOverlay extends StatefulWidget {
  final Color gold;
  final double volume;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onDismiss;

  const _VolumeOverlay({
    required this.gold,
    required this.volume,
    required this.fadeAnim,
    required this.scaleAnim,
    required this.onVolumeChanged,
    required this.onDismiss,
  });

  @override
  State<_VolumeOverlay> createState() => _VolumeOverlayState();
}

class _VolumeOverlayState extends State<_VolumeOverlay> {
  late double _currentVolume;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.volume;
  }

  @override
  void didUpdateWidget(_VolumeOverlay old) {
    super.didUpdateWidget(old);
    _currentVolume = widget.volume;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.fadeAnim,
      builder: (context, child) => Opacity(
        opacity: widget.fadeAnim.value,
        child: child,
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // prevent dismiss when tapping the slider
                child: ScaleTransition(
                  scale: widget.scaleAnim,
                  child: Container(
                    width: 64,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Icon(
                          _currentVolume == 0 ? LucideIcons.volume_x : (_currentVolume < 0.5 ? LucideIcons.volume_1 : LucideIcons.volume_2),
                          size: IjwiSizes.iconMd,
                          color: widget.gold,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 6,
                                trackShape: const RoundedRectSliderTrackShape(),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                                activeTrackColor: widget.gold,
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                                thumbColor: Colors.white,
                                overlayColor: widget.gold.withValues(alpha: 0.12),
                              ),
                              child: Slider(
                                value: _currentVolume,
                                onChanged: (v) {
                                  setState(() => _currentVolume = v);
                                  widget.onVolumeChanged(v);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_currentVolume * 100).round()}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

