import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  static const _steps = [
    {
      'icon': LucideIcons.flame,
      'title': 'Welcome to Ijwi',
      'subtitle': 'The Voice',
      'body': 'A faith space for African Christian youth — share testimonies, prayers, devotionals, and spoken word. Your voice was made for this moment.',
      'cta': 'Next →',
    },
    {
      'icon': LucideIcons.venetian_mask,
      'title': 'You can be anonymous',
      'subtitle': 'Your voice. Your rules.',
      'body': 'Every post can be shared anonymously using just your voice name. No one will know it\'s you — unless you choose to reveal yourself.',
      'cta': 'Next →',
    },
    {
      'icon': LucideIcons.sparkles,
      'title': 'Grow as you share',
      'subtitle': 'Your community awaits.',
      'body': 'Post testimonies, devotionals, prayers, and spoken word. The more you share, the deeper your impact in the community.',
      'cta': 'Start sharing →',
    },
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = IjwiColors.darkGold;
    final current = _steps[_step];

    return Scaffold(
      backgroundColor: IjwiColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const Spacer(flex: 2),

            // Progress dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Container(
              width: i == _step ? 24 : 8, height: 8, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: i == _step ? gold : IjwiColors.darkText3.withValues(alpha: 0.3)),
            ))),

            const SizedBox(height: 40),

            // Icon
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.12), border: Border.all(color: gold.withValues(alpha: 0.3))),
              child: Icon(current['icon'] as IconData, size: 32, color: gold),
            ),

            const SizedBox(height: 28),

            // Subtitle
            Text(current['subtitle'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: gold)),

            const SizedBox(height: 8),

            // Title
            Text(current['title'] as String, style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w400, color: IjwiColors.darkText), textAlign: TextAlign.center),

            const SizedBox(height: 16),

            // Body
            Text(current['body'] as String, style: GoogleFonts.poppins(fontSize: 15, color: IjwiColors.darkText2, height: 1.6), textAlign: TextAlign.center),

            const Spacer(flex: 3),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: Text(current['cta'] as String, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 12),

            // Skip
            if (_step < _steps.length - 1)
              TextButton(
                onPressed: widget.onComplete,
                child: Text('Skip', style: TextStyle(color: IjwiColors.darkText3, fontSize: 14)),
              )
            else
              const SizedBox(height: 40),

            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}
