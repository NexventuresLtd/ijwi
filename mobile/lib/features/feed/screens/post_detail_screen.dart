import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../widgets/echo_sheet.dart';

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
  bool _sending = false;
  bool _myReacted = false;
  bool _mySaved = false;
  bool _myReposted = false;
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
    await supabase.from('comments').insert({'post_id': widget.postId, 'author_id': userId, 'body': text});
    _commentCtrl.clear();
    await _load();
    setState(() => _sending = false);
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

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Author row
            GestureDetector(
              onTap: () {
                if (author?['id'] != null) context.push('/profile/${author!['id']}');
              },
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.15), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                  child: ClipOval(
                    child: authorAvatar != null && authorAvatar.startsWith('http')
                        ? Image.network(authorAvatar, width: 40, height: 40, fit: BoxFit.cover)
                        : Center(child: Text(name.toString()[0].toUpperCase(), style: TextStyle(color: gold, fontWeight: FontWeight.w700))),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(timeago.format(DateTime.parse(_post!['created_at'])), style: Theme.of(context).textTheme.bodySmall),
                ]),
              ]),
            ),

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
            ..._comments.map((c) {
              final ca = c['author'] as Map<String, dynamic>?;
              final cn = (ca?['is_revealed'] == true && ca?['real_name'] != null) ? ca!['real_name'] : (ca?['voice_name'] ?? 'Anon');
              final caAvatar = ca?['avatar_url'] as String?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  ])),
                ]),
              );
            }),
            if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No comments yet', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13))),
              ),
          ]),
        )),

        // Comment input (only for logged-in users)
        if (isLoggedIn) SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _commentCtrl,
                decoration: InputDecoration(hintText: 'Write a comment...', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).dividerColor)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _sendComment,
                child: CircleAvatar(radius: 20, backgroundColor: gold, child: Icon(LucideIcons.send, size: 16, color: isDark ? IjwiColors.darkBg : IjwiColors.lightBg)),
              ),
            ]),
          ),
        ),
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
