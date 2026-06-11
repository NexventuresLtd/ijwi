import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../shared/widgets/publish_success_screen.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key});
  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _type = 'story';
  bool _loading = false;

  final _types = ['story', 'devotional', 'spoken_word', 'prayer_request', 'question', 'encouragement', 'letter'];

  Future<void> _publish() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final uid = supabase.auth.currentUser!.id;
    final res = await supabase.from('posts').insert({
      'author_id': uid,
      'content_type': _type,
      'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      'body': _body.text.trim(),
      'status': 'published',
    }).select('id').single();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PublishSuccessScreen(postId: res['id'], type: _type.replaceAll('_', ' '))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(LucideIcons.x, size: 22), onPressed: () => context.pop()),
        title: Text('Write', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _loading ? null : _publish,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
              child: Text(_loading ? '...' : 'Publish'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Type selector
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _types[i];
                final active = t == _type;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: active ? gold.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: active ? gold : Theme.of(context).dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(t.replaceAll('_', ' '), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? gold : Theme.of(context).hintColor)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(hintText: 'Title (optional)', hintStyle: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: Theme.of(context).hintColor), border: InputBorder.none),
          ),
          TextField(
            controller: _body,
            maxLines: null,
            minLines: 10,
            style: GoogleFonts.dmSans(fontSize: 15, height: 1.7),
            decoration: InputDecoration(hintText: 'Share your voice...', hintStyle: GoogleFonts.dmSans(fontSize: 15, color: Theme.of(context).hintColor), border: InputBorder.none),
          ),
        ]),
      ),
    );
  }
}
