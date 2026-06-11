import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});
  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  bool _isPro = false;
  DateTime? _expiresAt;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final p = await supabase.from('profiles').select('is_pro, pro_expires_at').eq('id', uid).maybeSingle();
    if (p != null && mounted) setState(() {
      _isPro = p['is_pro'] == true;
      _expiresAt = p['pro_expires_at'] != null ? DateTime.tryParse(p['pro_expires_at'].toString()) : null;
      _loading = false;
    }); else if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final isExpired = _expiresAt != null && _expiresAt!.isBefore(DateTime.now());
    final active = _isPro && !isExpired;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text('Ijwi Pro', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w500))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // Hero
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [gold, const Color(0xFFF0C060)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            const Icon(LucideIcons.crown, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text('Ijwi Pro', style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 6),
            Text(active ? 'Your subscription is active' : 'Unlock the full Ijwi experience', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
            if (active && _expiresAt != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('Renews ${DateFormat('MMM d, yyyy').format(_expiresAt!)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 24),

        // Price
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Monthly', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Billed via Mobile Money', style: TextStyle(fontSize: 12, color: text3)),
            ]),
            const Spacer(),
            Text('2,000', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: gold)),
            Text(' RWF', style: TextStyle(fontSize: 13, color: text3)),
          ]),
        ),

        const SizedBox(height: 24),

        // Features
        Text('WHAT YOU GET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: text3)),
        const SizedBox(height: 12),
        _Feature(icon: LucideIcons.infinity, text: 'Unlimited Sparks uploads', gold: gold, surface: surface, border: border),
        _Feature(icon: LucideIcons.lock_open, text: 'Access all Pro-only content', gold: gold, surface: surface, border: border),
        _Feature(icon: LucideIcons.zap, text: 'Priority in Questions & feed', gold: gold, surface: surface, border: border),
        _Feature(icon: LucideIcons.badge_check, text: 'Pro badge on your profile', gold: gold, surface: surface, border: border),
        _Feature(icon: LucideIcons.palette, text: 'Custom chat backgrounds', gold: gold, surface: surface, border: border),
        _Feature(icon: LucideIcons.megaphone, text: 'Amplify events for free', gold: gold, surface: surface, border: border),

        const SizedBox(height: 28),

        // Subscribe button
        if (!active)
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: gold, foregroundColor: const Color(0xFF1A1814),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Subscribe via MoMo — 2,000 RWF/mo', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700)),
          )),

        if (active)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(LucideIcons.circle_check_big, size: 18, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(child: Text('You have full access to all Pro features.', style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w500))),
            ]),
          ),

        const SizedBox(height: 40),
      ]),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color gold, surface, border;
  const _Feature({required this.icon, required this.text, required this.gold, required this.surface, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 0.5)),
      child: Row(children: [
        Icon(icon, size: 18, color: gold),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500))),
        Icon(LucideIcons.check, size: 16, color: gold),
      ]),
    );
  }
}
