import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final url = barcode.rawValue!;
        // Expected format: https://ijwi.app/profile/<uuid>
        if (url.startsWith('https://ijwi.app/profile/')) {
          _scanned = true;
          final userId = url.split('/').last;
          _controller.stop();
          _showScannedProfile(userId);
          break;
        }
      }
    }
  }

  void _showScannedProfile(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScannedProfileSheet(userId: userId, onClosed: () {
        _scanned = false;
        _controller.start();
      }),
    ).whenComplete(() {
      if (mounted && _scanned) {
        _scanned = false;
        _controller.start();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    const double scanAreaSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          
          // Dark Overlay with transparent center using boxShadow trick
          Center(
            child: Container(
              width: scanAreaSize,
              height: scanAreaSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: gold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.75),
                    spreadRadius: 2000,
                  ),
                ],
              ),
            ),
          ),

          // UI Elements
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(LucideIcons.arrow_left, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Scan Profile',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Instructions Panel
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151515).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: gold.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(LucideIcons.qr_code, color: gold, size: 24),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Connect Instantly',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Align an Ijwi QR code within the frame to instantly view their profile and listen to their stories.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannedProfileSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onClosed;
  const _ScannedProfileSheet({required this.userId, required this.onClosed});

  @override
  State<_ScannedProfileSheet> createState() => _ScannedProfileSheetState();
}

class _ScannedProfileSheetState extends State<_ScannedProfileSheet> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await supabase.from('profiles').select('*').eq('id', widget.userId).maybeSingle();
      final uid = supabase.auth.currentUser?.id;
      bool following = false;
      if (uid != null && p != null) {
        final f = await supabase.from('follows').select('follower_id').eq('follower_id', uid).eq('following_id', widget.userId).maybeSingle();
        following = f != null;
      }
      if (mounted) setState(() { _profile = p; _isFollowing = following; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (_isFollowing) {
      await supabase.from('follows').delete().match({'follower_id': uid, 'following_id': widget.userId});
      setState(() => _isFollowing = false);
    } else {
      await supabase.from('follows').insert({'follower_id': uid, 'following_id': widget.userId});
      setState(() => _isFollowing = true);
      sendNotification(toUserId: widget.userId, type: 'follow', message: 'started following you');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 32),
          
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_profile == null)
            Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Profile not found', style: TextStyle(color: text3))))
          else ...[
            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold, width: 2)),
              child: ClipOval(
                child: _profile!['avatar_url'] != null && (_profile!['avatar_url'] as String).startsWith('http')
                  ? CachedNetworkImage(imageUrl: _profile!['avatar_url'], width: 80, height: 80, fit: BoxFit.cover)
                  : Center(child: Text((_profile!['voice_name'] ?? 'U')[0].toUpperCase(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: gold))),
              ),
            ),
            const SizedBox(height: 16),
            
            // Name
            Text(
              (_profile!['is_revealed'] == true && _profile!['real_name'] != null) ? _profile!['real_name'] : _profile!['voice_name'],
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_profile!['bio'] != null) ...[
              const SizedBox(height: 8),
              Text(_profile!['bio'], style: TextStyle(color: text3, fontSize: 14), textAlign: TextAlign.center, maxLines: 2),
            ],
            
            const SizedBox(height: 32),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing ? Colors.transparent : gold,
                      side: _isFollowing ? BorderSide(color: text3.withValues(alpha: 0.2)) : null,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_isFollowing ? 'Listening \u2713' : 'Listen', style: TextStyle(color: _isFollowing ? text3 : null)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onClosed();
                      context.push('/profile/${widget.userId}');
                    },
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('View Profile'),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}
