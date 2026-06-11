import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';
import '../widgets/echo_sheet.dart';
import '../../../shared/widgets/mention_overlay.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<Map<String, dynamic>> _comments = [];
  final _commentCtrl = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final post = await supabase.from('posts')
          .select('*, author:profiles!posts_author_id_fkey(id, voice_name, real_name, is_revealed, avatar_url)')
          .eq('id', widget.postId).single();
      final comments = await supabase.from('comments')
          .select('*, author:profiles!comments_author_id_fkey(id, voice_name, real_name, is_revealed, avatar_url)')
          .eq('post_id', widget.postId).order('created_at');
      if (mounted) {
        setState(() { _post = post; _comments = List<Map<String, dynamic>>.from(comments); });
        _initVideo();
        _loadUserState();
      }
    } catch (_) {}
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
      if (liked) {
        await supabase.from('reactions').delete().match({'post_id': commentId, 'user_id': uid, 'reaction_type': 'comment_like'});
      } else {
        await supabase.from('reactions').insert({'post_id': commentId, 'user_id': uid, 'reaction_type': 'comment_like'});
      }
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
    final isEssay = _post!['content_type'] == 'essay';
    final coverColorHex = _post!['cover_color'] as String?;
    final coverColor = coverColorHex != null && coverColorHex.startsWith('#')
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
                  Text(name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
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
              Text(_post!['title'], style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w500)),
            ],

            // Body
            if (_post!['body'] != null && (_post!['body'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_post!['body'], style: GoogleFonts.dmSans(fontSize: 15, height: 1.75)),
            ],

            // Reactions + Share
            const SizedBox(height: 20),
            if (isLoggedIn) Row(children: [
              _DetailReactionBtn(icon: LucideIcons.heart, count: ((_post!['reaction_healed'] ?? 0) + (_post!['reaction_amen'] ?? 0)) as int, active: _myReacted, gold: gold, onTap: () => _react('healed')),
              const SizedBox(width: 6),
              _DetailReactionBtn(icon: LucideIcons.droplets, count: (_post!['reaction_needed'] ?? 0) as int, active: false, gold: gold, onTap: () => _react('needed')),
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
            Text('Comments (${_comments.length})', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14)),
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
    final titleCtrl = TextEditingController(text: _post?['title'] ?? '');
    final bodyCtrl = TextEditingController(text: _post?['body'] ?? '');
    final gold = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
            Row(children: [
              Text('Edit Post', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w500)),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                  await supabase.from('posts').update({
                    'title': titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                  }).eq('id', widget.postId);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                child: const Text('Save'),
              ),
            ]),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Title', border: InputBorder.none, hintStyle: GoogleFonts.fraunces(fontSize: 18, color: Theme.of(context).hintColor))),
            Container(height: 0.5, color: Theme.of(context).dividerColor),
            TextField(controller: bodyCtrl, maxLines: null, minLines: 5, style: GoogleFonts.dmSans(fontSize: 14, height: 1.7), decoration: InputDecoration(hintText: 'Body', border: InputBorder.none, hintStyle: GoogleFonts.dmSans(fontSize: 14, color: Theme.of(context).hintColor))),
          ]),
        )),
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
                child: Text(cn, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(timeago.format(DateTime.parse(c['created_at'])), style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ]),
            const SizedBox(height: 3),
            Text(c['body'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            // Like + Reply actions
            Row(children: [
              GestureDetector(
                onTap: () => _toggleCommentLike(c['id']),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.heart, size: 14, color: isLiked ? gold : Theme.of(context).hintColor),
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

  Widget _buildEssayView(BuildContext context, Color gold, bool isDark, Map<String, dynamic>? author, String name, String? authorAvatar, Color? coverColor, String? musicUrl, bool isLoggedIn) {
    final bg = coverColor ?? const Color(0xFF1a1840);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton(color: Colors.white)),
      body: Column(children: [
        if (musicUrl != null && musicUrl.isNotEmpty)
          _EssayMusicBar(url: musicUrl, gold: gold),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Author
            GestureDetector(
              onTap: () { if (author?['id'] != null) context.push('/profile/${author!['id']}'); },
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white12),
                  child: ClipOval(
                    child: authorAvatar != null && authorAvatar.startsWith('http')
                        ? Image.network(authorAvatar, width: 36, height: 36, fit: BoxFit.cover)
                        : Center(child: Text(name[0].toUpperCase(), style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
                  ),
                ),
                const SizedBox(width: 10),
                Text(name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 24),
            // Title
            Text(_post!['title'] ?? '', style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3)),
            if (_post!['subtitle'] != null) ...[
              const SizedBox(height: 8),
              Text(_post!['subtitle'], style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white60)),
            ],
            const SizedBox(height: 24),
            Container(height: 1, color: Colors.white12),
            const SizedBox(height: 24),
            // Body
            Text(_post!['body'] ?? '', style: GoogleFonts.dmSans(fontSize: 16, height: 1.9, color: Colors.white.withValues(alpha: 0.88))),
            const SizedBox(height: 32),
            // Actions
            if (isLoggedIn) Row(children: [
              _DetailReactionBtn(icon: LucideIcons.heart, count: ((_post!['reaction_healed'] ?? 0) + (_post!['reaction_amen'] ?? 0)) as int, active: _myReacted, gold: gold, onTap: () => _react('healed')),
              const SizedBox(width: 6),
              _DetailReactionBtn(icon: LucideIcons.droplets, count: (_post!['reaction_needed'] ?? 0) as int, active: false, gold: gold, onTap: () => _react('needed')),
              const Spacer(),
              GestureDetector(onTap: _toggleSave, child: Icon(_mySaved ? LucideIcons.bookmark_check : LucideIcons.bookmark, size: 20, color: _mySaved ? gold : Colors.white54)),
            ]),
            const SizedBox(height: 60),
          ]),
        )),
      ]),
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
  final int count;
  final bool active;
  final Color gold;
  final VoidCallback onTap;
  const _DetailReactionBtn({required this.icon, required this.count, required this.active, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasCount = count > 0;
    final highlighted = active || hasCount;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: highlighted ? gold.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(color: highlighted ? gold.withValues(alpha: 0.3) : Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? gold : (hasCount ? gold : Theme.of(context).hintColor)),
          if (hasCount) ...[const SizedBox(width: 5), Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gold))],
        ]),
      ),
    );
  }
}


class _EssayMusicBar extends StatefulWidget {
  final String url;
  final Color gold;
  const _EssayMusicBar({required this.url, required this.gold});
  @override
  State<_EssayMusicBar> createState() => _EssayMusicBarState();
}

class _EssayMusicBarState extends State<_EssayMusicBar> {
  VideoPlayerController? _ctrl;
  bool _playing = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) { setState(() => _ready = true); _ctrl!.play(); setState(() => _playing = true); }
      });
    _ctrl!.setLooping(true);
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  void _toggle() {
    if (_ctrl == null) return;
    if (_playing) { _ctrl!.pause(); } else { _ctrl!.play(); }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white12)),
      child: Row(children: [
        GestureDetector(
          onTap: _ready ? _toggle : null,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold),
            child: Icon(_playing ? LucideIcons.pause : LucideIcons.play, size: 14, color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Icon(LucideIcons.music, size: 14, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(child: Text(_playing ? 'Playing...' : 'Background music', style: TextStyle(fontSize: 12, color: Colors.white54))),
        if (_playing)
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold)),
      ]),
    );
  }
}
