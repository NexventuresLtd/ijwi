import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _anonymousDefault = false;
  bool _showRealName = false;
  bool _allowDms = true;
  bool _showOnline = true;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) { if (mounted) setState(() => _loading = false); return; }
    try {
      final p = await supabase.from('profiles').select('is_revealed').eq('id', uid).maybeSingle();
      if (p != null && mounted) setState(() {
        _showRealName = p['is_revealed'] == true;
        _loading = false;
      }); else if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(String field, bool value) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try { await supabase.from('profiles').update({field: value}).eq('id', uid); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Privacy & Security', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _Section('Identity'),
        _ToggleTile(
          icon: LucideIcons.eye, title: 'Show real name', subtitle: 'Reveal your identity on posts and profile',
          value: _showRealName, gold: gold, surface: surface, border: border,
          onChanged: (v) { setState(() => _showRealName = v); _update('is_revealed', v); },
        ),
        const SizedBox(height: 8),
        _ToggleTile(
          icon: LucideIcons.user_x, title: 'Post anonymously by default', subtitle: 'New posts will hide your name',
          value: _anonymousDefault, gold: gold, surface: surface, border: border,
          onChanged: (v) { setState(() => _anonymousDefault = v); _update('anonymous_default', v); },
        ),

        const SizedBox(height: 24),
        _Section('Communication'),
        _ToggleTile(
          icon: LucideIcons.message_circle, title: 'Allow direct messages', subtitle: 'Let others send you DMs',
          value: _allowDms, gold: gold, surface: surface, border: border,
          onChanged: (v) { setState(() => _allowDms = v); _update('allow_dms', v); },
        ),
        const SizedBox(height: 8),
        _ToggleTile(
          icon: LucideIcons.radio, title: 'Show online status', subtitle: 'Others can see when you\'re active',
          value: _showOnline, gold: gold, surface: surface, border: border,
          onChanged: (v) { setState(() => _showOnline = v); _update('show_online', v); },
        ),

        const SizedBox(height: 24),
        _Section('Data'),
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
          child: Column(children: [
            _ActionTile(icon: LucideIcons.download, title: 'Download my data', subtitle: 'Export your posts and profile', gold: gold, onTap: () {}),
            Divider(height: 1, color: border),
            _ActionTile(icon: LucideIcons.shield_alert, title: 'Blocked users', subtitle: 'Manage blocked accounts', gold: gold, onTap: () {}),
          ]),
        ),

        const SizedBox(height: 24),
        _Section(''),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
          child: Row(children: [
            Icon(LucideIcons.lock, size: 16, color: text3),
            const SizedBox(width: 10),
            Expanded(child: Text('Your data is encrypted and stored securely. We never share your information with third parties.', style: TextStyle(fontSize: 12, color: text3, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Theme.of(context).hintColor)));
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final Color gold, surface, border;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({required this.icon, required this.title, required this.subtitle, required this.value, required this.gold, required this.surface, required this.border, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
      child: Row(children: [
        Icon(icon, size: 18, color: gold),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        ])),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: gold),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color gold;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: gold),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ])),
          Icon(LucideIcons.chevron_right, size: 16, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }
}
