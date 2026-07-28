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

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final phone = _phoneCtrl.text.trim();
    
    if (amount <= 0 || amount > widget.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number required')));
      return;
    }

    final bool authenticated = await _authenticateUser();
    if (!authenticated) return;

    _executeCashout(amount, phone);
  }

  Future<bool> _authenticateUser() async {
    final options = <String>[];
    if (_useBiometrics) options.add('Biometrics');
    if (_configuredPin != null) options.add('PIN');
    if (_configuredPattern != null) options.add('Pattern');

    if (options.isEmpty) return true; // No security configured

    String? selectedOption;
    if (options.length == 1) {
      selectedOption = options.first;
    } else {
      selectedOption = await _showSecurityChooser(options);
    }

    if (selectedOption == null) return false;

    if (selectedOption == 'Biometrics') {
      try {
        final authenticated = await auth.authenticate(
          localizedReason: 'Authenticate to confirm cashout',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
        );
        return authenticated;
      } catch (e) {
        debugPrint(e.toString());
        return false;
      }
    } else if (selectedOption == 'PIN') {
      return await _showPinPrompt();
    } else if (selectedOption == 'Pattern') {
      return await _showPatternPrompt();
    }

    return false;
  }

  Future<String?> _showSecurityChooser(List<String> options) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final gold = Theme.of(ctx).colorScheme.primary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose Authentication', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  IconData icon;
                  if (opt == 'Biometrics') icon = Icons.fingerprint;
                  else if (opt == 'PIN') icon = Icons.dialpad;
                  else icon = LucideIcons.grip;

                  return ListTile(
                    leading: Icon(icon, color: gold),
                    title: Text(opt, style: GoogleFonts.poppins(fontSize: 15)),
                    onTap: () => Navigator.pop(ctx, opt),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showPinPrompt() async {
    bool authenticated = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String enteredPin = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
            final gold = Theme.of(ctx).colorScheme.primary;

            Widget buildKeypadButton(String digit) {
              return InkWell(
                onTap: () {
                  setModalState(() {
                    if (enteredPin.length < 4) enteredPin += digit;
                    if (enteredPin.length == 4) {
                      final bytes = utf8.encode(enteredPin);
                      final hash = sha256.convert(bytes).toString();
                      if (hash == _configuredPin) {
                        // Success, reset attempts
                        supabase.from('profiles').update({'security_failed_attempts': 0}).eq('id', supabase.auth.currentUser!.id);
                        authenticated = true;
                        Navigator.pop(ctx);
                      } else {
                        enteredPin = '';
                        _handleFailedAttempt(ctx);
                      }
                    }
                  });
                },
                child: Container(
                  width: 70, height: 70,
                  alignment: Alignment.center,
                  child: Text(digit, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600)),
                ),
              );
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Enter PIN', style: GoogleFonts.poppins(fontSize: 20)),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 15, height: 15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < enteredPin.length ? gold : Colors.transparent,
                          border: Border.all(color: gold, width: 2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 50),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [buildKeypadButton('1'), buildKeypadButton('2'), buildKeypadButton('3')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [buildKeypadButton('4'), buildKeypadButton('5'), buildKeypadButton('6')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [buildKeypadButton('7'), buildKeypadButton('8'), buildKeypadButton('9')]),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 70),
                      buildKeypadButton('0'),
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            if (enteredPin.isNotEmpty) {
                              enteredPin = enteredPin.substring(0, enteredPin.length - 1);
                            }
                          });
                        },
                        child: Container(
                          width: 70, height: 70,
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.delete),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            );
          }
        );
      }
    );
    return authenticated;
  }

  Future<void> _handleFailedAttempt(BuildContext ctx) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final res = await supabase.from('profiles').select('security_failed_attempts').eq('id', user.id).single();
      int attempts = (res['security_failed_attempts'] ?? 0) + 1;
      await supabase.from('profiles').update({'security_failed_attempts': attempts}).eq('id', user.id);
      
      if (attempts >= 3) {
        Navigator.pop(ctx);
        // Call edge function to send OTP
        supabase.functions.invoke('send-security-otp').catchError((e) => debugPrint(e.toString()));
        context.go('/wallet/security_reset');
      } else {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Incorrect PIN. ${3 - attempts} attempts left.')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<bool> _showPatternPrompt() async {
    bool authenticated = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
        final gold = Theme.of(ctx).colorScheme.primary;

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Draw Pattern', style: GoogleFonts.poppins(fontSize: 20)),
              const SizedBox(height: 30),
              SizedBox(
                height: 350,
                child: PatternLock(
                  selectedColor: gold,
                  pointRadius: 8,
                  dimension: 3,
                  relativePadding: 0.7,
                  fillPoints: true,
                  onInputComplete: (List<int> input) {
                    if (input.join(',') == _configuredPattern) {
                      authenticated = true;
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Incorrect Pattern')));
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
    return authenticated;
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cashout requested successfully!')));
          if (mounted) {
            context.pushReplacement('/wallet/cashout/success', extra: amount);
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res.data}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cashout failed: $e')));
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
