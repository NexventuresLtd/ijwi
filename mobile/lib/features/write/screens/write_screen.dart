import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
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
  String _audience = 'anyone';
  bool _loading = false;
  String? _profileName;
  String? _avatarUrl;

  final _types = ['story', 'devotional', 'spoken_word', 'prayer_request', 'question', 'encouragement', 'letter'];

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final p = await supabase.from('profiles').select('voice_name, avatar_url').eq('id', uid).maybeSingle();
    if (p != null && mounted) setState(() { _profileName = p['voice_name']; _avatarUrl = p['avatar_url']; });
  }

  bool get _canPublish => _body.text.trim().isNotEmpty && !_loading;

  Future<void> _publish() async {
    if (!_canPublish) return;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final dividerColor = Theme.of(context).dividerColor;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ─── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.pop(),
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
                Text(_profileName ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
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
                child: Text(_loading ? '...' : 'Publish', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // ─── Content ──────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 14),

              // Type chips
              SizedBox(
                height: 32,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: active ? gold.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: active ? gold : dividerColor, width: active ? 1 : 0.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(t.replaceAll('_', ' '), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: active ? gold : hintColor)),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Title
              TextField(
                controller: _title,
                autofocus: true,
                style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: onSurface),
                decoration: InputDecoration(
                  hintText: 'Title (optional)',
                  hintStyle: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: hintColor),
                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent, filled: true,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),

              // Divider
              Container(height: 0.5, margin: const EdgeInsets.symmetric(vertical: 4), color: dividerColor),

              // Body
              TextField(
                controller: _body,
                maxLines: null,
                minLines: 10,
                style: GoogleFonts.dmSans(fontSize: 15, height: 1.7, color: onSurface),
                decoration: InputDecoration(
                  hintText: 'Share your voice...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 15, color: hintColor),
                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent, filled: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 80),
            ]),
          )),

          // ─── Bottom ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: dividerColor))),
            child: Row(children: [
              Icon(LucideIcons.type, size: 16, color: hintColor),
              const SizedBox(width: 6),
              Text(_type.replaceAll('_', ' '), style: TextStyle(fontSize: 12, color: hintColor, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${_body.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words', style: TextStyle(fontSize: 11, color: hintColor)),
            ]),
          ),
        ]),
      ),
    );
  }

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
          Text('Who can see this?', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w500, color: onSurface)),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(LucideIcons.globe, color: _audience == 'anyone' ? gold : Theme.of(context).hintColor),
            title: Text('Anyone', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('Visible to everyone on Ijwi', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            trailing: _audience == 'anyone' ? Icon(LucideIcons.check, size: 18, color: gold) : null,
            onTap: () { setState(() => _audience = 'anyone'); Navigator.pop(ctx); },
          ),
          ListTile(
            leading: Icon(LucideIcons.users, color: _audience == 'followers' ? gold : Theme.of(context).hintColor),
            title: Text('Followers only', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('Only people who follow you', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            trailing: _audience == 'followers' ? Icon(LucideIcons.check, size: 18, color: gold) : null,
            onTap: () { setState(() => _audience = 'followers'); Navigator.pop(ctx); },
          ),
        ]),
      )),
    );
  }
}
