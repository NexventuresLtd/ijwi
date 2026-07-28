import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pattern_lock/pattern_lock.dart';

class WalletPatternScreen extends StatefulWidget {
  const WalletPatternScreen({super.key});
  @override
  State<WalletPatternScreen> createState() => _WalletPatternScreenState();
}

class _WalletPatternScreenState extends State<WalletPatternScreen> {
  List<int>? _pattern;
  bool _isConfirming = false;
  String _error = '';

  Future<void> _savePattern(List<int> pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallet_pattern', pattern.join(','));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern successfully saved!')));
      Navigator.pop(context);
    }
  }

  Future<void> _removePattern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_pattern');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pattern removed!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isConfirming ? 'Confirm your Pattern' : 'Create a Pattern';
    final gold = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Pattern', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: _removePattern, child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 20)),
          const SizedBox(height: 10),
          if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 30),
          Expanded(
            child: PatternLock(
              selectedColor: gold,
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
