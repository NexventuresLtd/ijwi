import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../profile/screens/profile_screen.dart';

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
      final posts = await supabase.from('posts').select('id, title, body, content_type, created_at, reaction_fire, video_url, cover_image_url').inFilter('id', ids);
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
                    final isVideo = type == 'short' || p['video_url'] != null;
                    final tile = isVideo ? VideoGridTile(post: p, gold: gold) : PostGridTile(post: p, gold: gold);

                    return GestureDetector(
                      onTap: () {
                         if (isVideo) {
                           context.push('/sparks?id=${p['id']}');
                         } else {
                           context.push('/post/${p['id']}');
                         }
                      },
                      child: Stack(
                        children: [
                          tile,
                          Positioned(top: 6, right: 6, child: Icon(LucideIcons.bookmark_check, size: 12, color: gold)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
