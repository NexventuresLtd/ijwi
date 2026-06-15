import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/publish_success_screen.dart';
import '../../../shared/widgets/mention_overlay.dart';

// Background options using app color system
const _bgOptions = <Map<String, dynamic>>[
  {'label': 'Default', 'color': null, 'gradient': null},
  {'label': 'Indigo Night', 'color': null, 'gradient': [Color(0xFF1a1840), Color(0xFF0f0f28)]},
  {'label': 'Deep Ocean', 'color': null, 'gradient': [Color(0xFF0a1628), Color(0xFF0f0f28)]},
  {'label': 'Warm Ember', 'color': null, 'gradient': [Color(0xFF1a1010), Color(0xFF0f0c1e)]},
  {'label': 'Forest', 'color': null, 'gradient': [Color(0xFF0f1a10), Color(0xFF0a1628)]},
  {'label': 'Midnight', 'color': null, 'gradient': [Color(0xFF0C0916), Color(0xFF1a1a2e)]},
  {'label': 'Violet', 'color': null, 'gradient': [Color(0xFF1a0a20), Color(0xFF0f0f28)]},
  {'label': 'Sage', 'color': null, 'gradient': [Color(0xFF0e1a10), Color(0xFF101810)]},
  {'label': 'Slate', 'color': null, 'gradient': [Color(0xFF16222a), Color(0xFF1a1a2e)]},
  {'label': 'Burgundy', 'color': null, 'gradient': [Color(0xFF201510), Color(0xFF0d0b09)]},
];

// Music presets
const _musicPresets = [
  {'name': 'Amazing Grace', 'asset': 'backgroundmusic/Amazing-Grace-2011(chosic.com).mp3'},
  {'name': 'Eternal Hope', 'asset': 'backgroundmusic/Eternal-Hope(chosic.com).mp3'},
  {'name': 'Gregorian Chant', 'asset': 'backgroundmusic/Gregorian-Chant(chosic.com).mp3'},
  {'name': 'Easter', 'asset': 'backgroundmusic/Easter-chosic.com_.mp3'},
  {'name': 'Soul Searcher', 'asset': 'backgroundmusic/sb_soulsearcher(chosic.com).mp3'},
  {'name': 'Cantate Domino', 'asset': 'backgroundmusic/Anonymous_Choir_-_Cantate_Domino(chosic.com).mp3'},
  {'name': 'Caligaverunt Oculi', 'asset': 'backgroundmusic/Anonymous_Choir_-_Caligaverunt_Oculi_Mei(chosic.com).mp3'},
  {'name': 'Amicus Meus', 'asset': 'backgroundmusic/Anonymous_Choir_-_Amicus_Meus(chosic.com).mp3'},
  {'name': 'Solemn Choral', 'asset': 'backgroundmusic/Solemn-Choral-Piece-No.-1(chosic.com).mp3'},
  {'name': 'Arcadia', 'asset': 'backgroundmusic/Arcadia(chosic.com).mp3'},
  {'name': 'Camelot Monastery', 'asset': 'backgroundmusic/Camelot-Monastery-MP3(chosic.com).mp3'},
  {'name': 'Market Day', 'asset': 'backgroundmusic/Market_Day(chosic.com).mp3'},
  {'name': 'Minstrel Dance', 'asset': 'backgroundmusic/Minstrel_Dance(chosic.com).mp3'},
];

class CreateEssayScreen extends StatefulWidget {
  const CreateEssayScreen({super.key});
  @override
  State<CreateEssayScreen> createState() => _CreateEssayScreenState();
}

