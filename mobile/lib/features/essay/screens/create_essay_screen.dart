import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';

const _coverColors = [
  Color(0xFF1a1840),
  Color(0xFF0f1a10),
  Color(0xFF1a1010),
  Color(0xFF0a1628),
  Color(0xFF1a0a20),
  Color(0xFF0C0916),
  Color(0xFF102010),
  Color(0xFF201510),
];

class CreateEssayScreen extends StatefulWidget {
  const CreateEssayScreen({super.key});
  @override
  State<CreateEssayScreen> createState() => _CreateEssayScreenState();
}

class _CreateEssayScreenState extends State<CreateEssayScreen> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _musicCtrl = TextEditingController();
  Color _coverColor = const Color(0xFF1a1840);
  bool _publishing = false;

  bool get _canPublish => _titleCtrl.text.trim().isNotEmpty && _bodyCtrl.text.trim().isNotEmpty && !_publishing;

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _publishing = true);
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('posts').insert({
      'author_id': uid,
      'content_type': 'essay',
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
      'subtitle': _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim(),
      'music_url': _musicCtrl.text.trim().isEmpty ? null : _musicCtrl.text.trim(),
      'cover_color': '#${_coverColor.toARGB32().toRadixString(16).substring(2)}',
      'status': 'published',
    });
    if (mounted) context.go('/feed');
  }

  @override
  void dispose() { _titleCtrl.dispose(); _subtitleCtrl.dispose(); _bodyCtrl.dispose(); _musicCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: _coverColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(LucideIcons.x, size: 22, color: Colors.white), onPressed: () => context.pop()),
        title: Text('Essay', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _canPublish ? _publish : null,
              style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1814), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: Text(_publishing ? '...' : 'Publish', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cover color picker
          Text('COVER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.white60)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _coverColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _coverColors[i];
                final selected = c.toARGB32() == _coverColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _coverColor = c),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? gold : Colors.white24, width: selected ? 2.5 : 1),
                    ),
                    child: selected ? Icon(LucideIcons.check, size: 16, color: gold) : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 28),

          // Title
          TextField(
            controller: _titleCtrl,
            style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white),
            decoration: InputDecoration(hintText: 'Title', hintStyle: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white30), border: InputBorder.none),
            maxLines: 2,
          ),

          // Subtitle
          TextField(
            controller: _subtitleCtrl,
            style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white70),
            decoration: InputDecoration(hintText: 'Subtitle (optional)', hintStyle: GoogleFonts.dmSans(fontSize: 16, color: Colors.white24), border: InputBorder.none),
          ),

          const SizedBox(height: 8),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),

          // Body
          TextField(
            controller: _bodyCtrl,
            maxLines: null,
            minLines: 12,
            style: GoogleFonts.dmSans(fontSize: 15, height: 1.8, color: Colors.white.withValues(alpha: 0.9)),
            decoration: InputDecoration(hintText: 'Write your essay...\n\nShare your thoughts, reflections, or a deep word from God. This is your space to write long-form.', hintStyle: GoogleFonts.dmSans(fontSize: 15, height: 1.8, color: Colors.white24), border: InputBorder.none),
          ),

          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 16),

          // Background music URL
          Text('BACKGROUND MUSIC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.white60)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
            child: TextField(
              controller: _musicCtrl,
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste audio URL (mp3, m4a...)',
                hintStyle: TextStyle(fontSize: 14, color: Colors.white30),
                border: InputBorder.none,
                icon: Icon(LucideIcons.music, size: 16, color: gold),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('Readers will hear this music while reading your essay', style: TextStyle(fontSize: 11, color: Colors.white38)),

          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}
