import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class WalletBiometricsScreen extends StatefulWidget {
  const WalletBiometricsScreen({super.key});
  @override
  State<WalletBiometricsScreen> createState() => _WalletBiometricsScreenState();
}

class _WalletBiometricsScreenState extends State<WalletBiometricsScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLoading = true;
  bool _isConfigured = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final res = await supabase.from('profiles').select('wallet_biometrics_enabled').eq('id', user.id).single();
      setState(() {
        _isConfigured = res['wallet_biometrics_enabled'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _enableBiometrics() async {
    if (mounted) setState(() => _error = '');
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        if (mounted) setState(() => _error = 'Biometrics not enrolled on this device. Please set up Fingerprint or Face ID in phone settings.');
        return;
      }
      final authenticated = await _auth.authenticate(
        localizedReason: 'Enable Biometrics for Wallet Cashout',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (!mounted) return;
      if (authenticated) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase.from('profiles').update({'wallet_biometrics_enabled': true}).eq('id', user.id);
          if (mounted) {
            setState(() {
              _isConfigured = true;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _triggerReset() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final user = supabase.auth.currentUser;
      if (user?.email != null) {
        await supabase.auth.signInWithOtp(email: user!.email!);
      }
      if (mounted) {
        Navigator.pop(context); // Close dialog
        context.push('/wallet/security_reset').then((_) => _checkStatus());
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Biometrics Setup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: _isConfigured
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.check, size: 64, color: gold)
                        .animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
                      const SizedBox(height: 24),
                      Text('Biometrics is Setup', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('Your wallet is protected by biometrics.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
                      const SizedBox(height: 48),
                      ElevatedButton.icon(
                        icon: const Icon(LucideIcons.refresh_cw, size: 16),
                        label: Text('Reset Security', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: _triggerReset,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 64, color: gold),
                      const SizedBox(height: 24),
                      Text('Enable Biometrics', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                        'Secure your wallet using your fingerprint or Face ID.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 40),
                      if (_error.isNotEmpty) Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(_error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _enableBiometrics,
                          child: Text('Enable Biometrics', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
    );
  }
}
