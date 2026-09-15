import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../shared/widgets/verse_refresh_control.dart';

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
          .select('*, cover_image_url, organizer:profiles!events_organizer_id_fkey(id, voice_name, avatar_url), ticket_tiers(id, price)')
          .not('tags', 'cs', ['quick_live'])
          .gte('event_date', DateTime.now().toIso8601String())
          .order('event_date');
      if (mounted) setState(() { _events = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _events;
    if (_filter == 'live') list = list.where((e) => e['is_live'] == true).toList();
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

  void _showHostOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final gold = Theme.of(context).colorScheme.primary;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('What do you want to host?', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(backgroundColor: gold.withValues(alpha: 0.1), child: Icon(LucideIcons.calendar, color: gold)),
                  title: const Text('Host an Event', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Gather people in-person or online'),
                  onTap: () { Navigator.pop(context); context.push('/events/create?type=event'); },
                ),
                ListTile(
                  leading: CircleAvatar(backgroundColor: gold.withValues(alpha: 0.1), child: Icon(LucideIcons.mic, color: gold)),
                  title: const Text('Host a Live Prayer', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Start an audio/video streaming session'),
                  onTap: () { Navigator.pop(context); context.push('/events/create?type=live_prayer'); },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    final safeTop = MediaQuery.of(context).padding.top;
    final featured = _events.where((e) => e['is_amplified'] == true).toList();
    final rest = _filtered;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Floating header
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('IJWI EVENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: gold)),
                Text('Gather. Worship. Grow.', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w400, height: 1.2)),
              ])),
              ElevatedButton.icon(
                onPressed: _showHostOptions,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Host'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              ),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: Icon(LucideIcons.search, size: 16, color: text3),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
            ),
          ),

          VerseRefreshControl(onRefresh: _load),

          // Events list
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_events.isEmpty)
            SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.calendar, size: 48, color: text3),
              const SizedBox(height: 12),
              Text('No upcoming events', style: GoogleFonts.poppins(fontSize: 18)),
              const SizedBox(height: 6),
              Text('Be the first to host one', style: TextStyle(fontSize: 13, color: text3)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _showHostOptions, child: const Text('+ Host an event')),
            ])))
          else ...[
            if (featured.isNotEmpty)
              SliverToBoxAdapter(
                child: _FeaturedCarousel(featured: featured),
              ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text('All Events', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _FilterChip(label: 'All events', active: _filter == 'all', gold: gold, onTap: () => setState(() => _filter = 'all')),
                        _FilterChip(label: 'Live Now', active: _filter == 'live', gold: gold, onTap: () => setState(() => _filter = 'live')),
                        _FilterChip(label: '\u2713 Free', active: _filter == 'free', gold: gold, onTap: () => setState(() => _filter = 'free')),
                        _FilterChip(label: 'Online', active: _filter == 'online', gold: gold, onTap: () => setState(() => _filter = 'online')),
                        _FilterChip(label: 'In-person', active: _filter == 'in-person', gold: gold, onTap: () => setState(() => _filter = 'in-person')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            if (rest.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('No events match your filter.', style: TextStyle(color: text3)),
                  ),
                ),
              )
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _EventListTile(event: rest[i]),
                childCount: rest.length,
              )),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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
        child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
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
    final isVirtual = event['is_virtual'] == true;
    final isFree = event['is_free'] == true;
    final isLive = isVirtual && (event['stream_url'] == null || event['stream_url'] == '');
    final date = DateTime.parse(event['event_date']).toLocal();
    final dateStr = '${_monthName(date.month)} ${date.day} \u00b7 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => context.push('/events/${event['id']}'),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: 300,
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image
              if (event['cover_image_url'] != null)
                CachedNetworkImage(
                  imageUrl: event['cover_image_url'],
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: gold.withValues(alpha: 0.15), child: Center(child: Icon(LucideIcons.image, color: gold.withValues(alpha: 0.3), size: 32))),
                  errorWidget: (_, __, ___) => Container(color: gold.withValues(alpha: 0.15)),
                )
              else
                Container(color: gold.withValues(alpha: 0.15)),

              // 2. Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Glassmorphism details at bottom
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(event['title'] ?? '', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text(_getPriceText(event, isFree), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(isVirtual ? LucideIcons.globe : LucideIcons.map_pin, size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(isVirtual ? 'Online event' : ((event['location'] == null || event['location'].toString().trim().isEmpty) ? 'TBA' : event['location']), style: const TextStyle(fontSize: 12, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Icon(LucideIcons.calendar, size: 12, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. LIVE indicator
              if (isLive)
                Positioned(
                  top: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}

class _EventListTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventListTile({required this.event});

  String _monthName(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isVirtual = event['is_virtual'] == true;
    final isFree = event['is_free'] == true;
    final date = DateTime.parse(event['event_date']).toLocal();
    final dateStr = '${_monthName(date.month)} ${date.day} \u00b7 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final surfaceHighlight = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;

    return GestureDetector(
      onTap: () => context.push('/events/${event['id']}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: surfaceHighlight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: event['cover_image_url'] != null
                  ? CachedNetworkImage(
                      imageUrl: event['cover_image_url'],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Icon(LucideIcons.image, color: text3),
                      errorWidget: (_, __, ___) => Icon(LucideIcons.image, color: text3),
                    )
                  : Icon(LucideIcons.image, color: text3),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['title'] ?? 'Untitled Event', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${_getPriceText(event, isFree)} \u00b7 $dateStr', style: TextStyle(fontSize: 13, color: gold, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(isVirtual ? LucideIcons.video : LucideIcons.map_pin, size: 12, color: text3),
                      const SizedBox(width: 4),
                      Expanded(child: Text(isVirtual ? 'Online Event' : ((event['location'] == null || event['location'].toString().trim().isEmpty) ? 'TBA' : event['location']), style: TextStyle(fontSize: 12, color: text3), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _getPriceText(Map<String, dynamic> event, bool isFree) {
  if (isFree) return 'FREE';
  final tiers = event['ticket_tiers'] as List<dynamic>?;
  if (tiers != null && tiers.length > 1) return 'Tiered';
  if (tiers != null && tiers.length == 1) return '${event['ticket_currency'] ?? 'RWF'} ${(tiers.first['price'] as num?)?.toInt() ?? 0}';
  return '${event['ticket_currency'] ?? 'RWF'} ${(event['ticket_price'] as num?)?.toInt() ?? 0}';
}

class _FeaturedCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> featured;
  const _FeaturedCarousel({required this.featured});
  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9, initialPage: 1000 * widget.featured.length);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.featured.length <= 1) return;
    Future.delayed(const Duration(seconds: 4), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    if (_pageController.hasClients) {
      _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    }
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featured.isEmpty) return const SizedBox.shrink();
    if (widget.featured.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text('Featured', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 320,
              child: _EventCard(event: widget.featured.first),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text('Featured', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) {
              final event = widget.featured[i % widget.featured.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _EventCard(event: event),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.featured.length, (index) {
            final isActive = (_currentPage % widget.featured.length) == index;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
