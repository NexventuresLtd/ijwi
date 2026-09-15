import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class WalletSecurityHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Authenticate the user using Biometrics, PIN, or Pattern.
  /// If no security is configured, returns true automatically.
  static Future<bool> authenticate(BuildContext context, {String reason = 'Authenticate to continue'}) async {
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    // Fetch security settings
    final res = await supabase.from('profiles').select('wallet_biometrics_enabled, wallet_pin_hash').eq('id', user.id).single();
    final prefs = await SharedPreferences.getInstance();
    
    final bool useBiometrics = res['wallet_biometrics_enabled'] ?? false;
    final String? configuredPin = res['wallet_pin_hash'];
    final String? configuredPattern = prefs.getString('wallet_pattern');

    final options = <String>[];
    if (useBiometrics) options.add('Biometrics');
    if (configuredPin != null) options.add('PIN');
    if (configuredPattern != null) options.add('Pattern');

    if (options.isEmpty) return true; // No security configured

    String? selectedOption;
    if (options.length == 1) {
      selectedOption = options.first;
    } else {
      selectedOption = await _showSecurityChooser(context, options);
    }

    if (selectedOption == null) return false;

    if (selectedOption == 'Biometrics') {
      try {
        return await _auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );
      } catch (e) {
        debugPrint(e.toString());
        return false;
      }
    } else if (selectedOption == 'PIN') {
      return await _showPinPrompt(context, configuredPin!);
    } else if (selectedOption == 'Pattern') {
      return await _showPatternPrompt(context, configuredPattern!);
    }

    return false;
  }

  static Future<String?> _showSecurityChooser(BuildContext context, List<String> options) async {
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

  static Future<bool> _showPinPrompt(BuildContext context, String configuredPin) async {
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
                      if (hash == configuredPin) {
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

  static Future<void> _handleFailedAttempt(BuildContext ctx) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final res = await supabase.from('profiles').select('security_failed_attempts').eq('id', user.id).single();
      int attempts = (res['security_failed_attempts'] ?? 0) + 1;
      await supabase.from('profiles').update({'security_failed_attempts': attempts}).eq('id', user.id);
      
      if (attempts >= 3) {
        if (ctx.mounted) {
          Navigator.pop(ctx);
          // Call edge function to send OTP
          supabase.functions.invoke('send-security-otp').catchError((e) => debugPrint(e.toString()));
          ctx.go('/wallet/security_reset');
        }
      } else {
        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Incorrect PIN. ${3 - attempts} attempts left.')));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  static Future<bool> _showPatternPrompt(BuildContext context, String configuredPattern) async {
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
                  notSelectedColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white70 : Colors.black38,
                  pointRadius: 8,
                  dimension: 3,
                  relativePadding: 0.7,
                  fillPoints: true,
                  onInputComplete: (List<int> input) {
                    if (input.join(',') == configuredPattern) {
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
}