class _CreateEssayScreenState extends State<CreateEssayScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _titleLink = LayerLink();
  final _bodyLink = LayerLink();
  String? _musicName;
  String? _musicUrl;
  int _bgIndex = 0;
  bool _publishing = false;
  bool _discarded = false;
  String _audience = 'anyone';
  String? _profileName;
  String? _avatarUrl;

  bool get _canPublish => _titleCtrl.text.trim().isNotEmpty && _bodyCtrl.text.trim().isNotEmpty && !_publishing;

  @override
  void initState() { super.initState(); _loadProfile(); _loadDraft(); }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final p = await supabase.from('profiles').select('voice_name, avatar_url').eq('id', uid).maybeSingle();
    if (p != null && mounted) setState(() { _profileName = p['voice_name']; _avatarUrl = p['avatar_url']; });
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('essay_draft_title');
    final body = prefs.getString('essay_draft_body');
    if (title != null && mounted) _titleCtrl.text = title;
    if (body != null && mounted) _bodyCtrl.text = body;
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('essay_draft_title', _titleCtrl.text);
    await prefs.setString('essay_draft_body', _bodyCtrl.text);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('essay_draft_title');
    await prefs.remove('essay_draft_body');
  }

  void _confirmDiscard(BuildContext context) {
    if (_titleCtrl.text.trim().isEmpty && _bodyCtrl.text.trim().isEmpty) {
      _discarded = true;
      _clearDraft();
      context.pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('Your changes will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(ctx); _discarded = true; _clearDraft(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.pop(); }); }, child: const Text('Discard', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
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
      if (_musicUrl != null && _musicUrl!.isNotEmpty) data['music_url'] = _musicUrl;
      final bg = _bgOptions[_bgIndex];
      if (bg['gradient'] != null) {
        final colors = bg['gradient'] as List<Color>;
        data['cover_color'] = '#${colors[0].toARGB32().toRadixString(16).substring(2)}';
      }
      late final Map<String, dynamic> res;
      try {
        res = await supabase.from('posts').insert(data).select('id').single();
      } catch (_) {
        // Retry as 'story' if 'essay' not in constraint yet
        final fallback = <String, dynamic>{
          'author_id': uid,
          'content_type': 'story',
          'title': _titleCtrl.text.trim(),
          'body': _bodyCtrl.text.trim(),
          'status': 'published',
        };
        res = await supabase.from('posts').insert(fallback).select('id').single();
      }
      await _clearDraft();
      notifyMentions('${_titleCtrl.text} ${_bodyCtrl.text}', postId: res['id']);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushReplacement(MaterialPageRoute(builder: (_) => PublishSuccessScreen(postId: res['id'], type: 'essay')));
      }
    } catch (_) {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  void dispose() { if (!_discarded && !_publishing) _saveDraft(); _titleCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final dividerColor = Theme.of(context).dividerColor;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(children: [
          // ─── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
            child: Row(children: [
              GestureDetector(
                onTap: () => _confirmDiscard(context),
                child: Icon(LucideIcons.x, size: 22, color: onSurface),
              ),
              const SizedBox(width: 14),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                child: ClipOval(
                  child: _avatarUrl != null && _avatarUrl!.startsWith('http')
                      ? Image.network(_avatarUrl!, width: 34, height: 34, fit: BoxFit.cover)
                      : Center(child: Text((_profileName ?? '?')[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gold))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_profileName ?? '', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
                GestureDetector(
                  onTap: () => _showAudiencePicker(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_audience == 'anyone' ? LucideIcons.globe : LucideIcons.users, size: 11, color: gold),
                    const SizedBox(width: 3),
                    Text(_audience == 'anyone' ? 'Anyone' : 'Followers', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w500)),
                    Icon(LucideIcons.chevron_down, size: 12, color: gold),
                  ]),
                ),
              ])),
              ElevatedButton(
                onPressed: _canPublish ? _publish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canPublish ? gold : (isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                  foregroundColor: _canPublish ? Colors.white : hintColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(_publishing ? '...' : 'Publish', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // ─── Body ─────────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),

              // Chips row
              if (_musicName != null || _bgIndex > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    if (_musicName != null)
                      _Chip(icon: LucideIcons.music, label: _musicName!, gold: gold, surface: surface, dividerColor: dividerColor, onRemove: () => setState(() { _musicName = null; _musicUrl = null; })),
                    if (_bgIndex > 0)
                      _Chip(icon: LucideIcons.palette, label: (_bgOptions[_bgIndex]['label'] as String), gold: gold, surface: surface, dividerColor: dividerColor, onRemove: () => setState(() => _bgIndex = 0)),
                  ]),
                ),

              // Title
              MentionOverlay(
                controller: _titleCtrl,
                layerLink: _titleLink,
                child: TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Essay Title',
                    hintStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: hintColor),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // Divider
              const SizedBox(height: 8),

              // Body
              MentionOverlay(
                controller: _bodyCtrl,
                layerLink: _bodyLink,
                child: TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  minLines: 12,
                  style: GoogleFonts.montserrat(fontSize: 15, height: 1.75, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Start writing your essay...',
                    hintStyle: GoogleFonts.poppins(fontSize: 15, color: hintColor),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 80),
            ]),
          )),

          // ─── Bottom Actions ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: dividerColor))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['testimony', 'worship', 'faith', 'prayer', 'healing', 'grace', 'hope'].map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { _bodyCtrl.text = '${_bodyCtrl.text} #$tag'; _bodyCtrl.selection = TextSelection.collapsed(offset: _bodyCtrl.text.length); setState(() {}); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withValues(alpha: 0.2))),
                        child: Text('#$tag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gold)),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _ActionPill(icon: LucideIcons.music, label: 'Add Music', gold: gold, onTap: () => _showMusicSheet(context)),
                const SizedBox(width: 10),
                _ActionPill(icon: LucideIcons.palette, label: 'Background', gold: gold, onTap: () => _showBgSheet(context)),
                const Spacer(),
                Text('${_bodyCtrl.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words', style: TextStyle(fontSize: 11, color: hintColor)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─── Audience Picker ────────────────────────────────────────
  void _showAudiencePicker(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Text('Who can see this?', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w500, color: onSurface)),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(LucideIcons.globe, color: _audience == 'anyone' ? gold : Theme.of(context).hintColor),
            title: Text('Anyone', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('Visible to everyone on Ijwi', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            trailing: _audience == 'anyone' ? Icon(LucideIcons.check, size: 18, color: gold) : null,
            onTap: () { setState(() => _audience = 'anyone'); Navigator.pop(ctx); },
          ),
          ListTile(
            leading: Icon(LucideIcons.users, color: _audience == 'followers' ? gold : Theme.of(context).hintColor),
            title: Text('Followers only', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('Only people who follow you', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            trailing: _audience == 'followers' ? Icon(LucideIcons.check, size: 18, color: gold) : null,
            onTap: () { setState(() => _audience = 'followers'); Navigator.pop(ctx); },
          ),
        ]),
      )),
    );
  }

  // ─── Music Bottom Sheet ─────────────────────────────────────
  void _showMusicSheet(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final dividerColor = Theme.of(context).dividerColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MusicPickerSheet(gold: gold, hintColor: hintColor, dividerColor: dividerColor, onSurface: onSurface, onSelect: (name, url) {
        setState(() { _musicName = name; _musicUrl = url; });
      }),
    );
  }

  // ─── Background Bottom Sheet ────────────────────────────────
  void _showBgSheet(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Row(children: [
            Icon(LucideIcons.palette, size: 18, color: gold),
            const SizedBox(width: 8),
            Text('Reading Background', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: onSurface)),
          ]),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: Text('Readers will see this while reading your essay', style: TextStyle(fontSize: 12, color: hintColor))),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: _bgOptions.length,
            itemBuilder: (_, i) {
              final opt = _bgOptions[i];
              final isSelected = _bgIndex == i;
              final gradient = opt['gradient'] as List<Color>?;
              return GestureDetector(
                onTap: () { setState(() => _bgIndex = i); Navigator.pop(ctx); },
                child: Container(
                  decoration: BoxDecoration(
                    color: gradient == null ? scaffoldBg : null,
                    gradient: gradient != null ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient) : null,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? gold : (isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2), width: isSelected ? 2.5 : 1),
                  ),
                  child: gradient == null
                      ? Center(child: Text('Aa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface.withValues(alpha: 0.5))))
                      : (isSelected ? Center(child: Icon(LucideIcons.check, size: 16, color: gold)) : null),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gold, surface, dividerColor;
  final VoidCallback onRemove;
  const _Chip({required this.icon, required this.label, required this.gold, required this.surface, required this.dividerColor, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: dividerColor)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: gold),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove, child: Icon(LucideIcons.x, size: 13, color: Theme.of(context).hintColor)),
      ]),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gold;
  final VoidCallback onTap;
  const _ActionPill({required this.icon, required this.label, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    final border = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: border, width: 0.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: gold),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}


