import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await supabase.from('events')
          .select('*, organizer:profiles!events_organizer_id_fkey(id, voice_name, avatar_url)')
          .gte('event_date', DateTime.now().toIso8601String())
          .order('event_date');
      if (mounted) setState(() { _events = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _events;
    if (_filter == 'free') list = list.where((e) => e['is_free'] == true).toList();
    if (_filter == 'online') list = list.where((e) => e['is_virtual'] == true).toList();
    if (_filter == 'in-person') list = list.where((e) => e['is_virtual'] != true).toList();
    final q = _search.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        final org = (e['organizer']?['voice_name'] ?? '').toString().toLowerCase();
        return title.contains(q) || org.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: gold,
        edgeOffset: 180,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Floating header - hides on scroll down, reappears on any scroll up
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 0,
              expandedHeight: 192,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // Title + Host button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('IJWI EVENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: gold)),
                              const SizedBox(height: 4),
                              Text('Gather. Worship. Grow.', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w400)),
                            ])),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/events/create'),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Host'),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
                            ),
                          ]),
                        ),
                        // Search
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                hintText: 'Search events or organizers...',
                                prefixIcon: Icon(LucideIcons.search, size: 16, color: text3),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        // Filter chips
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _FilterChip(label: 'All events', active: _filter == 'all', gold: gold, onTap: () => setState(() => _filter = 'all')),
                              _FilterChip(label: '\u2713 Free', active: _filter == 'free', gold: gold, onTap: () => setState(() => _filter = 'free')),
                              _FilterChip(label: 'Online', active: _filter == 'online', gold: gold, onTap: () => setState(() => _filter = 'online')),
                              _FilterChip(label: 'In-person', active: _filter == 'in-person', gold: gold, onTap: () => setState(() => _filter = 'in-person')),
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Events list
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.calendar, size: 48, color: text3),
                const SizedBox(height: 12),
                Text('No upcoming events', style: GoogleFonts.roboto(fontSize: 18)),
                const SizedBox(height: 6),
                Text('Be the first to host one', style: TextStyle(fontSize: 13, color: text3)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.push('/events/create'), child: const Text('+ Host an event')),
              ])))
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _EventCard(event: _filtered[i]),
                childCount: _filtered.length,
              )),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color gold;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border2 = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? gold : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? gold : border2, width: 0.5),
        ),
        child: Text(label, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final isVirtual = event['is_virtual'] == true;
    final isFree = event['is_free'] == true;
    final isLive = isVirtual && (event['stream_url'] == null || event['stream_url'] == '');
    final org = event['organizer'] as Map<String, dynamic>?;

    final date = DateTime.parse(event['event_date']).toLocal();
    final dateStr = '${_monthName(date.month)} ${date.day} \u00b7 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => context.push('/events/${event['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 4, decoration: BoxDecoration(color: gold, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(LucideIcons.calendar, size: 13, color: gold),
                const SizedBox(width: 6),
                Text(dateStr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: gold)),
                const Spacer(),
                if (isLive) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
                    const SizedBox(width: 4),
                    const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFree ? Colors.green.withValues(alpha: 0.1) : gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: isFree ? Colors.green.withValues(alpha: 0.3) : gold.withValues(alpha: 0.3)),
                  ),
                  child: Text(isFree ? '\u2713 FREE' : '${event['ticket_currency'] ?? 'RWF'} ${event['ticket_price'] ?? 0}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isFree ? Colors.green : gold)),
                ),
              ]),
              const SizedBox(height: 12),
              Text(event['title'] ?? '', style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.w400), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Icon(isVirtual ? LucideIcons.globe : LucideIcons.map_pin, size: 13, color: Theme.of(context).hintColor),
                const SizedBox(width: 5),
                Text(isVirtual ? 'Online event' : (event['location'] ?? 'TBA'), style: Theme.of(context).textTheme.bodySmall),
                if (org != null) ...[
                  const Spacer(),
                  Text('by ', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                  Text(org['voice_name'] ?? '', style: GoogleFonts.roboto(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}
