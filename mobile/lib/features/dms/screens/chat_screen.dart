import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ijwi_mobile/core/image_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';

const _bgOptions = [
  {'label': 'Default', 'value': 'default', 'colors': <Color>[]},
  {'label': 'Indigo', 'value': 'indigo', 'colors': [Color(0xFF1a1840), Color(0xFF0f0f28)]},
  {'label': 'Warm', 'value': 'warm', 'colors': [Color(0xFF1a1020), Color(0xFF120808)]},
  {'label': 'Deep', 'value': 'deep', 'colors': [Color(0xFF0a1628), Color(0xFF0f0f28)]},
  {'label': 'Forest', 'value': 'forest', 'colors': [Color(0xFF0f1a10), Color(0xFF0a1628)]},
  {'label': 'Ember', 'value': 'ember', 'colors': [Color(0xFF1a1010), Color(0xFF0f0c1e)]},
  {'label': 'Sage', 'value': 'sage', 'colors': [Color(0xFF0e1a10), Color(0xFF101810)]},
  {'label': 'Midnight', 'value': 'midnight', 'colors': [Color(0xFF0C0916), Color(0xFF1a1a2e)]},
];

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  const ChatScreen({super.key, required this.otherUserId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _other;
  bool _sending = false;
  bool _isArchived = false;
  String _chatBg = 'default';
  final Map<String, Map<String, dynamic>> _postCache = {};
  final Map<String, Map<String, dynamic>> _eventCache = {};
  Map<String, dynamic>? _replyingTo;

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() { super.initState(); _load(); _subscribe(); _checkArchived(); _loadBg(); }

  @override
  void dispose() {
    supabase.removeChannel(supabase.channel('dm-recv-$_uid-${widget.otherUserId}'));
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadBg() async {
    final prefs = await SharedPreferences.getInstance();
    final bg = prefs.getString('ijwi_chat_bg_${widget.otherUserId}') ?? 'default';
    if (mounted) setState(() => _chatBg = bg);
  }

  Future<void> _setBg(String value) async {
    setState(() => _chatBg = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ijwi_chat_bg_${widget.otherUserId}', value);
  }

  Future<void> _checkArchived() async {
    final prefs = await SharedPreferences.getInstance();
    final archived = prefs.getStringList('ijwi_archived_chats') ?? [];
    if (mounted) setState(() => _isArchived = archived.contains(widget.otherUserId));
  }

  Future<void> _load() async {
    final other = await supabase.from('profiles').select('id, voice_name, real_name, is_revealed, avatar_url, bio, voice_role').eq('id', widget.otherUserId).single();
    final res = await supabase.from('direct_messages').select('*')
        .or('and(sender_id.eq.$_uid,receiver_id.eq.${widget.otherUserId}),and(sender_id.eq.${widget.otherUserId},receiver_id.eq.$_uid)')
        .order('created_at', ascending: true);
    if (mounted) setState(() { _other = other; _messages = List<Map<String, dynamic>>.from(res); });
    await _preloadPosts();
    await _preloadEvents();
    if (mounted && _messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    await supabase.from('direct_messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('receiver_id', _uid)
        .eq('sender_id', widget.otherUserId)
        .isFilter('read_at', null);
  }

  Future<void> _preloadPosts() async {
    final postIds = <String>[];
    for (final m in _messages) {
      final id = _extractPostId(m['message'] ?? '');
      if (id != null && !_postCache.containsKey(id)) postIds.add(id);
    }
    if (postIds.isEmpty) return;
    final posts = await supabase.from('posts').select('id, title, body, content_type, video_url, author:profiles!posts_author_id_fkey(voice_name, is_revealed, real_name)').inFilter('id', postIds);
    for (final p in posts) {
      _postCache[p['id']] = Map<String, dynamic>.from(p);
    }
    if (mounted) setState(() {});
  }

  Future<void> _preloadEvents() async {
    final eventIds = <String>[];
    for (final m in _messages) {
      final id = _extractEventId(m['message'] ?? '');
      if (id != null && !_eventCache.containsKey(id)) eventIds.add(id);
    }
    if (eventIds.isEmpty) return;
    final events = await supabase.from('events').select('id, title, cover_image_url, start_time').inFilter('id', eventIds);
    for (final e in events) {
      _eventCache[e['id']] = Map<String, dynamic>.from(e);
    }
    if (mounted) setState(() {});
  }

  String? _extractPostId(String msg) {
    final match = RegExp(r'^\[post:([a-f0-9\-]+)\]$').firstMatch(msg.trim());
    return match?.group(1);
  }

  String? _extractProfileId(String msg) {
    final match = RegExp(r'^\[profile:([a-f0-9\-]+)\]$').firstMatch(msg.trim());
    return match?.group(1);
  }

  String? _extractEventId(String msg) {
    final match = RegExp(r'^\[event:([a-f0-9\-]+)\]$').firstMatch(msg.trim());
    return match?.group(1);
  }

  bool _isImageUrl(String msg) {
    final lower = msg.trim().toLowerCase();
    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.contains('/storage/v1/object/'));
  }

  bool _isVideoUrl(String msg) {
    final lower = msg.trim().toLowerCase();
    return (lower.startsWith('http://') || lower.startsWith('https://')) &&
        (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm'));
  }

  void _subscribe() {
    // Listen for new messages (incoming)
    supabase.channel('dm-recv-$_uid-${widget.otherUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, schema: 'public', table: 'direct_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'receiver_id', value: _uid),
          callback: (payload) {
            final msg = payload.newRecord;
            if (msg.isEmpty) { // If deletion
              final oldId = payload.oldRecord['id'];
              setState(() {
                _messages.removeWhere((m) => m['id'] == oldId);
              });
              return;
            }
            if (msg['sender_id'] == widget.otherUserId) {
              if (payload.eventType == PostgresChangeEvent.insert) {
                setState(() => _messages.add(msg));
                _scrollBottom();
                _markAsRead();
                final postId = _extractPostId(msg['message'] ?? '');
                final eventId = _extractEventId(msg['message'] ?? '');
                if (postId != null && !_postCache.containsKey(postId)) _preloadPosts();
                if (eventId != null && !_eventCache.containsKey(eventId)) _preloadEvents();
                if (mounted) setState(() {});
              } else if (payload.eventType == PostgresChangeEvent.update) {
                setState(() {
                  final idx = _messages.indexWhere((m) => m['id'] == msg['id']);
                  if (idx != -1) _messages[idx] = msg;
                });
              }
            }
          },
        )
        // Listen for read_at updates (when other person reads our messages)
        .onPostgresChanges(
          event: PostgresChangeEvent.update, schema: 'public', table: 'direct_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'sender_id', value: _uid),
          callback: (payload) {
            final updated = payload.newRecord;
            if (updated['receiver_id'] == widget.otherUserId && updated['read_at'] != null) {
              setState(() {
                for (int i = 0; i < _messages.length; i++) {
                  if (_messages[i]['sender_id'] == _uid && _messages[i]['read_at'] == null) {
                    _messages[i]['read_at'] = updated['read_at'];
                  }
                }
              });
            }
          },
        ).subscribe();
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
  });

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final replyId = _replyingTo?['id'];
    setState(() { 
      _messages.add({
        'sender_id': _uid, 
        'receiver_id': widget.otherUserId, 
        'message': text, 
        if (replyId != null) 'reply_to_id': replyId,
        'created_at': DateTime.now().toUtc().toIso8601String(), 
        'id': 'temp'
      }); 
      _ctrl.clear(); 
      _replyingTo = null; 
    });
    _scrollBottom();
    await supabase.from('direct_messages').insert({
      'sender_id': _uid, 
      'receiver_id': widget.otherUserId, 
      'message': text,
      if (replyId != null) 'reply_to_id': replyId
    });
    sendNotification(toUserId: widget.otherUserId, type: 'message', message: 'sent you a message');
    setState(() => _sending = false);
  }

  void _showAttachOptions() {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          ListTile(
            leading: Icon(LucideIcons.image, color: gold),
            title: Text('Image', style: GoogleFonts.poppins(fontSize: 15)),
            subtitle: Text('Send a photo', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            onTap: () { Navigator.pop(ctx); _pickImage(); },
          ),
          ListTile(
            leading: Icon(LucideIcons.file, color: gold),
            title: Text('Document', style: GoogleFonts.poppins(fontSize: 15)),
            subtitle: Text('Send a file', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            onTap: () { Navigator.pop(ctx); _pickDocument(); },
          ),
          ListTile(
            leading: Icon(LucideIcons.user, color: gold),
            title: Text('Profile', style: GoogleFonts.poppins(fontSize: 15)),
            subtitle: Text('Share someone you listen to', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            onTap: () { Navigator.pop(ctx); _pickProfile(); },
          ),
        ]),
      )),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;
    setState(() => _sending = true);
    try {
      var bytes = file.bytes;
      if (file.path != null) {
        final fixedPath = await ImageHelper.compressAndFixRotation(file.path!);
        bytes = await File(fixedPath).readAsBytes();
      } else if (bytes == null) {
        return;
      }
      final ext = file.extension ?? 'jpg';
      final path = 'dm_images/${_uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final url = supabase.storage.from('chat-media').getPublicUrl(path);
      setState(() { _messages.add({'sender_id': _uid, 'receiver_id': widget.otherUserId, 'message': url, 'created_at': DateTime.now().toUtc().toIso8601String(), 'id': 'temp'}); });
      _scrollBottom();
      await supabase.from('direct_messages').insert({'sender_id': _uid, 'receiver_id': widget.otherUserId, 'message': url});
      sendNotification(toUserId: widget.otherUserId, type: 'message', message: 'sent you a photo');
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }


  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await File(file.path!).readAsBytes();
      final ext = file.extension ?? 'file';
      final path = 'dm_docs/${_uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final url = supabase.storage.from('chat-media').getPublicUrl(path);
      setState(() { _messages.add({'sender_id': _uid, 'receiver_id': widget.otherUserId, 'message': url, 'created_at': DateTime.now().toUtc().toIso8601String(), 'id': 'temp'}); });
      _scrollBottom();
      await supabase.from('direct_messages').insert({'sender_id': _uid, 'receiver_id': widget.otherUserId, 'message': url});
      sendNotification(toUserId: widget.otherUserId, type: 'message', message: 'sent you a file');
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _pickProfile() async {
    final uid = _uid;
    final following = await supabase.from('follows').select('following_id').eq('follower_id', uid);
    final ids = following.map<String>((f) => f['following_id'] as String).toList();
    if (ids.isEmpty || !mounted) return;
    final profiles = await supabase.from('profiles').select('id, voice_name, real_name, is_revealed').inFilter('id', ids);
    if (!mounted) return;
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
        Padding(padding: const EdgeInsets.all(16), child: Text('Share a profile', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
        ...profiles.map((p) {
          final name = (p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name'];
          return ListTile(
            leading: CircleAvatar(backgroundColor: gold.withValues(alpha: 0.1), child: Text(name[0].toUpperCase(), style: TextStyle(color: gold, fontWeight: FontWeight.w700))),
            title: Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () async {
              Navigator.pop(ctx);
              final msg = '[profile:${p['id']}]';
              setState(() { _messages.add({'sender_id': _uid, 'receiver_id': widget.otherUserId, 'message': msg, 'created_at': DateTime.now().toUtc().toIso8601String(), 'id': 'temp'}); });
              _scrollBottom();
              await supabase.from('direct_messages').insert({'sender_id': _uid, 'receiver_id': widget.otherUserId, 'message': msg});
              sendNotification(toUserId: widget.otherUserId, type: 'message', message: 'shared a profile with you');
            },
          );
        }),
        const SizedBox(height: 16),
      ])),
    );
  }

  void _showMenu() {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _other != null ? ((_other!['is_revealed'] == true && _other!['real_name'] != null) ? _other!['real_name'] : _other!['voice_name']) : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          ListTile(
            leading: Icon(LucideIcons.user, color: gold),
            title: Text('View profile', style: GoogleFonts.poppins(fontSize: 15)),
            subtitle: Text(name, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            onTap: () { Navigator.pop(ctx); context.push('/profile/${widget.otherUserId}'); },
          ),
          ListTile(
            leading: Icon(LucideIcons.paintbrush, color: gold),
            title: Text('Chat background', style: GoogleFonts.poppins(fontSize: 15)),
            onTap: () { Navigator.pop(ctx); _showBgPicker(); },
          ),
          _isArchived
            ? ListTile(
                leading: Icon(LucideIcons.archive_restore, color: gold),
                title: Text('Unarchive chat', style: GoogleFonts.poppins(fontSize: 15)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  final archived = (prefs.getStringList('ijwi_archived_chats') ?? []).toSet();
                  archived.remove(widget.otherUserId);
                  await prefs.setStringList('ijwi_archived_chats', archived.toList());
                  if (mounted) setState(() => _isArchived = false);
                },
              )
            : ListTile(
                leading: const Icon(LucideIcons.archive, color: Colors.redAccent),
                title: Text('Archive chat', style: GoogleFonts.poppins(fontSize: 15, color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  final archived = (prefs.getStringList('ijwi_archived_chats') ?? []).toSet();
                  archived.add(widget.otherUserId);
                  await prefs.setStringList('ijwi_archived_chats', archived.toList());
                  if (mounted) { setState(() => _isArchived = true); Navigator.maybePop(context); }
                },
              ),
          ListTile(
            leading: const Icon(LucideIcons.trash_2, color: Colors.redAccent),
            title: Text('Delete chat', style: GoogleFonts.poppins(fontSize: 15, color: Colors.redAccent)),
            onTap: () { Navigator.pop(ctx); },
          ),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _other != null ? ((_other!['is_revealed'] == true && _other!['real_name'] != null) ? _other!['real_name'] : _other!['voice_name']) : '...';

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => context.push('/profile/${widget.otherUserId}'),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: gold.withValues(alpha: 0.12), child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              Row(children: [Icon(LucideIcons.lock, size: 9, color: Colors.green), const SizedBox(width: 3), Text('Encrypted', style: TextStyle(fontSize: 10, color: Colors.green))]),
            ]),
          ]),
        ),
        actions: [
          IconButton(icon: Icon(LucideIcons.ellipsis_vertical, size: 20), onPressed: _showMenu),
        ],
      ),
      body: Column(children: [
        Expanded(child: Container(
          decoration: _chatBgDecoration(),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final showDaySeparator = _shouldShowDaySeparator(i);
              return Column(
                children: [
                  if (showDaySeparator) _buildDayLabel(_messages[i]),
                  _buildMessage(_messages[i], gold, isDark),
                ],
              );
            },
          ),
        )),
        SafeArea(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                child: Row(children: [
                  Icon(LucideIcons.reply, size: 16, color: Theme.of(context).hintColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_replyingTo!['message']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
                  GestureDetector(onTap: () => setState(() => _replyingTo = null), child: Icon(LucideIcons.x, size: 16, color: Theme.of(context).hintColor)),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
              child: Row(children: [
                GestureDetector(
              onTap: _showAttachOptions,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2),
                child: Icon(LucideIcons.paperclip, size: 18, color: Theme.of(context).hintColor),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(hintText: 'Message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Theme.of(context).dividerColor)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              maxLines: 3, minLines: 1, textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: CircleAvatar(radius: 20, backgroundColor: gold, child: Icon(LucideIcons.send, size: 16, color: const Color(0xFF1A1814))),
            ),
          ]),
        ),
      ],
    )),
      ]),
    );
  }

  BoxDecoration _chatBgDecoration() {
    final option = _bgOptions.firstWhere((o) => o['value'] == _chatBg, orElse: () => _bgOptions[0]);
    final colors = option['colors'] as List<Color>;
    if (colors.isEmpty) return const BoxDecoration();
    return BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors));
  }

  void _showBgPicker() {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Text('Chat Background', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: _bgOptions.map((opt) {
            final value = opt['value'] as String;
            final label = opt['label'] as String;
            final colors = opt['colors'] as List<Color>;
            final isSelected = _chatBg == value;
            return GestureDetector(
              onTap: () { _setBg(value); Navigator.pop(ctx); },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? gold : Colors.transparent, width: 2.5),
                    gradient: colors.isNotEmpty ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors) : null,
                    color: colors.isEmpty ? (isDark ? IjwiColors.darkBg : IjwiColors.lightBg) : null,
                  ),
                  child: isSelected ? Center(child: Icon(LucideIcons.check, size: 18, color: gold)) : null,
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 10, color: isSelected ? gold : Theme.of(context).hintColor, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
              ]),
            );
          }).toList()),
        ]),
      )),
    );
  }

  bool _shouldShowDaySeparator(int index) {
    if (index == 0) return true;
    final curr = DateTime.tryParse(_messages[index]['created_at']?.toString() ?? '')?.toLocal();
    final prev = DateTime.tryParse(_messages[index - 1]['created_at']?.toString() ?? '')?.toLocal();
    if (curr == null || prev == null) return false;
    return curr.year != prev.year || curr.month != prev.month || curr.day != prev.day;
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildDayLabel(Map<String, dynamic> m) {
    final date = DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal();
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).hintColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _dayLabel(date),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).hintColor),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> m, Color gold, bool isDark) {
    final isMine = m['sender_id'] == _uid;
    final msg = (m['message'] ?? '').toString();
    final isDeleted = m['deleted'] == true || (m['message'] ?? '').toString() == '[deleted]';
    final postId = _extractPostId(msg);
    final eventId = _extractEventId(msg);
    final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal();
    final timeStr = createdAt != null ? DateFormat('HH:mm').format(createdAt) : '';
    final readAt = m['read_at'];
    final status = isMine ? (readAt != null ? 'Seen' : 'Unread') : null;

    Widget content;
    if (isDeleted) {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.ban, size: 13, color: Theme.of(context).hintColor),
        const SizedBox(width: 6),
        Text('This message was deleted', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Theme.of(context).hintColor)),
      ]);
    } else if (eventId != null) {
      content = _buildEventCard(eventId, gold, isDark);
    } else if (postId != null) {
      content = _buildPostPreview(postId, gold, isDark);
    } else if (_extractProfileId(msg) != null) {
      content = _buildProfileCard(_extractProfileId(msg)!, gold, isDark);
    } else if (m['action_type'] != null) {
      content = _buildActionBubble(m, gold, isDark);
    } else if (_isImageUrl(msg)) {
      content = _buildImageBubble(msg);
    } else if (_isVideoUrl(msg)) {
      content = _buildVideoBubble(msg);
    } else {
      content = Text(msg, style: TextStyle(fontSize: 14, color: isMine ? const Color(0xFF1A1814) : null));
    }

    Widget messageBody = content;
    final replyId = m['reply_to_id'];
    if (replyId != null && !isDeleted) {
      final repliedMsg = _messages.cast<Map<String, dynamic>?>().firstWhere((e) => e?['id'] == replyId, orElse: () => null);
      if (repliedMsg != null) {
        final rMsg = (repliedMsg['message'] ?? '').toString();
        messageBody = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isMine ? Colors.black12 : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: isMine ? const Color(0xFF1A1814) : gold, width: 3)),
              ),
              child: Text(rMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: isMine ? const Color(0xFF1A1814).withValues(alpha: 0.7) : Theme.of(context).hintColor)),
            ),
            content,
          ],
        );
      }
    }

    return Dismissible(
      key: Key(m['id']?.toString() ?? UniqueKey().toString()),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.2,
        DismissDirection.endToStart: 0.2,
      },
      confirmDismiss: (direction) async {
        if (!isDeleted) {
          HapticFeedback.lightImpact();
          setState(() => _replyingTo = m);
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: Icon(LucideIcons.reply, color: Theme.of(context).hintColor, size: 20),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(LucideIcons.reply, color: Theme.of(context).hintColor, size: 20),
      ),
      child: GestureDetector(
        onLongPress: isDeleted ? null : () => _showMessageOptions(m, isMine),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: (postId != null || _isImageUrl(msg) || _isVideoUrl(msg)) && !isDeleted ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  color: isDeleted ? Colors.transparent : (isMine ? gold : (isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 18),
                  ),
                  border: isDeleted ? Border.all(color: Theme.of(context).dividerColor) : (isMine ? null : Border.all(color: isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2)),
                ),
                child: messageBody,
              ),
              if (!isDeleted && (m['reactions'] as Map<String, dynamic>? ?? {}).isNotEmpty)
                Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2, bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? IjwiColors.darkBg2 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...((m['reactions'] as Map<String, dynamic>).values.toSet().take(3).map((e) => Text(e.toString(), style: const TextStyle(fontSize: 12)))),
                        if ((m['reactions'] as Map<String, dynamic>).length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text((m['reactions'] as Map<String, dynamic>).length.toString(), style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                ),
              if (!isDeleted) Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Text(timeStr, style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                  if (status != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        color: status == 'Seen' ? gold : Theme.of(context).hintColor,
                        fontWeight: status == 'Seen' ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    ));
  }

  Future<void> _toggleReaction(Map<String, dynamic> m, String emoji) async {
    final msgId = m['id'];
    if (msgId == null || msgId == 'temp') return;
    
    final currentReactions = Map<String, dynamic>.from(m['reactions'] as Map<String, dynamic>? ?? {});
    if (currentReactions[_uid] == emoji) {
      currentReactions.remove(_uid);
    } else {
      currentReactions[_uid] = emoji;
    }
    
    setState(() {
      final idx = _messages.indexWhere((msg) => msg['id'] == msgId);
      if (idx != -1) {
        _messages[idx]['reactions'] = currentReactions;
      }
    });
    
    await supabase.from('direct_messages').update({'reactions': currentReactions}).eq('id', msgId);
  }

  void _showMessageOptions(Map<String, dynamic> m, bool isMine) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          
          if (!m.containsKey('deleted') || m['deleted'] != true) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                final hasReacted = (m['reactions'] as Map<String, dynamic>? ?? {})[_uid] == emoji;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleReaction(m, emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasReacted ? gold.withValues(alpha: 0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!m.containsKey('deleted') || m['deleted'] != true) const Divider(),
          
          ListTile(
            leading: Icon(LucideIcons.reply, color: gold),
            title: Text('Reply', style: GoogleFonts.poppins(fontSize: 15)),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _replyingTo = m);
            },
          ),
          if (isMine) ListTile(
            leading: Icon(LucideIcons.trash_2, color: Colors.redAccent),
            title: Text('Delete message', style: GoogleFonts.poppins(fontSize: 15, color: Colors.redAccent)),
            subtitle: Text('This message will be deleted for everyone', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                final idx = _messages.indexOf(m);
                if (idx != -1) {
                  _messages[idx]['deleted'] = true;
                  _messages[idx]['message'] = '[deleted]';
                }
              });
              if (m['id'] != null && m['id'] != 'temp') {
                supabase.from('direct_messages').update({'message': '[deleted]', 'deleted': true}).eq('id', m['id']).then((_) {});
              }
            },
          ),
        ]),
      )),
    );
  }


  Widget _buildProfileCard(String profileId, Color gold, bool isDark) {
    return FutureBuilder(
      future: supabase.from('profiles').select('id, voice_name, real_name, is_revealed').eq('id', profileId).maybeSingle(),
      builder: (context, snapshot) {
        final p = snapshot.data;
        if (p == null) return const SizedBox(width: 150, height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        final name = (p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name'];
        return GestureDetector(
          onTap: () => context.push('/profile/$profileId'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withValues(alpha: 0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)), child: Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w700, color: gold)))),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('View profile', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w500)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEventCard(String eventId, Color gold, bool isDark) {
    final event = _eventCache[eventId];
    if (event == null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
          const SizedBox(width: 8),
          Text('Loading event...', style: TextStyle(fontSize: 12, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
        ]),
      );
    }

    final title = event['title'] ?? 'Ijwi Event';
    final cover = event['cover_image_url'] as String?;
    final date = DateTime.tryParse(event['start_time']?.toString() ?? '')?.toLocal();

    return GestureDetector(
      onTap: () => context.push('/events/$eventId'),
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (cover != null && cover.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(cover, width: double.infinity, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Icon(LucideIcons.image)))),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (date != null) ...[
                const SizedBox(height: 4),
                Text(DateFormat('MMM d, yyyy • h:mm a').format(date), style: TextStyle(fontSize: 11, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                const Spacer(),
                Text('View Event', style: TextStyle(fontSize: 10, color: gold, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(LucideIcons.arrow_right, size: 10, color: gold),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPostPreview(String postId, Color gold, bool isDark) {
    final post = _postCache[postId];
    if (post == null) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
          const SizedBox(width: 8),
          Text('Loading post...', style: TextStyle(fontSize: 12, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
        ]),
      );
    }

    final author = post['author'] as Map<String, dynamic>?;
    final authorName = (author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous');
    final title = post['title'] ?? '';
    final body = post['body'] ?? '';
    final type = (post['content_type'] ?? 'story').toString().replaceAll('_', ' ');

    return GestureDetector(
      onTap: () => context.push('/post/$postId'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(LucideIcons.file_text, size: 14, color: gold),
            const SizedBox(width: 6),
            Expanded(child: Text(authorName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: gold)),
            ),
          ]),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body, style: TextStyle(fontSize: 12, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Row(children: [
            const Spacer(),
            Text('Tap to view', style: TextStyle(fontSize: 10, color: gold, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(LucideIcons.arrow_right, size: 10, color: gold),
          ]),
        ]),
      ),
    );
  }

  Widget _buildActionBubble(Map<String, dynamic> m, Color gold, bool isDark) {
    final actionType = m['action_type'] as String?;
    final isMine = m['sender_id'] == _uid;
    final payload = m['action_payload'] as Map<String, dynamic>? ?? {};

    String title = 'Invitation';
    String desc = m['message']?.toString() ?? '';
    
    if (actionType == 'invite_live') {
      title = 'Live Stream Invite';
    } else if (actionType == 'invite_event_admin') {
      title = 'Event Admin Invite';
    } else if (actionType == 'invite_event_usher') {
      title = 'Event Usher Invite';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? IjwiColors.darkBg2.withValues(alpha: 0.5) : IjwiColors.lightBg2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.mail_open, size: 16, color: gold),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isMine ? const Color(0xFF1A1814) : null)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 13, color: isMine ? const Color(0xFF1A1814).withValues(alpha: 0.9) : (isDark ? IjwiColors.darkText2 : IjwiColors.lightText2))),
          const SizedBox(height: 12),
          if (!isMine)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleActionAccept(m),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: const Color(0xFF1A1814),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text('Accept', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          if (isMine)
            Text('Awaiting response...', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF1A1814).withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Future<void> _handleActionAccept(Map<String, dynamic> m) async {
    final actionType = m['action_type'] as String?;
    final payload = m['action_payload'] as Map<String, dynamic>? ?? {};
    
    try {
      if (actionType == 'invite_live') {
        final streamId = payload['stream_id'];
        final eventId = payload['event_id'];
        if (streamId == null) return;
        
        // Accept the request by inserting/updating livestream_participants
        await supabase.from('livestream_participants').upsert({
          'stream_id': streamId,
          'user_id': _uid,
          'role': 'co_host',
          'joined_at': DateTime.now().toIso8601String(),
        });
        
        // Delete the action message or mark it accepted (updating payload)
        await supabase.from('direct_messages').update({
          'action_type': 'invite_live_accepted',
          'message': 'You accepted the live stream invite.',
        }).eq('id', m['id']);
        
        if (mounted && eventId != null) {
          context.push('/events/$eventId/live');
        }
      } else if (actionType == 'invite_event_admin' || actionType == 'invite_event_usher') {
        final eventId = payload['event_id'];
        if (eventId == null) return;
        final role = actionType == 'invite_event_admin' ? 'admin' : 'usher';
        
        await supabase.from('event_collaborators').upsert({
          'event_id': eventId,
          'user_id': _uid,
          'role': role,
        });
        
        await supabase.from('direct_messages').update({
          'action_type': '${actionType}_accepted',
          'message': 'You are now an $role for this event.',
        }).eq('id', m['id']);
      }
    } catch (e) {
      debugPrint('Error accepting action: $e');
    }
  }

  Widget _buildImageBubble(String url) {
    return GestureDetector(
      onTap: () => _openFullscreenMedia(context, url: url, isVideo: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 220,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(width: 220, height: 160, color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, __, ___) => Container(width: 220, height: 80, color: Colors.black12, child: const Icon(LucideIcons.image_off, size: 24)),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(String url) {
    return GestureDetector(
      onTap: () => _openFullscreenMedia(context, url: url, isVideo: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 220, height: 160,
          color: Colors.black,
          child: Stack(alignment: Alignment.center, children: [
            const Icon(LucideIcons.play, color: Colors.white, size: 36),
            Positioned(bottom: 8, left: 8, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
              child: const Text('Video', style: TextStyle(color: Colors.white, fontSize: 10)),
            )),
          ]),
        ),
      ),
    );
  }

  void _openFullscreenMedia(BuildContext context, {required String url, required bool isVideo}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullscreenMediaView(url: url, isVideo: isVideo),
    ));
  }
}

class _FullscreenMediaView extends StatefulWidget {
  final String url;
  final bool isVideo;
  const _FullscreenMediaView({required this.url, required this.isVideo});
  @override
  State<_FullscreenMediaView> createState() => _FullscreenMediaViewState();
}

class _FullscreenMediaViewState extends State<_FullscreenMediaView> {
  VideoPlayerController? _videoCtrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() => _initialized = true);
          _videoCtrl!.play();
        });
    }
  }

  @override
  void dispose() { _videoCtrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: widget.isVideo
              ? (_initialized
                  ? AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: VideoPlayer(_videoCtrl!))
                  : const CircularProgressIndicator(color: Colors.white))
              : InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.contain),
                ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
              child: const Icon(LucideIcons.x, color: Colors.white, size: 20),
            ),
          ),
        ),
        if (widget.isVideo && _initialized)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0, right: 0,
            child: Center(child: GestureDetector(
              onTap: () => setState(() { _videoCtrl!.value.isPlaying ? _videoCtrl!.pause() : _videoCtrl!.play(); }),
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                child: Icon(_videoCtrl!.value.isPlaying ? LucideIcons.pause : LucideIcons.play, color: Colors.white, size: 28),
              ),
            )),
          ),
      ]),
    );
  }
}
