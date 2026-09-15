import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../widgets/event_share_sheet.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _event;

  String? _role;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final e = await supabase.from('events')
          .select('*, cover_image_url, organizer:profiles!events_organizer_id_fkey(id, voice_name)')
          .eq('id', widget.eventId).single();
      
      final collabRes = await supabase.from('event_collaborators').select('role').eq('event_id', widget.eventId).eq('user_id', uid).maybeSingle();
      final r = e['organizer_id'] == uid ? 'admin' : (collabRes?['role']);

      if (mounted) setState(() { _event = e; _role = r; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    if (_event == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final e = _event!;
    final isVirtual = e['is_virtual'] == true;
    final isLive = isVirtual && (e['is_live'] == true);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: const BackButton(color: Colors.white),
              ),
            ),
            actions: [
              if (_role == 'admin')
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(LucideIcons.pencil, color: Colors.white),
                      onPressed: () => context.push('/events/create?eventId=${widget.eventId}').then((_) => _load()),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => EventShareSheet(event: e));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.share, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: e['cover_image_url'] != null
                  ? CachedNetworkImage(
                      imageUrl: e['cover_image_url'],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: gold.withValues(alpha: 0.1), child: Center(child: CircularProgressIndicator(color: gold, strokeWidth: 2))),
                    )
                  : Container(color: Theme.of(context).cardColor),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(e['title'] ?? '', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _InfoChip(icon: LucideIcons.calendar, text: DateTime.parse(e['event_date']).toLocal().toString().substring(0, 16)),
                  _InfoChip(icon: isVirtual ? LucideIcons.globe : LucideIcons.map_pin, text: isVirtual ? 'Online' : (e['location'] ?? 'TBA')),
                ]),
                const SizedBox(height: 20),
                Text(e['description'] ?? '', style: GoogleFonts.montserrat(fontSize: 15, height: 1.7)),
                const SizedBox(height: 28),

                if (e['moments_urls'] != null && (e['moments_urls'] as List).isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text('Event Moments', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: (e['moments_urls'] as List).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final url = e['moments_urls'][index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Theme.of(context).cardColor, child: const Center(child: CircularProgressIndicator())),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLive)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/events/${widget.eventId}/live'),
                    icon: const Icon(LucideIcons.radio, size: 18),
                    label: Text('Join Ijwi Live', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              if (!isLive && isVirtual && e['stream_url'] != null)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Join Stream', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (!isLive && e['is_free'] == true && _role != 'admin')
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push('/events/${widget.eventId}/checkout'),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Register for free', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (!isLive && e['is_free'] != true && _role != 'admin')
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push('/events/${widget.eventId}/checkout'),
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Buy Ticket', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (_role == 'admin')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () async {
                        final uid = supabase.auth.currentUser?.id;
                        final newLive = !isLive;
                        await supabase.from('events').update({'is_live': newLive, 'is_virtual': true}).eq('id', widget.eventId);
                        if (newLive && uid != null) {
                          try {
                            await supabase.from('live_streams').upsert({
                              'event_id': widget.eventId,
                              'host_id': uid,
                              'status': 'live',
                              'title': e['title'] ?? 'Live Event',
                              'created_at': DateTime.now().toIso8601String(),
                            }, onConflict: 'event_id');
                          } catch (_) {}
                        } else {
                          try {
                            await supabase.from('live_streams').update({'status': 'ended'}).eq('event_id', widget.eventId);
                          } catch (_) {}
                        }
                        _load();
                      },
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(isLive ? 'End Live Event' : 'Start Live Stream', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: gold)),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
