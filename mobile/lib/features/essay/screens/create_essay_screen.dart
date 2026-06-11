import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/publish_success_screen.dart';

const _coverColors = <Color?>[
  null,
  Color(0xFF1a1840), Color(0xFF0f1a10), Color(0xFF1a1010), Color(0xFF0a1628),
  Color(0xFF1a0a20), Color(0xFF0C0916), Color(0xFF102010), Color(0xFF201510),
  Color(0xFF2d1b69), Color(0xFF0f2027), Color(0xFF1f1c2c), Color(0xFF134e5e),
  Color(0xFF0d0b09), Color(0xFF1a1a2e), Color(0xFF16222a),
];

class CreateEssayScreen extends StatefulWidget {
  const CreateEssayScreen({super.key});
  @override
  State<CreateEssayScreen> createState() => _CreateEssayScreenState();
}

class _CreateEssayScreenState extends State<CreateEssayScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _musicCtrl = TextEditingController();
  Color? _coverColor;
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
      final data = <String, dynamic>{
        'author_id': uid,
        'content_type': 'essay',
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'status': 'published',
      };
      if (_musicCtrl.text.trim().isNotEmpty) data['music_url'] = _musicCtrl.text.trim();
      if (_coverColor != null) data['cover_color'] = '#${_coverColor!.toARGB32().toRadixString(16).substring(2)}';
      final res = await supabase.from('posts').insert(data).select('id').single();
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PublishSuccessScreen(postId: res['id'], type: 'essay')));
      }
    } catch (_) {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); _musicCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final bg = isDark ? IjwiColors.darkBg : IjwiColors.lightBg;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          // Top row: close + avatar + publish
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Icon(LucideIcons.x, size: 24, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                child: ClipOval(
                  child: _avatarUrl != null && _avatarUrl!.startsWith('http')
                      ? Image.network(_avatarUrl!, width: 36, height: 36, fit: BoxFit.cover)
                      : Center(child: Text((_profileName ?? '?')[0].toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gold))),
                ),
              ),
              const SizedBox(width: 10),
              Text(_profileName ?? '', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              ElevatedButton(
                onPressed: _canPublish ? _publish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canPublish ? gold : border,
                  foregroundColor: _canPublish ? const Color(0xFF1A1814) : text3,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(_publishing ? '...' : 'Publish', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),

          // Writing area
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: text3),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              Container(height: 0.5, margin: const EdgeInsets.symmetric(vertical: 4), color: border),
              TextField(
                controller: _bodyCtrl,
                maxLines: null,
                minLines: 10,
                style: GoogleFonts.dmSans(fontSize: 15, height: 1.7),
                decoration: InputDecoration(
                  hintText: 'Share your voice...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 15, color: text3),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              if (_showMusicField) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 0.5)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(LucideIcons.music, size: 14, color: gold),
                      const SizedBox(width: 6),
                      Text('Background Music', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(onTap: () => setState(() { _showMusicField = false; _musicCtrl.clear(); }), child: Icon(LucideIcons.x, size: 14, color: text3)),
                    ]),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _musicCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(hintText: 'Audio URL (mp3, m4a)', hintStyle: TextStyle(fontSize: 13, color: text3), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: gold))),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 80),
            ]),
          )),

          // Bottom toolbar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: border, width: 0.5))),
            child: Row(children: [
              _ToolBtn(icon: LucideIcons.palette, color: _coverColor, gold: gold, onTap: () => _showColorPicker(context, gold, isDark, surface, border, bg)),
              const SizedBox(width: 10),
              _ToolBtn(icon: LucideIcons.music, gold: gold, onTap: () => setState(() => _showMusicField = true)),
              const Spacer(),
              Text('${_bodyCtrl.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words', style: TextStyle(fontSize: 11, color: text3)),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color gold, bool isDark, Color surface, Color border, Color bg) {
    showModalBottomSheet(
      context: context, backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Text('Reading Background', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: _coverColors.map((c) {
            final selected = c?.toARGB32() == _coverColor?.toARGB32();
            return GestureDetector(
              onTap: () { setState(() => _coverColor = c); Navigator.pop(ctx); },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: c ?? bg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? gold : (isDark ? Colors.white12 : Colors.black12), width: selected ? 2.5 : 1),
                ),
                child: c == null
                    ? Center(child: Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)))
                    : (selected ? Center(child: Icon(LucideIcons.check, size: 14, color: gold)) : null),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
        ]),
      )),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final Color gold;
  final Color? color;
  final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.gold, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color ?? Colors.transparent, border: Border.all(color: color != null ? Colors.white24 : Theme.of(context).dividerColor)),
        child: color != null ? null : Icon(icon, size: 16, color: gold),
      ),
    );
  }
}
