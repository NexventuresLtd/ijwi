import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _logoSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _logoSlide = Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _textFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 0.8, curve: Curves.easeOut)),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IjwiColors.darkBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoFade,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: IjwiColors.darkGold.withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: IjwiColors.darkGold.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App name
            FadeTransition(
              opacity: _logoFade,
              child: Text(
                'ijwi',
                style: GoogleFonts.poppins(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: IjwiColors.darkGold,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tagline
            FadeTransition(
              opacity: _textFade,
              child: Text(
                'Your voice matters.',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: IjwiColors.darkText2,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Subtle loading indicator
            FadeTransition(
              opacity: _textFade,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: IjwiColors.darkGold.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom message
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: FadeTransition(
            opacity: _textFade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'A safe space for faith & stories',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: IjwiColors.darkText3,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Built by Nexventures',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: IjwiColors.darkGold.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
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
