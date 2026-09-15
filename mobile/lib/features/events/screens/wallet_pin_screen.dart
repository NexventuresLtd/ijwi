import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase.dart';

class WalletPinScreen extends StatefulWidget {
  const WalletPinScreen({super.key});
  @override
  State<WalletPinScreen> createState() => _WalletPinScreenState();
}

class _WalletPinScreenState extends State<WalletPinScreen> {
  String _pin = '';
  String _confirmPin = '';
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
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await supabase.from('profiles').select('wallet_pin_hash').eq('id', user.id).single();
        if (res['wallet_pin_hash'] != null && res['wallet_pin_hash'].toString().isNotEmpty) {
          _isConfigured = true;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _onDigit(String digit) {
    setState(() {
      _error = '';
      if (!_isConfirming) {
        if (_pin.length < 4) _pin += digit;
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            setState(() => _isConfirming = true);
          });
        }
      } else {
        if (_confirmPin.length < 4) _confirmPin += digit;
        if (_confirmPin.length == 4) {
          if (_pin == _confirmPin) {
            _savePin(_pin);
          } else {
            setState(() {
              _error = 'PINs do not match. Try again.';
              _pin = '';
              _confirmPin = '';
              _isConfirming = false;
            });
          }
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = '';
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  Future<void> _savePin(String pin) async {
    final bytes = utf8.encode(pin);
    final hash = sha256.convert(bytes).toString();
    try {
      await supabase.from('profiles').update({'wallet_pin_hash': hash}).eq('id', supabase.auth.currentUser!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN successfully saved!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving PIN: $e')));
      }
    }
  }

  Future<void> _removePin() async {
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
                  Text('Enter the 8-digit code sent to ${user.email} to remove your PIN.', style: const TextStyle(fontSize: 13)),
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
                      
                      await supabase.from('profiles').update({'wallet_pin_hash': null}).eq('id', user.id);
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN removed successfully!')));
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

  Widget _buildDot(bool filled) {
    final gold = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? gold : Colors.transparent,
        border: Border.all(color: gold, width: 2),
      ),
    );
  }

  Widget _buildKeypadButton(String digit, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _onDigit(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Text(digit, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isConfirming ? 'Confirm your PIN' : 'Create a 4-digit PIN';
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup PIN', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (!_isConfigured) TextButton(onPressed: _removePin, child: const Text('Remove', style: TextStyle(color: Colors.red))),
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
                  Text('PIN is Setup', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Your wallet is protected by a PIN.', style: TextStyle(color: Colors.grey)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) => _buildDot(index < currentLength)),
          ),
          const SizedBox(height: 50),
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKeypadButton('1'), _buildKeypadButton('2'), _buildKeypadButton('3'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKeypadButton('4'), _buildKeypadButton('5'), _buildKeypadButton('6'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildKeypadButton('7'), _buildKeypadButton('8'), _buildKeypadButton('9'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 80),
                  _buildKeypadButton('0'),
                  InkWell(
                    onTap: _onDelete,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      child: const Icon(Icons.backspace_outlined, size: 28),
                    ),
                  )
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}
