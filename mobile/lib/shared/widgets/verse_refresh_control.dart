import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/verses.dart';

class VerseRefreshControl extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const VerseRefreshControl({super.key, required this.onRefresh});

  @override
  State<VerseRefreshControl> createState() => _VerseRefreshControlState();
}

class _VerseRefreshControlState extends State<VerseRefreshControl> {
  late Map<String, String> _currentVerse;

  @override
  void initState() {
    super.initState();
    _currentVerse = Verses.todaysVerse();
  }

  void _generateNewVerse() {
    setState(() {
      _currentVerse = Verses.randomVerse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return CupertinoSliverRefreshControl(
      onRefresh: () async {
        _generateNewVerse();
        await widget.onRefresh();
      },
      refreshIndicatorExtent: 120,
      refreshTriggerPullDistance: 140,
      builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
        // Prevent layout overflow if pulled too far
        final clampedExtent = pulledExtent.clamp(0.0, 300.0);
        final double opacity = (clampedExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
        
        return ClipRect(
          child: Opacity(
            opacity: opacity,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '"${_currentVerse['text']}"',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '— ${_currentVerse['reference']?.toUpperCase()}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: textColor.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              ),
            ),
          ),
        );
      },
    );
  }
}
