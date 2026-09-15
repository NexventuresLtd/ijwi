import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase.dart';

class WalletPatternScreen extends StatefulWidget {
  const WalletPatternScreen({super.key});
  @override
  State<WalletPatternScreen> createState() => _WalletPatternScreenState();
}

class _WalletPatternScreenState extends State<WalletPatternScreen> {
  List<int>? _pattern;
  bool _isConfirming = false;
  String _error = '';
  bool _isConfigured = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patternStr = prefs.getString('wallet_pattern');
      if (patternStr != null && patternStr.isNotEmpty) {
        _isConfigured = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _savePattern(List<int> pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_pattern', pattern.join(','));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern successfully saved!')));
      Navigator.pop(context);
    }
  }

  Future<void> _removePattern() async {
    final user = supabase.auth.currentUser;
    if (user?.email == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await supabase.auth.signInWithOtp(email: user!.email!);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
      }
      return;
    }
    
    if (mounted) Navigator.pop(context); // pop loading

    final otpCtrl = TextEditingController();
    bool verifying = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text('Security Verification', style: GoogleFonts.poppins()),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Enter the 8-digit code sent to ${user.email} to remove your pattern.', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '00000000', hintStyle: TextStyle(letterSpacing: 8)),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 8),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: verifying ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
                TextButton(
                  onPressed: verifying ? null : () async {
                    if (otpCtrl.text.trim().length != 6) return;
                    setState(() => verifying = true);
                    try {
                      await supabase.auth.verifyOTP(
                        type: OtpType.magiclink,
                        token: otpCtrl.text.trim(),
                        email: user.email!,
                      );
                      
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('wallet_pattern');
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern removed successfully!')));
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      setState(() => verifying = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
                      }
                    }
                  },
                  child: verifying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify & Remove', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isConfirming ? 'Confirm your Pattern' : 'Create a Pattern';
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Pattern', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (!_isConfigured) TextButton(onPressed: _removePattern, child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _isConfigured
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.check, size: 64, color: Theme.of(context).colorScheme.primary)
                    .animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
                  const SizedBox(height: 24),
                  Text('Pattern is Setup', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Your wallet is protected by a pattern.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(LucideIcons.refresh_cw, size: 16),
                    label: Text('Reset Security', style: GoogleFonts.poppins()),
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
            )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 20)),
          const SizedBox(height: 10),
          if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 30),
          Expanded(
            child: PatternLock(
              selectedColor: gold,
              notSelectedColor: isDark ? Colors.white70 : Colors.black38,
              pointRadius: 8,
              showInput: true,
              dimension: 3,
              relativePadding: 0.7,
              selectThreshold: 25,
              fillPoints: true,
              onInputComplete: (List<int> input) {
                if (input.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 4 points required!')));
                  return;
                }
                setState(() {
                  _error = '';
                  if (!_isConfirming) {
                    _pattern = input;
                    _isConfirming = true;
                  } else {
                    if (_pattern != null && _pattern!.join(',') == input.join(',')) {
                      _savePattern(input);
                    } else {
                      _error = 'Patterns do not match. Try again.';
                      _isConfirming = false;
                      _pattern = null;
                    }
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
