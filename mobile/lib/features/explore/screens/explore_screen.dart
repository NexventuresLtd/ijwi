import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

const _tags = ['faith', 'testimony', 'healing', 'prayer', 'devotional', 'africa', 'youth', 'hope', 'grace', 'worship', 'scripture', 'revival'];

class ExploreScreen extends StatefulWidget {
  final String? initialQuery;
  const ExploreScreen({super.key, this.initialQuery});
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
  void initState() {
    super.initState();
    _loadTrending();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!;
      _search(widget.initialQuery!);
    }
  }

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
      final users = await supabase.from('profiles')
          .select('id, voice_name, real_name, avatar_url, is_revealed')
          .ilike('voice_name', '%$q%').limit(20);

      final posts = await supabase.from('posts')
          .select('id, title, body, content_type, cover_image_url, video_url, comment_count, reaction_healed, author:profiles!posts_author_id_fkey(id, voice_name, is_revealed, real_name)')
          .or('title.ilike.%$q%,body.ilike.%$q%')
          .order('created_at', ascending: false).limit(30);

      List<Map<String, dynamic>> combinedPosts = List<Map<String, dynamic>>.from(posts);

      try {
        final essays = await supabase.from('essays')
            .select('id, title, subtitle, cover_image_url, cover_color, published_at, author:profiles(id, voice_name, is_revealed, real_name)')
            .or('title.ilike.%$q%,subtitle.ilike.%$q%')
            .eq('is_published', true)
            .order('published_at', ascending: false).limit(30);

        for (final e in essays) {
          final essayMap = Map<String, dynamic>.from(e);
          essayMap['content_type'] = 'essay';
          if (!combinedPosts.any((p) => p['id'] == essayMap['id'])) {
            combinedPosts.add(essayMap);
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _userResults = List<Map<String, dynamic>>.from(users);
          _postResults = combinedPosts;
          _searching = false;
        });
      }
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
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: gold.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Icon(LucideIcons.search_x, size: 36, color: gold),
              const SizedBox(height: 10),
              Text('No results for "${_searchCtrl.text}"', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Try searching for something else or check out popular topics below', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor), textAlign: TextAlign.center),
            ]),
          ),
          ..._buildBrowseItems(context),
        ],
      );
    }

    final filteredPosts = _resultFilter == 'all' ? _postResults
        : _resultFilter == 'voices' ? _postResults.where((p) => p['content_type'] != 'short' && p['content_type'] != 'essay').toList()
        : _postResults.where((p) => p['content_type'] == _resultFilter).toList();

    return Column(children: [
      // Filter tabs
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _FilterChip(label: 'All', active: _resultFilter == 'all', gold: gold, onTap: () => setState(() => _resultFilter = 'all')),
          _FilterChip(label: 'Voices', active: _resultFilter == 'voices', gold: gold, onTap: () => setState(() => _resultFilter = 'voices')),
          _FilterChip(label: 'Essays', active: _resultFilter == 'essay', gold: gold, onTap: () => setState(() => _resultFilter = 'essay')),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 3, mainAxisSpacing: 3),
            itemCount: filteredPosts.length,
            itemBuilder: (_, i) {
              final p = filteredPosts[i];
              final type = (p['content_type'] ?? 'story').toString();
              final borderRadius = getInstagramGridBorderRadius(i, filteredPosts.length, crossAxisCount: 2);
              return GestureDetector(
                onTap: () {
                  if (type == 'short' || type == 'spark') {
                    context.push('/sparks?id=${p['id']}');
                  } else {
                    context.push('/post/${p['id']}');
                  }
                },
                child: (type == 'short' || type == 'spark')
                    ? VideoGridTile(post: p, gold: gold, borderRadius: borderRadius)
                    : PostGridTile(post: p, gold: gold, borderRadius: borderRadius),
              );
            },
          ),
        ] else if (_resultFilter != 'all') ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder),
            ),
            child: Column(children: [
              Icon(LucideIcons.search_x, size: 36, color: gold),
              const SizedBox(height: 10),
              Text(
                'No ${_resultFilter == "essay" ? "Essays" : _resultFilter == "short" ? "Sparks" : "Voices"} found',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'We couldn\'t find any ${_resultFilter == "essay" ? "essays" : _resultFilter == "short" ? "sparks" : "voices"} matching "${_searchCtrl.text}".',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _resultFilter = 'all'),
                icon: const Icon(LucideIcons.globe, size: 15),
                label: const Text('View All Results'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ]),
          ),
        ],
      ])),
    ]);
  }

  List<Widget> _buildBrowseItems(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return [
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
          _TypeTile(icon: LucideIcons.book_open, label: 'Stories', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor, onTap: () { _searchCtrl.text = 'story'; _search('story'); setState(() {}); }),
          _TypeTile(icon: LucideIcons.heart, label: 'Devotionals', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor, onTap: () { _searchCtrl.text = 'devotional'; _search('devotional'); setState(() {}); }),
          _TypeTile(icon: LucideIcons.mic, label: 'Spoken Word', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor, onTap: () { _searchCtrl.text = 'spoken word'; _search('spoken word'); setState(() {}); }),
          _TypeTile(icon: LucideIcons.message_circle, label: 'Questions', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor, onTap: () { _searchCtrl.text = 'question'; _search('question'); setState(() {}); }),
          _TypeTile(icon: LucideIcons.hand_helping, label: 'Prayer', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor, onTap: () { _searchCtrl.text = 'prayer'; _search('prayer'); setState(() {}); }),
          _TypeTile(icon: LucideIcons.video, label: 'Sparks', gold: gold, cardColor: Theme.of(context).cardColor, borderColor: Theme.of(context).dividerColor, onTap: () { _searchCtrl.text = 'spark'; _search('spark'); setState(() {}); }),
        ],
      ),
      const SizedBox(height: 40),
    ];
  }

  Widget _buildBrowse(BuildContext context) {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: _buildBrowseItems(context));
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
  final VoidCallback? onTap;
  const _TypeTile({required this.icon, required this.label, required this.gold, required this.cardColor, required this.borderColor, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 24, color: gold),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ]),
      ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? gold : Colors.transparent, width: 2.5)),
        ),
        child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: active ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor)),
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
