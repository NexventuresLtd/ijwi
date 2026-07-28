import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/notify_helper.dart';

class EventCheckoutScreen extends StatefulWidget {
  final String eventId;
  const EventCheckoutScreen({super.key, required this.eventId});

  @override
  State<EventCheckoutScreen> createState() => _EventCheckoutScreenState();
}

class _EventCheckoutScreenState extends State<EventCheckoutScreen> {
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _tiers = [];
  Map<String, dynamic>? _selectedTier;
  bool _loading = true;
  bool _processing = false;
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await supabase.from('events').select('id, title, event_date, location, is_free, ticket_price').eq('id', widget.eventId).single();
      final tResponse = await supabase.from('ticket_tiers').select('*').eq('event_id', widget.eventId).order('sort_order', ascending: true);
      final tiersList = List<Map<String, dynamic>>.from(tResponse);
      
      if (mounted) {
        setState(() { 
          _event = e; 
          _tiers = tiersList;
          if (tiersList.isNotEmpty) _selectedTier = tiersList.first;
          _loading = false; 
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay() async {
    final e = _event!;
    final isFree = e['is_free'] == true;
    final amount = _selectedTier != null ? _selectedTier!['price'] : (e['ticket_price'] ?? 0);
    
    if (!isFree) {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty) return;
    }
    
    setState(() => _processing = true);

    try {
      final uid = supabase.auth.currentUser!.id;
      
      // Record booking as pending (or completed if free)
      final bookingResponse = await supabase.from('event_bookings').insert({
        'event_id': widget.eventId,
        'user_id': uid,
        'tier_id': _selectedTier?['id'],
        'amount': amount,
        'payment_status': isFree ? 'completed' : 'pending',
        'ticket_code': 'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'
      }).select('id').single();
      
      final bookingId = bookingResponse['id'];

      if (!isFree) {
        // 1. Call OpusPay Checkout Edge Function
        final phone = _phoneCtrl.text.trim();
        final res = await supabase.functions.invoke('opuspay-checkout', body: {
          'phone': phone,
          'amount': amount,
          'merchant_reference': 'ticket_$bookingId',
        });
        

        
        final paymentId = res.data['payment_id'];
        final clientToken = res.data['client_token'];
        
        if (paymentId == null || clientToken == null) {
          throw Exception(res.data['error'] ?? 'Unknown error connecting to payment gateway');
        }

        // 2. Poll the status
        bool isCompleted = false;
        while (!isCompleted) {
          if (!mounted) return;
          
          final client = HttpClient();
          final req = await client.getUrl(Uri.parse('https://pay.opus.rw/api/v1/payments/$paymentId'));
          req.headers.add('Authorization', 'Bearer $clientToken');
          
          final resHttp = await req.close();
          final resBody = await resHttp.transform(utf8.decoder).join();
          client.close();
          
          if (resHttp.statusCode == 200) {
            final statusData = jsonDecode(resBody);
            if (statusData['status'] == 'completed') {
              isCompleted = true;
              break;
            } else if (statusData['status'] == 'failed') {
              throw Exception(statusData['failure_reason'] ?? 'Payment failed on mobile money side');
            }
          }
          
          // Poll every 3 seconds
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      
      // Post-payment success logic (or free ticket logic)
      bool shouldDecrement = isFree;
      if (!isFree) {
        // Fallback: mark as completed if still pending (in case webhook failed/delayed)
        final updateRes = await supabase
            .from('event_bookings')
            .update({'payment_status': 'completed'})
            .eq('id', bookingId)
            .eq('payment_status', 'pending')
            .select('id');
            
        if (updateRes.isNotEmpty) {
          shouldDecrement = true;
        }
      }
      
      if (shouldDecrement) {
        if (_selectedTier != null && _selectedTier!['capacity'] != null && _selectedTier!['capacity'] > 0) {
          await supabase.from('ticket_tiers').update({'capacity': _selectedTier!['capacity'] - 1}).eq('id', _selectedTier!['id']);
        } else if (e['max_attendees'] != null && e['max_attendees'] > 0) {
          await supabase.from('events').update({'max_attendees': e['max_attendees'] - 1}).eq('id', e['id']);
        }
        
        if (e['organizer_id'] != null && e['organizer_id'] != uid) {
          sendNotification(
            toUserId: e['organizer_id'], 
            type: 'purchase', 
            message: 'Someone just bought a ticket to ${e['title'] ?? 'your event'}!',
          );
        }
      }

      if (!mounted) return;
      setState(() => _processing = false);
      context.pushReplacement('/events/booked');
    } catch (e) {
      if (mounted) setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to process payment: $e')));
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_event == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Event not found')));

    final e = _event!;
    final isFree = e['is_free'] == true;
    final price = _selectedTier != null ? ((_selectedTier!['price'] as num?)?.toInt() ?? 0).toString() : ((e['ticket_price'] as num?)?.toInt() ?? 0).toString();

    return Scaffold(
      appBar: AppBar(title: Text('Checkout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Summary', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Text(e['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                      Text(isFree ? 'Free' : '$price RWF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: gold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(isFree ? '0 RWF' : '$price RWF', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: gold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (!isFree && _tiers.isNotEmpty) ...[
              Text('Select Tier', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ..._tiers.map((t) {
                final selected = _selectedTier?['id'] == t['id'];
                final int remaining = (t['capacity'] ?? 100) - (t['sold_count'] ?? 0);
                final bool isSoldOut = remaining <= 0;
                
                return GestureDetector(
                  onTap: isSoldOut ? null : () => setState(() => _selectedTier = t),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSoldOut ? Theme.of(context).disabledColor.withValues(alpha: 0.1) : (selected ? gold.withValues(alpha: 0.1) : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? gold : Theme.of(context).dividerColor),
                    ),
                    child: Row(children: [
                      Icon(selected ? LucideIcons.circle_check : LucideIcons.circle, color: isSoldOut ? Theme.of(context).disabledColor : (selected ? gold : Theme.of(context).hintColor)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'] ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: isSoldOut ? Theme.of(context).disabledColor : null)),
                            const SizedBox(height: 2),
                            Text(isSoldOut ? 'Sold out' : '$remaining remaining', style: TextStyle(fontSize: 12, color: isSoldOut ? Colors.redAccent : Theme.of(context).hintColor)),
                          ],
                        ),
                      ),
                      Text('${(t['price'] as num?)?.toInt() ?? 0} RWF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isSoldOut ? Theme.of(context).disabledColor : (selected ? gold : null))),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 32),
            ],
            if (!isFree) ...[
              Text('Payment Method', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.smartphone, color: gold),
                    const SizedBox(width: 12),
                    Text('Mobile Money (MTN/Airtel)', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: gold)),
                    const Spacer(),
                    Icon(LucideIcons.check, color: gold),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Mobile Money Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).hintColor)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g. 078...',
                  prefixIcon: const Icon(LucideIcons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _processing ? null : _pay,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _processing
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        isFree ? 'Confirm Registration' : 'Pay $price RWF',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
