import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';

class MyTicketDetailScreen extends StatefulWidget {
  final String eventId;
  const MyTicketDetailScreen({super.key, required this.eventId});

  @override
  State<MyTicketDetailScreen> createState() => _MyTicketDetailScreenState();
}

class _MyTicketDetailScreenState extends State<MyTicketDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _bookings = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final eventRes = await supabase.from('events').select('*').eq('id', widget.eventId).single();
      final bookingsRes = await supabase
          .from('event_bookings')
          .select('*, ticket_tiers(name)')
          .eq('event_id', widget.eventId)
          .eq('user_id', uid);

      if (mounted) {
        setState(() {
          _event = eventRes;
          _bookings = List<Map<String, dynamic>>.from(bookingsRes);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Ticket')),
        body: Center(child: CircularProgressIndicator(color: gold)),
      );
    }

    if (_error != null || _event == null || _bookings.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Ticket')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text('Ticket not found or error occurred.', style: TextStyle(color: text3)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(LucideIcons.chevron_left), onPressed: () => context.pop()),
        title: Text('My Ticket', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: PageView.builder(
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final b = _bookings[index];
          final bool checkedIn = b['checked_in'] == true;
          final tierName = b['ticket_tiers']?['name'] ?? 'General Admission';
          final ticketCode = b['ticket_code'] ?? b['id'];
          final eventDate = DateTime.parse(_event!['event_date']).toLocal();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Event Info
                Text(
                  _event!['title'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMM d, y • h:mm a').format(eventDate),
                  style: TextStyle(fontSize: 16, color: gold, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  _event!['is_virtual'] == true ? 'Online Event' : (_event!['location'] ?? 'TBD'),
                  style: TextStyle(fontSize: 14, color: text3),
                ),
                const SizedBox(height: 32),

                // Ticket Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(tierName, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        '${(b['amount'] as num?)?.toInt() ?? 0} ${b['currency'] ?? 'RWF'}',
                        style: TextStyle(fontSize: 16, color: text3),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // QR Code
                      if (checkedIn)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withValues(alpha: 0.1)),
                              child: const Icon(Icons.check_circle, size: 64, color: Colors.redAccent),
                            ),
                            const SizedBox(height: 16),
                            Text('Ticket Used', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                            const SizedBox(height: 4),
                            Text('Scanned on ${b['checked_in_at'] != null ? DateFormat('MMM d, h:mm a').format(DateTime.parse(b['checked_in_at']).toLocal()) : 'Unknown'}', style: TextStyle(color: text3)),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: ticketCode,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Scan at the entrance', style: TextStyle(color: text3)),
                          ],
                        ),
                    ],
                  ),
                ),
                
                if (_bookings.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text('Ticket ${index + 1} of ${_bookings.length} (Swipe)', style: TextStyle(color: text3)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
