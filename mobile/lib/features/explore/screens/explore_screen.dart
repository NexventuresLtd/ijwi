import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

const _tags = ['faith', 'testimony', 'healing', 'prayer', 'devotional', 'africa', 'youth', 'hope', 'grace', 'worship', 'scripture', 'revival'];

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _trending = [];
  List<Map<String, dynamic>> _userResults = [];
  List<Map<String, dynamic>> _postResults = [];
  bool _loadingTrending = true;
  bool _searching = false;
  String _resultFilter = 'all';

  @override
  void initState() { super.initState(); _loadTrending(); }

  Future<void> _loadTrending() async {
    try {
      final res = await supabase.from('posts')
          .select('id, title, body, content_type, comment_count, reaction_healed, reaction_amen, author:profiles!posts_author_id_fkey(id, voice_name, is_revealed, real_name, avatar_url)')
          .or('status.eq.published,status.is.null')
          .order('reaction_healed', ascending: false)
          .limit(5);
      if (mounted) setState(() { _trending = List<Map<String, dynamic>>.from(res); _loadingTrending = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTrending = false);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() { _userResults = []; _postResults = []; _searching = false; }); return; }
    setState(() => _searching = true);
    try {
      final users = await supabase.from('profiles').select('id, voice_name, real_name, avatar_url, is_revealed').ilike('voice_name', '%$q%').limit(8);
      final posts = await supabase.from('posts')
          .select('id, title, body, content_type, comment_count, reaction_healed, author:profiles!posts_author_id_fkey(id, voice_name, is_revealed, real_name)')
          .or('title.ilike.%$q%,body.ilike.%$q%')
          .order('created_at', ascending: false).limit(10);
      if (mounted) setState(() { _userResults = List<Map<String, dynamic>>.from(users); _postResults = List<Map<String, dynamic>>.from(posts); _searching = false; });
    } catch (_) { if (mounted) setState(() => _searching = false); }
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('Explore', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _searchCtrl, autofocus: true,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_userResults.isEmpty && _postResults.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.search_x, size: 40, color: Theme.of(context).hintColor),
        const SizedBox(height: 12),
        Text('No results for "${_searchCtrl.text}"', style: Theme.of(context).textTheme.bodyMedium),
      ]));
    }

    final filteredPosts = _resultFilter == 'all' ? _postResults
        : _resultFilter == 'voices' ? _postResults.where((p) => p['content_type'] != 'short' && p['content_type'] != 'question').toList()
        : _postResults.where((p) => p['content_type'] == _resultFilter).toList();

    return Column(children: [
      // Filter tabs
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _FilterChip(label: 'All', active: _resultFilter == 'all', gold: gold, onTap: () => setState(() => _resultFilter = 'all')),
          _FilterChip(label: 'Voices', active: _resultFilter == 'voices', gold: gold, onTap: () => setState(() => _resultFilter = 'voices')),
          _FilterChip(label: 'Questions', active: _resultFilter == 'question', gold: gold, onTap: () => setState(() => _resultFilter = 'question')),
          _FilterChip(label: 'Sparks', active: _resultFilter == 'short', gold: gold, onTap: () => setState(() => _resultFilter = 'short')),
        ])),
      ),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        if (_userResults.isNotEmpty && _resultFilter == 'all') ...[
          _label('People'),
          ..._userResults.map((u) {
            final name = (u['is_revealed'] == true && u['real_name'] != null) ? u['real_name'] : u['voice_name'];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 22, backgroundColor: gold.withValues(alpha: 0.12), child: Text(name.toString()[0].toUpperCase(), style: TextStyle(color: gold, fontWeight: FontWeight.w700))),
              title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
              trailing: Icon(LucideIcons.chevron_right, size: 16, color: Theme.of(context).hintColor),
              onTap: () => context.push('/profile/${u['id']}'),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (filteredPosts.isNotEmpty) ...[
          _label('Posts'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
            itemCount: filteredPosts.length,
            itemBuilder: (_, i) {
              final p = filteredPosts[i];
              final type = (p['content_type'] ?? 'story').toString();
              final gradients = {
                'story': [const Color(0xFF2D1B69), const Color(0xFF11998e)],
                'devotional': [const Color(0xFF1a1a2e), const Color(0xFFb8860b)],
                'spoken_word': [const Color(0xFF200122), const Color(0xFF6f0000)],
                'prayer_request': [const Color(0xFF0f2027), const Color(0xFF2c5364)],
                'question': [const Color(0xFF1f1c2c), const Color(0xFF928DAB)],
                'essay': [const Color(0xFF1a1840), const Color(0xFF0f0f28)],
              };
              final colors = gradients[type] ?? gradients['story']!;
              return GestureDetector(
                onTap: () => context.push('/post/${p['id']}'),
                child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
                  child: Stack(children: [
                    Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)])))),
                    Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(3)), child: Text(type.replaceAll('_', ' '), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.white70)))),
                    Positioned(bottom: 4, left: 4, right: 4, child: Text(p['title'] ?? p['body'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            },
          ),
        ],
      ])),
    ]);
  }

  Widget _buildBrowse(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      // Top 5 Trending
      _label('Top Anointed'),
      if (_loadingTrending)
        const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
      else
        ...List.generate(_trending.length, (i) => _TrendingTile(index: i, post: _trending[i])),

      const SizedBox(height: 28),
      _label('Browse topics'),
      Wrap(spacing: 8, runSpacing: 8, children: _tags.map((t) => ActionChip(
        label: Text('#$t', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: gold)),
        backgroundColor: gold.withValues(alpha: 0.08),
        side: BorderSide(color: gold.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        onPressed: () { _searchCtrl.text = t; _search(t); setState(() {}); },
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
          _TypeTile(icon: LucideIcons.video, label: 'Sparks', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor),
        ],
      ),
      const SizedBox(height: 40),
    ]);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).hintColor, letterSpacing: 0.8)),
  );
}

class _TrendingTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> post;
  const _TrendingTile({required this.index, required this.post});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = post['author'] as Map<String, dynamic>?;
    final name = (author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous');
    final likes = ((post['reaction_healed'] ?? 0) + (post['reaction_amen'] ?? 0)) as int;
    final comments = (post['comment_count'] ?? 0) as int;

    return GestureDetector(
      onTap: () => context.push('/post/${post['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder, width: 0.5),
        ),
        child: Row(children: [
          // Rank number
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post['title'] ?? (post['body'] ?? '').toString().substring(0, (post['body'] ?? '').toString().length.clamp(0, 60)), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Text(name, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              const SizedBox(width: 10),
              Icon(Icons.favorite, size: 11, color: gold),
              const SizedBox(width: 2),
              Text('$likes', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Icon(LucideIcons.message_circle, size: 11, color: Theme.of(context).hintColor),
              const SizedBox(width: 2),
              Text('$comments', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ]),
          ])),
        ]),
      ),
    );
  }
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
        Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color gold;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.gold, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? gold : (isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2), width: 0.5),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : Theme.of(context).hintColor)),
      ),
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
    final likes = ((post['reaction_healed'] ?? 0) + (post['reaction_amen'] ?? 0)) as int;
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
            Text(post['title'] ?? post['body'] ?? '', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Text(name, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              if (likes > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.favorite, size: 10, color: gold),
                const SizedBox(width: 2),
                Text('$likes', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w500)),
              ],
            ]),
          ])),
          const SizedBox(width: 12),
          Icon(LucideIcons.chevron_right, size: 16, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }
}
