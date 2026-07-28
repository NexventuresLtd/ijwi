import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/theme.dart';

class EventScannerScreen extends StatefulWidget {
  final String eventId;
  const EventScannerScreen({super.key, required this.eventId});

  @override
  State<EventScannerScreen> createState() => _EventScannerScreenState();
}

class _EventScannerScreenState extends State<EventScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  final supabase = Supabase.instance.client;
  bool _isProcessing = false;
  String? _lastScanned;

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code == _lastScanned) return;

    setState(() {
      _isProcessing = true;
      _lastScanned = code;
    });

    try {
      // Assuming the QR code contains the ticket ID
      final ticketId = code;
      
      // Verify ticket belongs to this event
      final res = await supabase
          .from('event_bookings')
          .select('id, checked_in, profiles(display_name, voice_name)')
          .eq('event_id', widget.eventId)
          .or('id.eq.$ticketId,ticket_code.eq.$ticketId')
          .maybeSingle();
          
      if (!mounted) return;

      if (res == null) {
        _showResult(false, 'Invalid ticket for this event');
      } else if (res['checked_in'] == true) {
        _showResult(false, 'Ticket already scanned (Attended)');
      } else {
        // Mark as attended
        await supabase
            .from('event_bookings')
            .update({
              'checked_in': true,
              'checked_in_at': DateTime.now().toIso8601String(),
            })
            .eq('id', res['id']);
            
        final name = res['profiles']?['display_name'] ?? res['profiles']?['voice_name'] ?? 'Guest';
        _showResult(true, 'Success! $name checked in.');
      }
    } catch (e) {
      if (mounted) _showResult(false, 'Error processing ticket: $e');
    }
  }

  void _showResult(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.cancel, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: success ? Colors.green.shade800 : Colors.red.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Allow scanning again after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Ticket', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleBarcode,
          ),
          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: gold,
                borderWidth: 3.0,
                overlayColor: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isProcessing)
                  CircularProgressIndicator(color: gold)
                else
                  Text(
                    'Align QR code within frame',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;

  const _ScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.overlayColor = const Color(0x88000000),
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getClipPath(Rect rect) {
      final width = rect.width;
      final height = rect.height;
      final size = width < height ? width * 0.7 : height * 0.7;
      final left = (width - size) / 2;
      final top = (height - size) / 2;
      return Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, size, size), const Radius.circular(12)));
    }

    return Path()
      ..addRect(rect)
      ..addPath(_getClipPath(rect), Offset.zero);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final size = width < height ? width * 0.7 : height * 0.7;
    final left = (width - size) / 2;
    final top = (height - size) / 2;
    final scanRect = Rect.fromLTWH(left, top, size, size);

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)), paint);
    
    // Draw background
    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
      
    final backgroundPath = Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
      
    canvas.drawPath(backgroundPath, backgroundPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}
