import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});
  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final saved = await supabase.from('saved_posts').select('post_id').eq('user_id', uid).order('created_at', ascending: false);
    final ids = saved.map<String>((s) => s['post_id'] as String).toList();
    if (ids.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    final posts = await supabase.from('posts').select('*, author:profiles!posts_author_id_fkey(id, voice_name, avatar_url, is_revealed, real_name)').inFilter('id', ids);
    if (mounted) setState(() { _posts = List<Map<String, dynamic>>.from(posts); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Saved Posts', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.bookmark, size: 40, color: text3),
                  const SizedBox(height: 12),
                  Text('No saved posts', style: GoogleFonts.poppins(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Posts you save will appear here', style: TextStyle(fontSize: 13, color: text3)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) {
                    final p = _posts[i];
                    final author = p['author'] as Map<String, dynamic>?;
                    final name = (author?['is_revealed'] == true && author?['real_name'] != null) ? author!['real_name'] : (author?['voice_name'] ?? 'Anonymous');
                    return GestureDetector(
                      onTap: () => context.push('/post/${p['id']}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder, width: 0.5),
                        ),
                        child: Row(children: [
                          Icon(LucideIcons.bookmark_check, size: 18, color: gold),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p['title'] ?? (p['body'] ?? '').toString().substring(0, (p['body'] ?? '').toString().length.clamp(0, 60)), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('by $name • ${timeago.format(DateTime.parse(p['created_at']))}', style: TextStyle(fontSize: 11, color: text3)),
                          ])),
                          Icon(LucideIcons.chevron_right, size: 16, color: text3),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
