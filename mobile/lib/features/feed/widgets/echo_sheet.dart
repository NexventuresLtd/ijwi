import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class EchoSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final Color gold;
  final bool isDark;
  const EchoSheet({super.key, required this.post, required this.gold, required this.isDark});
  @override
  State<EchoSheet> createState() => _EchoSheetState();
}

class _EchoSheetState extends State<EchoSheet> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadPeople(); }

  Future<void> _loadPeople() async {
    final uid = supabase.auth.currentUser!.id;
    final res1 = await supabase.from('follows').select('following_id').eq('follower_id', uid);
    final res2 = await supabase.from('follows').select('follower_id').eq('following_id', uid);
    final ids = <String>{};
    for (final r in res1) ids.add(r['following_id'] as String);
    for (final r in res2) ids.add(r['follower_id'] as String);
    ids.remove(uid);
    if (ids.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    final profiles = await supabase.from('profiles').select('id, voice_name, real_name, is_revealed, avatar_url').inFilter('id', ids.toList());
    if (mounted) setState(() { _people = List<Map<String, dynamic>>.from(profiles); _loading = false; });
  }

  void _sendTo(String userId) async {
    final msg = '[post:${widget.post['id']}]';
    await supabase.from('direct_messages').insert({'sender_id': supabase.auth.currentUser!.id, 'receiver_id': userId, 'message': msg});
    if (mounted) Navigator.pop(context);
  }

  void _shareExternal() {
    final body = (widget.post['body'] ?? '').toString();
    final preview = body.length > 80 ? '${body.substring(0, 80)}...' : body;
    SharePlus.instance.share(ShareParams(text: '"$preview"\n\n\u2014 Shared from Ijwi\nhttps://ijwi-orpin.vercel.app/post/${widget.post['id']}'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final text3 = widget.isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: text3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 8), child: Row(children: [
            Text('Echo this post', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(LucideIcons.x, size: 20, color: text3)),
          ])),
          // Share externally
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: GestureDetector(
            onTap: _shareExternal,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.gold.withValues(alpha: 0.3)), color: widget.gold.withValues(alpha: 0.05)),
              child: Row(children: [
                Icon(LucideIcons.share_2, size: 20, color: widget.gold),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Share externally', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Copy link or share to other apps', style: TextStyle(fontSize: 11, color: text3)),
                ])),
                Icon(LucideIcons.chevron_right, size: 16, color: text3),
              ]),
            ),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('SEND TO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text3, letterSpacing: 0.8)))),
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _people.isEmpty
              ? Center(child: Text('No connections yet', style: TextStyle(color: text3)))
              : ListView.builder(controller: scroll, itemCount: _people.length, itemBuilder: (_, i) {
                  final p = _people[i];
                  final name = (p['is_revealed'] == true && p['real_name'] != null) ? p['real_name'] : p['voice_name'];
                  return InkWell(
                    onTap: () => _sendTo(p['id']),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.gold.withValues(alpha: 0.1), border: Border.all(color: widget.gold.withValues(alpha: 0.2))), alignment: Alignment.center, child: Text(name.toString()[0].toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: widget.gold))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: widget.gold), child: const Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1814)))),
                    ])),
                  );
                })),
        ]),
      ),
    );
  }
}
