import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

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
  bool _showMusicField = false;
  String? _profileName;
  String? _avatarUrl;

  bool get _canPublish => _titleCtrl.text.trim().isNotEmpty && _bodyCtrl.text.trim().isNotEmpty && !_publishing;

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final p = await supabase.from('profiles').select('voice_name, avatar_url').eq('id', uid).maybeSingle();
    if (p != null && mounted) setState(() { _profileName = p['voice_name']; _avatarUrl = p['avatar_url']; });
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _publishing = true);
    final uid = supabase.auth.currentUser!.id;
    try {
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
    } catch (_) {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _subtitleCtrl.dispose(); _bodyCtrl.dispose(); _musicCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final bg = isDark ? IjwiColors.darkBg : IjwiColors.lightBg;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text2 = isDark ? IjwiColors.darkText2 : IjwiColors.lightText2;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border, width: 0.5))),
            child: Row(children: [
              IconButton(icon: Icon(LucideIcons.x, size: 22, color: text2), onPressed: () => context.pop()),
              const Spacer(),
              // Publish button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _canPublish ? _publish : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canPublish ? gold : border,
                    foregroundColor: _canPublish ? const Color(0xFF1A1814) : text3,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(_publishing ? 'Publishing...' : 'Publish', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ),

          // Content
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),

              // Author row
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                  child: ClipOval(
                    child: _avatarUrl != null && _avatarUrl!.startsWith('http')
                        ? Image.network(_avatarUrl!, width: 44, height: 44, fit: BoxFit.cover)
                        : Center(child: Text((_profileName ?? '?')[0].toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: gold))),
                  ),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_profileName ?? '...', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
                  Row(children: [
                    Icon(LucideIcons.book_open, size: 12, color: gold),
                    const SizedBox(width: 4),
                    Text('Essay', style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w500)),
                  ]),
                ]),
              ]),

              const SizedBox(height: 24),

              // Title
              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: text3),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),

              // Subtitle
              TextField(
                controller: _subtitleCtrl,
                style: GoogleFonts.dmSans(fontSize: 16, color: text2),
                decoration: InputDecoration(
                  hintText: 'Add a subtitle...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 16, color: text3.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: 4),
              Container(height: 0.5, color: border),
              const SizedBox(height: 16),

              // Body
              TextField(
                controller: _bodyCtrl,
                maxLines: null,
                minLines: 8,
                style: GoogleFonts.dmSans(fontSize: 15, height: 1.8, color: text2),
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 15, height: 1.8, color: text3.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 20),

              // Music field (expandable)
              if (_showMusicField) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(LucideIcons.music, size: 16, color: gold),
                      const SizedBox(width: 8),
                      Text('Background Music', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(onTap: () => setState(() => _showMusicField = false), child: Icon(LucideIcons.x, size: 16, color: text3)),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _musicCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Paste audio URL (mp3, m4a...)',
                        hintStyle: TextStyle(fontSize: 13, color: text3),
                        filled: true,
                        fillColor: bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: gold)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Plays softly while readers enjoy your essay', style: TextStyle(fontSize: 11, color: text3)),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 60),
            ]),
          )),

          // Bottom toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: border, width: 0.5))),
            child: Row(children: [
              // Cover color
              _ToolbarBtn(icon: LucideIcons.palette, label: 'Cover', color: _coverColor, gold: gold, onTap: () => _showColorPicker(context, gold, isDark, surface, border)),
              const SizedBox(width: 12),
              // Music
              _ToolbarBtn(icon: LucideIcons.music, label: 'Music', gold: gold, onTap: () => setState(() => _showMusicField = true)),
              const Spacer(),
              // Word count
              Text('${_bodyCtrl.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words', style: TextStyle(fontSize: 12, color: text3)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color gold, bool isDark, Color surface, Color border) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Text('Reading Background', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Readers will see this color while reading your essay', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: _coverColors.map((c) {
            final selected = c.toARGB32() == _coverColor.toARGB32();
            return GestureDetector(
              onTap: () { setState(() => _coverColor = c); Navigator.pop(ctx); },
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? gold : Colors.transparent, width: 2.5),
                  boxShadow: selected ? [BoxShadow(color: gold.withValues(alpha: 0.3), blurRadius: 8)] : null,
                ),
                child: selected ? Center(child: Icon(LucideIcons.check, size: 18, color: gold)) : null,
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
        ]),
      )),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gold;
  final Color? color;
  final VoidCallback onTap;
  const _ToolbarBtn({required this.icon, required this.label, required this.gold, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg2 = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    final border = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg2, borderRadius: BorderRadius.circular(20), border: Border.all(color: border, width: 0.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (color != null)
            Container(width: 16, height: 16, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)))
          else
            Icon(icon, size: 15, color: gold),
          if (color == null) const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2)),
        ]),
      ),
    );
  }
}
