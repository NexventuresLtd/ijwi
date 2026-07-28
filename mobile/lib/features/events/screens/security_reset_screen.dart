import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class SecurityResetScreen extends StatefulWidget {
  const SecurityResetScreen({super.key});

  @override
  State<SecurityResetScreen> createState() => _SecurityResetScreenState();
}

class _SecurityResetScreenState extends State<SecurityResetScreen> {
  String _enteredOtp = '';
  bool _isLoading = false;
  String _error = '';

  void _onDigit(String digit) {
    if (_isLoading) return;
    setState(() {
      _error = '';
      if (_enteredOtp.length < 4) _enteredOtp += digit;
      if (_enteredOtp.length == 4) {
        _verifyOtp();
      }
    });
  }

  void _onDelete() {
    if (_isLoading) return;
    setState(() {
      _error = '';
      if (_enteredOtp.isNotEmpty) {
        _enteredOtp = _enteredOtp.substring(0, _enteredOtp.length - 1);
      }
    });
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Not logged in');
      }

      final res = await supabase
          .from('profiles')
          .select('security_otp_code, security_otp_expires_at')
          .eq('id', user.id)
          .single();

      final storedHash = res['security_otp_code'];
      final expiresAtStr = res['security_otp_expires_at'];

      if (storedHash == null || expiresAtStr == null) {
        throw Exception('No OTP request found. Please contact support.');
      }

      final expiresAt = DateTime.parse(expiresAtStr);
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please request a new one.');
      }

      final bytes = utf8.encode(_enteredOtp);
      final hash = sha256.convert(bytes).toString();

      if (hash == storedHash) {
        // Success! Reset security.
        await supabase.from('profiles').update({
          'wallet_pin_hash': null,
          'wallet_biometrics_enabled': false,
          'security_failed_attempts': 0,
          'security_otp_code': null,
          'security_otp_expires_at': null,
        }).eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security reset successfully!')));
          context.go('/wallet/settings');
        }
      } else {
        setState(() {
          _error = 'Incorrect OTP.';
          _enteredOtp = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _enteredOtp = '';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      await supabase.functions.invoke('send-security-otp');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new OTP has been sent to your email.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to resend OTP: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildKeypadButton(String digit) {
    return InkWell(
      onTap: () => _onDigit(digit),
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
    final gold = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Security', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.shield_alert, size: 64, color: Colors.redAccent),
          const SizedBox(height: 20),
          Text('Security Locked', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'You have entered the wrong PIN too many times. An email has been sent with a 4-digit code to reset your security.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          if (_error.isNotEmpty) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(_error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final filled = index < _enteredOtp.length;
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
            }),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _resendOtp,
            child: Text('Resend Code', style: TextStyle(color: gold)),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildKeypadButton('1'), _buildKeypadButton('2'), _buildKeypadButton('3')]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildKeypadButton('4'), _buildKeypadButton('5'), _buildKeypadButton('6')]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildKeypadButton('7'), _buildKeypadButton('8'), _buildKeypadButton('9')]),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 80),
                  _buildKeypadButton('0'),
                  InkWell(
                    onTap: _onDelete,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 80, height: 80,
                      alignment: Alignment.center,
                      child: const Icon(LucideIcons.delete),
                    ),
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
