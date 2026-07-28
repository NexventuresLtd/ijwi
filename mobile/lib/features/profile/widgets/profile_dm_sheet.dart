import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class ProfileDmSheet extends StatefulWidget {
  final String? userId;
  final Color gold;
  final bool isDark;
  const ProfileDmSheet({super.key, required this.userId, required this.gold, required this.isDark});
  @override
  State<ProfileDmSheet> createState() => _ProfileDmSheetState();
}

class _ProfileDmSheetState extends State<ProfileDmSheet> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadPeople(); }

  Future<void> _loadPeople() async {
    try {
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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sendTo(String targetUserId) async {
    final profileIdToShare = widget.userId ?? supabase.auth.currentUser!.id;
    final msg = '[profile:$profileIdToShare]';
    await supabase.from('direct_messages').insert({'sender_id': supabase.auth.currentUser!.id, 'receiver_id': targetUserId, 'message': msg});
    if (mounted) Navigator.pop(context);
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
            Text('Share via DM', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(LucideIcons.x, size: 20, color: text3)),
          ])),
          const SizedBox(height: 8),
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
                      Expanded(child: Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: widget.gold), child: const Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1814)))),
                    ])),
                  );
                })),
        ]),
      ),
    );
  }
}
