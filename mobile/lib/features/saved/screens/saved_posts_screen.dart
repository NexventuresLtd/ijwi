import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
    try {
      final saved = await supabase.from('saved_posts').select('post_id').eq('user_id', uid).order('created_at', ascending: false);
      final ids = saved.map<String>((s) => s['post_id'] as String).toList();
      if (ids.isEmpty) { if (mounted) setState(() => _loading = false); return; }
      final posts = await supabase.from('posts').select('id, title, body, content_type').inFilter('id', ids);
      if (mounted) setState(() { _posts = List<Map<String, dynamic>>.from(posts); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) {
                    final p = _posts[i];
                    final type = (p['content_type'] ?? 'story').toString();
                    final gradients = {
                      'story': [const Color(0xFF2D1B69), const Color(0xFF11998e)],
                      'devotional': [const Color(0xFF1a1a2e), const Color(0xFFb8860b)],
                      'spoken_word': [const Color(0xFF200122), const Color(0xFF6f0000)],
                      'prayer_request': [const Color(0xFF0f2027), const Color(0xFF2c5364)],
                      'question': [const Color(0xFF1f1c2c), const Color(0xFF928DAB)],
                      'encouragement': [const Color(0xFF134E5E), const Color(0xFF71B280)],
                      'essay': [const Color(0xFF1a1840), const Color(0xFF0f0f28)],
                    };
                    final colors = gradients[type] ?? gradients['story']!;
                    return GestureDetector(
                      onTap: () => context.push('/post/${p['id']}'),
                      child: Container(
                        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
                        child: Stack(children: [
                          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)])))),
                          Positioned(top: 6, left: 6, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
                            child: Text(type.replaceAll('_', ' '), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.3)),
                          )),
                          Positioned(top: 6, right: 6, child: Icon(LucideIcons.bookmark_check, size: 12, color: gold)),
                          Positioned(bottom: 6, left: 6, right: 6, child: Text(
                            p['title'] ?? p['body'] ?? '',
                            style: const TextStyle(fontSize: 9, color: Colors.white, height: 1.3, fontWeight: FontWeight.w500),
                            maxLines: 3, overflow: TextOverflow.ellipsis,
                          )),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