class _MusicPickerSheet extends StatefulWidget {
  final Color gold, hintColor, dividerColor, onSurface;
  final void Function(String name, String url) onSelect;
  const _MusicPickerSheet({required this.gold, required this.hintColor, required this.dividerColor, required this.onSurface, required this.onSelect});
  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _player = AudioPlayer();
  int _playingIdx = -1;

  List<Map<String, String>> get _filtered {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _musicPresets.cast<Map<String, String>>();
    return _musicPresets.where((m) => m['name']!.toLowerCase().contains(q)).cast<Map<String, String>>().toList();
  }

  void _togglePreview(int idx, String asset) async {
    if (_playingIdx == idx) {
      await _player.stop();
      setState(() => _playingIdx = -1);
      return;
    }
    await _player.stop();
    try {
      await _player.play(AssetSource(asset));
    } catch (_) {
      try { await _player.play(UrlSource('https://ijwi-orpin.vercel.app/$asset')); } catch (_) {}
    }
    setState(() => _playingIdx = idx);
  }

  @override
  void dispose() { _player.dispose(); _searchCtrl.dispose(); _urlCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.6, maxChildSize: 0.85,
      builder: (_, scroll) => Column(children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4, decoration: BoxDecoration(color: widget.hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(children: [
            Icon(LucideIcons.music, size: 18, color: widget.gold),
            const SizedBox(width: 8),
            Text('Add Music', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: widget.onSurface)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(fontSize: 13, color: widget.onSurface),
            decoration: InputDecoration(hintText: 'Search music...', prefixIcon: Icon(LucideIcons.search, size: 16, color: widget.hintColor)),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: widget.dividerColor),
          itemBuilder: (_, i) {
            final m = items[i];
            final isPlaying = _playingIdx == i;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                // Preview play button
                GestureDetector(
                  onTap: () => _togglePreview(i, m['asset']!),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: widget.gold.withValues(alpha: 0.1)),
                    child: Icon(isPlaying ? LucideIcons.pause : LucideIcons.play, size: 16, color: widget.gold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(m['name']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500))),
                // Add button
                GestureDetector(
                  onTap: () { _player.stop(); widget.onSelect(m['name']!, m['asset']!); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: widget.gold, borderRadius: BorderRadius.circular(16)),
                    child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ]),
            );
          },
        )),
        // Custom URL
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(children: [
            Expanded(child: TextField(controller: _urlCtrl, style: const TextStyle(fontSize: 12), decoration: InputDecoration(hintText: 'Or paste URL...', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { if (_urlCtrl.text.trim().isNotEmpty) { widget.onSelect('Custom Audio', _urlCtrl.text.trim()); Navigator.pop(context); } },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: widget.gold, borderRadius: BorderRadius.circular(16)), child: const Text('Use', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
            ),
          ]),
        ),
      ]),
    );
  }
}
