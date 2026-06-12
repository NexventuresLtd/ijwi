import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final e = await supabase.from('events')
        .select('*, organizer:profiles!events_organizer_id_fkey(id, voice_name)')
        .eq('id', widget.eventId).single();
    if (mounted) setState(() => _event = e);
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    if (_event == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final e = _event!;
    final isVirtual = e['is_virtual'] == true;
    final isLive = isVirtual && (e['stream_url'] == null || e['stream_url'] == '');

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e['title'] ?? '', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoChip(icon: LucideIcons.calendar, text: DateTime.parse(e['event_date']).toLocal().toString().substring(0, 16)),
            _InfoChip(icon: isVirtual ? LucideIcons.globe : LucideIcons.map_pin, text: isVirtual ? 'Online' : (e['location'] ?? 'TBA')),
          ]),
          const SizedBox(height: 20),
          Text(e['description'] ?? '', style: GoogleFonts.montserrat(fontSize: 15, height: 1.7)),
          const SizedBox(height: 28),
          if (isLive)
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () => context.push('/events/${widget.eventId}/live'),
              icon: Icon(LucideIcons.radio, size: 18),
              label: const Text('Join Ijwi Live →'),
            )),
          if (!isLive && isVirtual && e['stream_url'] != null)
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, child: const Text('Join Stream →'))),
          if (e['is_free'] == true && !isLive)
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, child: const Text('Register for free →'))),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: Theme.of(context).dividerColor)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: gold), const SizedBox(width: 6), Text(text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500))]),
    );
  }
}
