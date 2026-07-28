import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/theme.dart';

class CashoutSuccessScreen extends StatefulWidget {
  final double amount;
  const CashoutSuccessScreen({super.key, required this.amount});

  @override
  State<CashoutSuccessScreen> createState() => _CashoutSuccessScreenState();
}

class _CashoutSuccessScreenState extends State<CashoutSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold, width: 2)),
                    child: Icon(LucideIcons.check, size: 48, color: gold),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Cashout Processing!', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                  'Your request to withdraw ${widget.amount.toInt()} RWF has been successfully initiated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop(true); // Return to Wallet screen and trigger reload
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF1A1814),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: Text('Back to Wallet', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
