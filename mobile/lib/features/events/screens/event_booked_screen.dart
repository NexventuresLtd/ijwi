import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/theme.dart';

class EventBookedScreen extends StatelessWidget {
  const EventBookedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.3), width: 2)),
                child: Icon(LucideIcons.check, size: 36, color: gold),
              ),
              const SizedBox(height: 24),
              Text('Ticket Confirmed!', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Your spot has been reserved. You can view your ticket in the My Events tab.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => context.go('/my-events'),
                style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1814), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: Text('View My Tickets', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              )),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: TextButton(
                onPressed: () => context.go('/events'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('Back to Events', style: TextStyle(fontSize: 15, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2)),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}
