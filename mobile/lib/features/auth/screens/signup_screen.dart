import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;
import '../../../core/supabase.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _voiceName = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _done = false;

  Future<void> _signup() async {
    if (_voiceName.text.trim().isEmpty) { setState(() => _error = 'Choose a voice name.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await supabase.auth.signUp(email: _email.text.trim(), password: _password.text, data: {'voice_name': _voiceName.text.trim()});
      if (res.user != null) {
        await supabase.from('profiles').upsert({'id': res.user!.id, 'voice_name': _voiceName.text.trim()});
        setState(() => _done = true);
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
            child: _done
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline, size: 56, color: gold),
                    const SizedBox(height: 16),
                    Text('Check your inbox', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 8),
                    Text('Confirm your email to start writing.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    TextButton(onPressed: () => context.go('/auth/login'), child: Text('← Back to sign in', style: TextStyle(color: gold))),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('ijwi', style: GoogleFonts.roboto(fontSize: 36, fontWeight: FontWeight.w700, color: gold)),
                    const SizedBox(height: 8),
                    Text('Find your voice', style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 32),
                    TextField(controller: _voiceName, decoration: const InputDecoration(hintText: 'Voice name')),
                    const SizedBox(height: 12),
                    TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email address')),
                    const SizedBox(height: 12),
                    TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'Password (6+ characters)')),
                    if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))],
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _signup, child: Text(_loading ? 'Creating...' : 'Create account →'))),
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Already have an account? ', style: Theme.of(context).textTheme.bodyMedium),
                      GestureDetector(onTap: () => context.go('/auth/login'), child: Text('Sign in', style: TextStyle(color: gold, fontWeight: FontWeight.w600))),
                    ]),
                  ]),
          ),
        ),
      ),
    );
  }
}
