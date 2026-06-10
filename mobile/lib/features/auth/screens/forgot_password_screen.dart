import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;
import '../../../core/supabase.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _reset() async {
    setState(() { _loading = true; _error = null; });
    try {
      await supabase.auth.resetPasswordForEmail(_email.text.trim());
      setState(() => _sent = true);
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
              Text("Enter your email and we'll send you a link.", style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 28),
              if (_sent) ...[
                Icon(Icons.mark_email_read_outlined, size: 48, color: gold),
                const SizedBox(height: 12),
                Text('Check your inbox at ${_email.text}', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ] else ...[
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email address')),
                if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _reset, child: Text(_loading ? 'Sending...' : 'Send reset link →'))),
              ],
              const SizedBox(height: 24),
              TextButton(onPressed: () => context.go('/auth/login'), child: Text('← Back to sign in', style: TextStyle(color: gold))),
            ]),
          ),
        ),
      ),
    );
  }
}
