import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class EventCreateScreen extends StatefulWidget {
  const EventCreateScreen({super.key});
  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _ticketPrice = TextEditingController();
  final _maxAttendees = TextEditingController();
  final _streamUrl = TextEditingController();

  bool _isFree = true;
  bool _isVirtual = false;
  bool _amplify = false;
  String _amplifyPlan = '3days';
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  bool _loading = false;
  String? _error;

  final _amplifyPlans = [
    {'key': '3days', 'label': '3 Days', 'price': '2,000 RWF', 'desc': 'Shown on events page'},
    {'key': '7days', 'label': '7 Days', 'price': '4,500 RWF', 'desc': 'Events page + home feed'},
    {'key': '14days', 'label': '14 Days', 'price': '8,000 RWF', 'desc': 'Featured everywhere'},
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_eventDate));
      setState(() {
        _eventDate = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 18, time?.minute ?? 0);
      });
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Title and description are required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('events').insert({
        'organizer_id': uid,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _isVirtual ? null : _location.text.trim(),
        'event_date': _eventDate.toIso8601String(),
        'is_free': _isFree,
        'ticket_price': _isFree ? null : double.tryParse(_ticketPrice.text),
        'ticket_currency': 'RWF',
        'max_attendees': _maxAttendees.text.isNotEmpty ? int.tryParse(_maxAttendees.text) : null,
        'is_virtual': _isVirtual,
        'stream_url': _isVirtual && _streamUrl.text.trim().isNotEmpty ? _streamUrl.text.trim() : null,
        'early_access': _amplify,
      });
      if (mounted) context.go('/events');
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(LucideIcons.x, size: 22), onPressed: () => context.pop()),
        title: Text('Host an Event', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title
          _label('Event title *'),
          TextField(controller: _title, decoration: const InputDecoration(hintText: 'Worship Night at Kigali Arena')),
          const SizedBox(height: 16),

          // Description
          _label('Description *'),
          TextField(controller: _description, maxLines: 4, decoration: const InputDecoration(hintText: 'What to expect, who it\'s for...')),
          const SizedBox(height: 16),

          // Date
          _label('Date & time *'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Row(children: [
                Icon(LucideIcons.calendar, size: 16, color: gold),
                const SizedBox(width: 10),
                Text('${_eventDate.day}/${_eventDate.month}/${_eventDate.year} at ${_eventDate.hour.toString().padLeft(2, '0')}:${_eventDate.minute.toString().padLeft(2, '0')}', style: GoogleFonts.poppins(fontSize: 14)),
                const Spacer(),
                Icon(LucideIcons.chevron_down, size: 16, color: text3),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Toggles
          _toggle('Online / virtual event', _isVirtual, (v) => setState(() => _isVirtual = v), gold),
          const SizedBox(height: 12),

          if (_isVirtual) ...[
            _label('Stream URL (optional)'),
            TextField(controller: _streamUrl, decoration: const InputDecoration(hintText: 'Leave empty to use Ijwi Live')),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('No URL = in-app live chat room', style: TextStyle(fontSize: 12, color: text3))),
            const SizedBox(height: 16),
          ] else ...[
            _label('Location'),
            TextField(controller: _location, decoration: const InputDecoration(hintText: 'Kigali Arena, Kigali')),
            const SizedBox(height: 16),
          ],

          _toggle('Free event', _isFree, (v) => setState(() => _isFree = v), gold),
          const SizedBox(height: 12),

          if (!_isFree) ...[
            _label('Ticket price (RWF)'),
            TextField(controller: _ticketPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '5000')),
            const SizedBox(height: 16),
          ],

          _label('Max attendees (optional)'),
          TextField(controller: _maxAttendees, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '200')),
          const SizedBox(height: 28),

          // Amplify section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _amplify ? gold : border, width: _amplify ? 1.5 : 0.5),
              color: _amplify ? gold.withValues(alpha: 0.05) : surface,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(LucideIcons.rocket, size: 20, color: gold),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Amplify your event', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Get more attendees with paid promotion', style: TextStyle(fontSize: 12, color: text3)),
                ])),
                Switch.adaptive(value: _amplify, onChanged: (v) => setState(() => _amplify = v), activeColor: gold),
              ]),
              if (_amplify) ...[
                const SizedBox(height: 16),
                ..._amplifyPlans.map((plan) {
                  final selected = _amplifyPlan == plan['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _amplifyPlan = plan['key']!),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? gold : border, width: selected ? 1.5 : 0.5),
                        color: selected ? gold.withValues(alpha: 0.08) : Colors.transparent,
                      ),
                      child: Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? gold : text3, width: 2)),
                          child: selected ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: gold))) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(plan['label']!, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(plan['desc']!, style: TextStyle(fontSize: 11, color: text3)),
                        ])),
                        Text(plan['price']!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gold)),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Text('Payment will be processed via MoMo after creating the event.', style: TextStyle(fontSize: 11, color: text3, fontStyle: FontStyle.italic)),
              ],
            ]),
          ),

          const SizedBox(height: 24),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
            ),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_loading ? 'Creating...' : _amplify ? 'Create & Amplify \u2192' : 'Create event \u2192'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? IjwiColors.darkText2 : IjwiColors.lightText2)),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged, Color gold) {
    return Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 14))),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: gold),
    ]);
  }
}
