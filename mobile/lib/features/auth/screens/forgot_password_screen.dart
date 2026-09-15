import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/supabase.dart';

enum ForgotPasswordStep { email, otp, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  
  ForgotPasswordStep _step = ForgotPasswordStep.email;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _sendOtp() async {
    final emailStr = _email.text.trim();
    if (emailStr.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.resetPasswordForEmail(emailStr);
      setState(() => _step = ForgotPasswordStep.otp);
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otpStr = _otp.text.trim();
    if (otpStr.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: otpStr,
        email: _email.text.trim(),
      );
      setState(() => _step = ForgotPasswordStep.newPassword);
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    final passStr = _newPassword.text.trim();
    if (passStr.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.updateUser(UserAttributes(password: passStr));
      await supabase.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully! Please sign in with your new password.')));
        context.go('/auth/login');
      }
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Reset password', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              
              if (_step == ForgotPasswordStep.email) ...[
                Text("Enter your email and we'll send you an OTP.", style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email address')),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _sendOtp, child: Text(_loading ? 'Sending...' : 'Send OTP →'))),
              ] else if (_step == ForgotPasswordStep.otp) ...[
                Text('Enter the 8-digit code sent to ${_email.text}', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '00000000', hintStyle: TextStyle(letterSpacing: 8)), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 8)),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _verifyOtp, child: Text(_loading ? 'Verifying...' : 'Verify OTP'))),
              ] else ...[
                Text('Enter your new secure password.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextField(
                  controller: _newPassword,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _updatePassword, child: Text(_loading ? 'Updating...' : 'Update Password'))),
              ],

              const SizedBox(height: 24),
              if (_step == ForgotPasswordStep.email)
                TextButton(onPressed: () => context.go('/auth/login'), child: Text('← Back to sign in', style: TextStyle(color: gold)))
              else
                TextButton(onPressed: () => setState(() { _step = ForgotPasswordStep.email; _error = null; }), child: Text('Start over', style: TextStyle(color: gold))),
            ]),
          ),
        ),
      ),
    );
  }
}
