import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import 'package:intl/intl.dart';

class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});
  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _useBiometrics = false;
  bool _usePin = false;
  bool _usePattern = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSettings();
  }

  Future<void> _checkBiometrics() async {
    try {
      _canCheckBiometrics = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _loadSettings() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      final res = await supabase.from('profiles').select('wallet_biometrics_enabled, wallet_pin_hash').eq('id', user.id).single();
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final patternStr = prefs.getString('wallet_pattern');
        setState(() {
          _useBiometrics = res['wallet_biometrics_enabled'] ?? false;
          _usePin = res['wallet_pin_hash'] != null && res['wallet_pin_hash'].toString().isNotEmpty;
          _usePattern = patternStr != null && patternStr.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet settings: $e');
    }
  }



  void _showPdfOptionsSheet() {
    String selectedPeriod = 'All Time';
    String selectedType = 'All';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download Statement', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Period', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).hintColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['All Time', 'This Month', 'Last 30 Days', 'Last 7 Days'].map((p) => ChoiceChip(
                    label: Text(p),
                    selected: selectedPeriod == p,
                    onSelected: (val) { if (val) setStateSheet(() => selectedPeriod = p); },
                  )).toList(),
                ),
                const SizedBox(height: 16),
                Text('Type', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).hintColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Cash-ins', 'Cash-outs'].map((t) => ChoiceChip(
                    label: Text(t),
                    selected: selectedType == t,
                    onSelected: (val) { if (val) setStateSheet(() => selectedType = t); },
                  )).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _generatePdfStatement(selectedPeriod, selectedType);
                    },
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Generate PDF', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdfStatement(String period, String type) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      DateTime? startDate;
      final now = DateTime.now();
      if (period == 'This Month') startDate = DateTime(now.year, now.month, 1);
      if (period == 'Last 30 Days') startDate = now.subtract(const Duration(days: 30));
      if (period == 'Last 7 Days') startDate = now.subtract(const Duration(days: 7));

      final eventsRes = await supabase.from('events').select('id').eq('organizer_id', uid);
      final eventIds = (eventsRes as List).map((e) => e['id']).toList();

      List<Map<String, dynamic>> transactions = [];

      if ((type == 'All' || type == 'Cash-ins') && eventIds.isNotEmpty) {
        var query = supabase.from('event_bookings').select('created_at, payment_status, amount, events(title, ticket_price), ticket_tiers(name, price)').inFilter('event_id', eventIds).eq('payment_status', 'completed');
        if (startDate != null) query = query.gte('created_at', startDate.toIso8601String());
        
        final bookings = await query;
        for (final b in bookings as List) {
          final price = b['amount'] ?? b['ticket_tiers']?['price'] ?? b['events']?['ticket_price'] ?? 0;
          final net = (price * 0.96).floorToDouble(); // after 4% fees
          final eventTitle = b['events']?['title'] ?? 'Event';
          final tierName = b['ticket_tiers']?['name'] ?? 'Ticket';
          
          transactions.add({
            'date': DateTime.parse(b['created_at']).toLocal(),
            'amount': '+${net.toInt()}',
            'type': '$eventTitle ($tierName)',
            'status': 'completed',
          });
        }
      }

      if (type == 'All' || type == 'Cash-outs') {
        var query = supabase.from('organizer_payouts').select('created_at, amount, status').eq('user_id', uid);
        if (startDate != null) query = query.gte('created_at', startDate.toIso8601String());
        
        final payouts = await query;
        for (final p in payouts as List) {
          transactions.add({
            'date': DateTime.parse(p['created_at']).toLocal(),
            'amount': '-${p['amount']}',
            'type': 'Cash-out',
            'status': p['status'] ?? 'completed',
          });
        }
      }

      transactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      final pdf = pw.Document();
      final font = await PdfGoogleFonts.poppinsRegular();
      final boldFont = await PdfGoogleFonts.poppinsBold();

      final pdfGold = PdfColor.fromHex('#C8922A');

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Ijwi Wallet Statement', style: pw.TextStyle(font: boldFont, fontSize: 24, color: pdfGold)),
                pw.SizedBox(height: 10),
                pw.Text('Generated: ${DateFormat.yMMMd().format(now)}', style: pw.TextStyle(font: font, fontSize: 14)),
                pw.Text('Period: $period | Type: $type', style: pw.TextStyle(font: font, fontSize: 14)),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Date', 'Type', 'Amount (RWF)', 'Status'],
                  data: transactions.map((t) => [
                    DateFormat.yMd().add_Hm().format(t['date']),
                    t['type'],
                    t['amount'],
                    t['status']
                  ]).toList(),
                  headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: pdfGold),
                  cellStyle: pw.TextStyle(font: font),
                ),
              ],
            );
          },
        ),
      );

      if (mounted) Navigator.pop(context); // Close loading
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'ijwi_wallet_statement.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final gold = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text('Wallet Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cashout Security', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: gold)),
          const SizedBox(height: 16),
          Material(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (_canCheckBiometrics)
                  ListTile(
                    title: Text('Biometrics (Face/Fingerprint)', style: GoogleFonts.poppins(fontSize: 15)),
                    subtitle: Text(_useBiometrics ? 'Configured' : 'Not setup', style: TextStyle(color: _useBiometrics ? Colors.green : Colors.grey)),
                    trailing: const Icon(LucideIcons.chevron_right),
                    onTap: () => context.push('/wallet/settings/biometrics').then((_) => _loadSettings()),
                  ),
                ListTile(
                  title: Text('PIN Code', style: GoogleFonts.poppins(fontSize: 15)),
                  subtitle: Text(_usePin ? 'Configured' : 'Not setup', style: TextStyle(color: _usePin ? Colors.green : Colors.grey)),
                  trailing: const Icon(LucideIcons.chevron_right),
                  onTap: () => context.push('/wallet/settings/pin').then((_) => _loadSettings()),
                ),
                ListTile(
                  title: Text('Pattern Lock', style: GoogleFonts.poppins(fontSize: 15)),
                  subtitle: Text(_usePattern ? 'Configured' : 'Not setup', style: TextStyle(color: _usePattern ? Colors.green : Colors.grey)),
                  trailing: const Icon(LucideIcons.chevron_right),
                  onTap: () => context.push('/wallet/settings/pattern').then((_) => _loadSettings()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Reports & History', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: gold)),
          const SizedBox(height: 16),
          Material(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(LucideIcons.download),
              title: Text('Download Statement (PDF)', style: GoogleFonts.poppins(fontSize: 15)),
              trailing: const Icon(LucideIcons.chevron_right),
              onTap: _showPdfOptionsSheet,
            ),
          ),
          
          if (_usePin || _usePattern) ...[
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(LucideIcons.lock, size: 56, color: gold)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .shimmer(duration: 2.seconds)
                    .shake(hz: 2, curve: Curves.easeInOut),
                  const SizedBox(height: 12),
                  Text('Security is Configured', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: gold)),
                  const SizedBox(height: 8),
                  Text('Your wallet is protected by a security code.', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.refresh_cw, size: 16),
                    label: Text('Reset Security', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                    ),
                    onPressed: () async {
                      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                      try {
                        final user = supabase.auth.currentUser;
                        if (user?.email != null) {
                          await supabase.auth.signInWithOtp(email: user!.email!);
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          context.push('/wallet/security_reset');
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
