import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../utils/wallet_security_helper.dart';

class CashoutScreen extends StatefulWidget {
  final double availableBalance;
  const CashoutScreen({super.key, required this.availableBalance});
  @override
  State<CashoutScreen> createState() => _CashoutScreenState();
}

class _CashoutScreenState extends State<CashoutScreen> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  
  bool _useBiometrics = false;
  String? _configuredPin;
  String? _configuredPattern;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase.from('profiles').select('wallet_biometrics_enabled, wallet_pin_hash, security_failed_attempts').eq('id', user.id).single();
      final prefs = await SharedPreferences.getInstance();
      final patternStr = prefs.getString('wallet_pattern');
      if (mounted) {
        setState(() {
          _useBiometrics = res['wallet_biometrics_enabled'] ?? false;
          _configuredPin = res['wallet_pin_hash'];
          _configuredPattern = patternStr;
          if ((res['security_failed_attempts'] ?? 0) >= 3) {
            // Immediately kick to reset screen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/wallet/settings/reset');
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _showErrorPopup(String title, String message) {
    if (!mounted) return;
    final gold = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(LucideIcons.triangle_alert, color: Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600))),
        ]),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: gold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final phone = _phoneCtrl.text.trim();
    
    if (amount < 800) {
      _showErrorPopup(
        'Minimum Amount',
        'The minimum cashout amount is 800 RWF to cover processing fees. Please enter an amount of 800 RWF or more.',
      );
      return;
    }
    if (amount > 10000000) {
      _showErrorPopup(
        'Maximum Exceeded',
        'The maximum cashout amount is 10,000,000 RWF per transaction.',
      );
      return;
    }
    if (amount > widget.availableBalance) {
      _showErrorPopup(
        'Insufficient Balance',
        'Your available balance is ${widget.availableBalance.toInt()} RWF. Please enter a lower amount.',
      );
      return;
    }
    if (phone.isEmpty) {
      _showErrorPopup('Phone Required', 'Please enter the mobile money number to receive your payout.');
      return;
    }

    final bool authenticated = await WalletSecurityHelper.authenticate(context, reason: 'Authenticate to confirm cashout');
    if (!authenticated) return;

    _executeCashout(amount, phone);
  }

  Future<void> _executeCashout(double amount, String phone) async {
    setState(() => _loading = true);
    try {
      final res = await supabase.functions.invoke('opuspay-cashout', body: {
        'amount': amount,
        'recipient_number': phone,
      });

      if (res.status == 200) {
        if (mounted) {
          context.pushReplacement('/wallet/cashout/success', extra: amount);
        }
      } else {
        String msg = 'Your payout could not be processed. Please try again later.';
        if (res.data is Map && res.data['error'] != null) {
          final raw = res.data['error'].toString();
          if (raw.contains('amount must be between')) {
            msg = 'The amount must be at least 800 RWF and no more than 10,000,000 RWF.';
          } else {
            msg = raw;
          }
        }
        if (mounted) _showErrorPopup('Cashout Failed', msg);
      }
    } catch (e) {
      if (mounted) _showErrorPopup('Cashout Error', 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final gold = Theme.of(context).colorScheme.primary;
    final text1 = isDark ? IjwiColors.darkText : IjwiColors.lightText;

    return Scaffold(
      appBar: AppBar(title: Text('Cashout Funds', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('Available Balance', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('${widget.availableBalance.toStringAsFixed(0)} RWF', style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: gold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: text1, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Amount (RWF)',
                labelStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: gold, width: 2)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: text1, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Mobile Money Number (e.g. 07...)',
                labelStyle: TextStyle(color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: gold, width: 2)),
              ),
            ),
            const SizedBox(height: 40),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Confirm Cashout', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
