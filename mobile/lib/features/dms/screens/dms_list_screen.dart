import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class DmsListScreen extends StatefulWidget {
  const DmsListScreen({super.key});
  @override
  State<DmsListScreen> createState() => _DmsListScreenState();
}

class _DmsListScreenState extends State<DmsListScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _conversations = [];
  Set<String> _archivedIds = {};
  bool _loading = true;
  final _search = TextEditingController();
  String _filter = 'all'; // all, unread, archived

  @override
  void initState() { super.initState(); _loadArchived().then((_) => _load()); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadArchived().then((_) { if (mounted) setState(() {}); });
  }

  Future<void> _loadArchived() async {
    final prefs = await SharedPreferences.getInstance();
    _archivedIds = (prefs.getStringList('ijwi_archived_chats') ?? []).toSet();
  }

  Future<void> _saveArchived() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ijwi_archived_chats', _archivedIds.toList());
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final messages = await supabase.from('direct_messages')
          .select('sender_id, receiver_id, message, created_at, read_at')
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .order('created_at', ascending: false);
      final Map<String, Map<String, dynamic>> convMap = {};
      for (final m in messages) {
        final otherId = m['sender_id'] == uid ? m['receiver_id'] : m['sender_id'];
        if (!convMap.containsKey(otherId)) convMap[otherId as String] = m;
      }
      if (convMap.isEmpty) { if (mounted) setState(() => _loading = false); return; }
      final profiles = await supabase.from('profiles')
          .select('id, voice_name, real_name, is_revealed, avatar_url')
          .inFilter('id', convMap.keys.toList());
      final uid2 = supabase.auth.currentUser!.id;
      final convs = profiles.map((p) {
        final conv = convMap[p['id']]!;
        final isUnread = conv['read_at'] == null && conv['sender_id'] != uid2;
        return {...p, 'last_message': conv['message'], 'last_at': conv['created_at'], 'unread': isUnread};
      }).toList();
      convs.sort((a, b) => (b['last_at'] as String).compareTo(a['last_at'] as String));
      if (mounted) setState(() { _conversations = List<Map<String, dynamic>>.from(convs); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleArchive(String id) {
    setState(() {
      if (_archivedIds.contains(id)) { _archivedIds.remove(id); } else { _archivedIds.add(id); }
    });
    _saveArchived();
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _conversations;
    final q = _search.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((c) => _getName(c).toLowerCase().contains(q)).toList();
    }
    switch (_filter) {
      case 'unread': return list.where((c) => c['unread'] == true && !_archivedIds.contains(c['id'])).toList();
      case 'archived': return list.where((c) => _archivedIds.contains(c['id'])).toList();
      default: return list.where((c) => !_archivedIds.contains(c['id'])).toList();
    }
  }

  String _getName(Map<String, dynamic> c) =>
      (c['is_revealed'] == true && c['real_name'] != null) ? c['real_name'] : c['voice_name'];

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
          child: Row(children: [
            Text('Messages', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showNewMessage(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.3))),
                child: Icon(LucideIcons.square_pen, size: 18, color: gold),
              ),
            ),
          ]),
        ),

        // Filter tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            _FilterTab(label: 'All', active: _filter == 'all', gold: gold, onTap: () => setState(() => _filter = 'all')),
            _FilterTab(label: 'Unread', active: _filter == 'unread', gold: gold, onTap: () => setState(() => _filter = 'unread')),
            _FilterTab(label: 'Archived', active: _filter == 'archived', gold: gold, onTap: () => setState(() => _filter = 'archived')),
          ]),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(hintText: 'Search', prefixIcon: Icon(LucideIcons.search, size: 16, color: text3), isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Conversations
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_filter == 'archived' ? LucideIcons.archive : LucideIcons.message_circle, size: 48, color: text3),
                      const SizedBox(height: 12),
                      Text(_filter == 'archived' ? 'No archived chats' : _filter == 'unread' ? 'All caught up' : 'No messages yet', style: GoogleFonts.fraunces(fontSize: 18)),
                    ]))
                  : RefreshIndicator(
                      color: gold,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          final name = _getName(c);
                          final isUnread = c['unread'] == true;
                          final isArchived = _archivedIds.contains(c['id']);
                          return Dismissible(
                            key: ValueKey(c['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: isArchived ? Colors.green.withValues(alpha: 0.1) : gold.withValues(alpha: 0.1),
                              child: Icon(isArchived ? LucideIcons.archive_restore : LucideIcons.archive, color: isArchived ? Colors.green : gold),
                            ),
                            confirmDismiss: (_) async { _toggleArchive(c['id']); return false; },
                            child: InkWell(
                              onTap: () => context.push('/dms/${c['id']}'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(children: [
                                  Stack(children: [
                                    Container(
                                      width: 52, height: 52,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                                      alignment: Alignment.center,
                                      child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: gold)),
                                    ),
                                    if (isUnread) Positioned(bottom: 2, right: 2, child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: gold, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5)))),
                                  ]),
                                  const SizedBox(width: 14),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                      Text(timeago.format(DateTime.parse(c['last_at']), locale: 'en_short'), style: TextStyle(fontSize: 12, color: text3)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(c['last_message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: text3, fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400)),
                                  ])),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  void _showNewMessage(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _NewMessageSheet(gold: gold, bg: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface, text3: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color gold;
  final VoidCallback onTap;
  const _FilterTab({required this.label, required this.active, required this.gold, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? gold : (isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2), width: 0.5),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: active ? Colors.white : Theme.of(context).hintColor)),
      ),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  final Color gold, bg, text3;
  const _NewMessageSheet({required this.gold, required this.bg, required this.text3});
  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _loadPeople(); }

  Future<void> _loadPeople() async {
    final uid = supabase.auth.currentUser!.id;
    final followingRes = await supabase.from('follows').select('following_id').eq('follower_id', uid);
    final followerRes = await supabase.from('follows').select('follower_id').eq('following_id', uid);
    final ids = <String>{};
    for (final r in followingRes) ids.add(r['following_id'] as String);
    for (final r in followerRes) ids.add(r['follower_id'] as String);
    ids.remove(uid);
    if (ids.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    final profiles = await supabase.from('profiles').select('id, voice_name, real_name, is_revealed, avatar_url').inFilter('id', ids.toList()).order('voice_name');
    if (mounted) setState(() { _people = List<Map<String, dynamic>>.from(profiles); _filtered = _people; _loading = false; });
  }

  void _onSearch(String q) {
    if (q.trim().isEmpty) { setState(() => _filtered = _people); return; }
    setState(() => _filtered = _people.where((p) {
      final name = ((p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name']).toString().toLowerCase();
      return name.contains(q.toLowerCase());
    }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.92,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(color: widget.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: widget.text3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 12), child: Row(children: [
            Text('New message', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(LucideIcons.x, size: 20, color: widget.text3)),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _search, autofocus: true, decoration: InputDecoration(hintText: 'Search people...', prefixIcon: Icon(LucideIcons.search, size: 16, color: widget.text3), isDense: true), onChanged: _onSearch)),
          const SizedBox(height: 8),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text(_search.text.trim().isNotEmpty ? 'No results' : 'No followers yet', style: TextStyle(fontSize: 14, color: widget.text3)))
                  : ListView.builder(controller: scroll, padding: const EdgeInsets.only(bottom: 20), itemCount: _filtered.length, itemBuilder: (_, i) {
                      final p = _filtered[i];
                      final name = (p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name'];
                      return InkWell(
                        onTap: () { Navigator.pop(context); context.push('/dms/${p['id']}'); },
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Row(children: [
                          Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold.withValues(alpha: 0.1), border: Border.all(color: widget.gold.withValues(alpha: 0.2), width: 1.5)), alignment: Alignment.center, child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: widget.gold))),
                          const SizedBox(width: 14),
                          Expanded(child: Text(name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600))),
                          Icon(LucideIcons.chevron_right, size: 16, color: widget.text3),
                        ])),
                      );
                    })),
        ]),
      ),
    );
  }
}
