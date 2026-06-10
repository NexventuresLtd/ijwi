import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';

const _tags = ['faith', 'testimony', 'healing', 'prayer', 'devotional', 'africa', 'youth', 'hope', 'grace', 'worship', 'scripture', 'revival'];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _trendingPosts = [];
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _postResults = [];
  bool _loadingTrending = true;
  bool _searching = false;

  @override
  void initState() { super.initState(); _loadTrending(); }

  Future<void> _loadTrending() async {
    final res = await supabase.from('posts')
        .select('id, title, body, content_type, reaction_fire, author:profiles!posts_author_id_fkey(id, voice_name, is_revealed, real_name)')
        .or('status.eq.published,status.is.null')
        .order('reaction_fire', ascending: false)
        .limit(12);
    if (mounted) setState(() { _trendingPosts = List<Map<String, dynamic>>.from(res); _loadingTrending = false; });
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() { _userResults = []; _postResults = []; _searching = false; }); return; }
    setState(() => _searching = true);
    try {
      final users = await supabase.from('profiles')
          .select('id, voice_name, real_name, avatar_url, is_revealed')
          .ilike('voice_name', '%$q%')
          .limit(8);
      final posts = await supabase.from('posts')
          .select('id, title, body, content_type, reaction_fire, author:profiles!posts_author_id_fkey(id, voice_name, is_revealed, real_name)')
          .or('title.ilike.%$q%,body.ilike.%$q%')
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) setState(() { _userResults = List<Map<String, dynamic>>.from(users); _postResults = List<Map<String, dynamic>>.from(posts); _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search people, topics, posts...',
              prefixIcon: Icon(LucideIcons.search, size: 16, color: Theme.of(context).hintColor),
              suffixIcon: _isSearching ? IconButton(icon: Icon(LucideIcons.x, size: 16), onPressed: () { _searchCtrl.clear(); _search(''); setState(() {}); }) : null,
            ),
            onChanged: (q) { _search(q); setState(() {}); },
          ),
        ),
        Expanded(child: _isSearching ? _buildSearchResults(context) : _buildBrowse(context)),
      ]),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_userResults.isEmpty && _postResults.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.search_x, size: 40, color: Theme.of(context).hintColor),
        const SizedBox(height: 12),
        Text('No results for "${_searchCtrl.text}"', style: Theme.of(context).textTheme.bodyMedium),
      ]));
    }
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      if (_userResults.isNotEmpty) ...[
        _label('People'),
        ..._userResults.map((u) {
          final name = (u['is_revealed'] == true && u['real_name'] != null) ? u['real_name'] : u['voice_name'];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 22, backgroundColor: gold.withValues(alpha: 0.12), child: Text(name.toString()[0].toUpperCase(), style: TextStyle(color: gold, fontWeight: FontWeight.w700))),
            title: Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15)),
            trailing: Icon(LucideIcons.chevron_right, size: 16, color: Theme.of(context).hintColor),
            onTap: () => context.push('/profile/${u['id']}'),
          );
        }),
        const SizedBox(height: 16),
      ],
      if (_postResults.isNotEmpty) ...[
        _label('Posts'),
        ..._postResults.map((p) => _PostTile(post: p)),
      ],
    ]);
  }

  Widget _buildBrowse(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      _label('Browse topics'),
      Wrap(spacing: 8, runSpacing: 8, children: _tags.map((t) => ActionChip(
        label: Text('#$t', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gold)),
        backgroundColor: gold.withValues(alpha: 0.08),
        side: BorderSide(color: gold.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        onPressed: () {
          _searchCtrl.text = t;
          _search(t);
          setState(() {});
        },
      )).toList()),
      const SizedBox(height: 28),

      _label('Browse by type'),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1,
        children: [
          _TypeTile(icon: LucideIcons.book_open, label: 'Stories', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
          _TypeTile(icon: LucideIcons.heart, label: 'Devotionals', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
          _TypeTile(icon: LucideIcons.mic, label: 'Spoken Word', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
          _TypeTile(icon: LucideIcons.message_circle, label: 'Questions', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
          _TypeTile(icon: LucideIcons.hand_helping, label: 'Prayer', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
          _TypeTile(icon: LucideIcons.zap, label: 'Sparks', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
        ],
      ),
      const SizedBox(height: 28),

      _label('Most anointed this week'),
      if (_loadingTrending)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
      else
        ..._trendingPosts.map((p) => _PostTile(post: p)),
      const SizedBox(height: 40),
    ]);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).hintColor, letterSpacing: 0.8)),
  );
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gold, cardColor, borderColor;
  const _TypeTile({required this.icon, required this.label, required this.gold, required this.cardColor, required this.borderColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 24, color: gold),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostTile({required this.post});
  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final author = post['author'] as Map<String, dynamic>?;
    final name = (author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous');
    final fire = post['reaction_fire'] ?? 0;
    return InkWell(
      onTap: () => context.push('/post/${post['id']}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text((post['content_type'] ?? 'story').toString().replaceAll('_', ' '), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: gold)),
            ),
            const SizedBox(height: 6),
            Text(post['title'] ?? post['body'] ?? '', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Text(name, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              const SizedBox(width: 8),
              Icon(LucideIcons.zap, size: 10, color: gold),
              const SizedBox(width: 2),
              Text('$fire', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w600)),
            ]),
          ])),
          const SizedBox(width: 12),
          Icon(LucideIcons.chevron_right, size: 16, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }
}
