import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;
import '../../../core/supabase.dart';

class LiveRoomScreen extends StatefulWidget {
  final String eventId;
  const LiveRoomScreen({super.key, required this.eventId});
  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String _title = '';
  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() { super.initState(); _load(); _subscribe(); }

  Future<void> _load() async {
    final event = await supabase.from('events').select('title').eq('id', widget.eventId).single();
    final msgs = await supabase.from('live_messages').select('*, author:profiles!live_messages_user_id_fkey(voice_name, real_name, is_revealed)').eq('event_id', widget.eventId).order('created_at').limit(100);
    if (mounted) setState(() { _title = event['title'] ?? ''; _messages = List<Map<String, dynamic>>.from(msgs); });
    _scrollBottom();
  }

  void _subscribe() {
    supabase.channel('live-${widget.eventId}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'live_messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) async {
            final msg = payload.newRecord;
            if (msg['user_id'] == _uid) return;
            final a = await supabase.from('profiles').select('voice_name, real_name, is_revealed').eq('id', msg['user_id']).single();
            if (mounted) setState(() => _messages.add({...msg, 'author': a}));
            _scrollBottom();
          },
        ).subscribe();
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  });

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    final profile = await supabase.from('profiles').select('voice_name, real_name, is_revealed').eq('id', _uid).single();
    setState(() => _messages.add({'user_id': _uid, 'message': text, 'created_at': DateTime.now().toIso8601String(), 'author': profile}));
    _scrollBottom();
    await supabase.from('live_messages').insert({'event_id': widget.eventId, 'user_id': _uid, 'message': text});
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
          const SizedBox(width: 8),
          Expanded(child: Text(_title, overflow: TextOverflow.ellipsis, style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
      ),
      body: Column(children: [
        Expanded(child: _messages.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.mic, size: 40, color: gold),
                const SizedBox(height: 12),
                Text("You're live!", style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Say something to start.', style: Theme.of(context).textTheme.bodySmall),
              ]))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(14),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final a = m['author'] as Map<String, dynamic>?;
                  final name = (a?['is_revealed'] == true && a?['real_name'] != null) ? a!['real_name'] : (a?['voice_name'] ?? 'Anon');
                  final isMine = m['user_id'] == _uid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 14, backgroundColor: gold.withOpacity(0.12), child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 10, color: gold))),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(isMine ? 'You' : name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isMine ? gold : null)),
                          const SizedBox(width: 6),
                          Text(timeago.format(DateTime.parse(m['created_at'])), style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                        ]),
                        const SizedBox(height: 2),
                        Text(m['message'] ?? '', style: GoogleFonts.roboto(fontSize: 14)),
                      ])),
                    ]),
                  );
                },
              ),
        ),
        SafeArea(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(hintText: 'Say something...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            GestureDetector(onTap: _send, child: CircleAvatar(radius: 20, backgroundColor: gold, child: Icon(LucideIcons.send, size: 16, color: Theme.of(context).scaffoldBackgroundColor))),
          ]),
        )),
      ]),
    );
  }
}
