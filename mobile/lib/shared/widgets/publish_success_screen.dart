import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme.dart';

class PublishSuccessScreen extends StatelessWidget {
  final String postId;
  final String type;
  const PublishSuccessScreen({super.key, required this.postId, required this.type});

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
              Text('Published!', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Your $type is now live.', style: TextStyle(fontSize: 15, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => context.go('/feed'),
                style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1814), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: Text('See Feed', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}
