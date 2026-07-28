import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/verses.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _hostedEvents = [];
  List<Map<String, dynamic>> _collabEvents = [];
  bool _loading = true;
  late Map<String, String> _dailyVerse;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _dailyVerse = Verses.all[DateTime.now().day % Verses.all.length];
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final hostedRes = await supabase
          .from('events')
          .select('id, title, event_date, is_virtual, location, cover_image_url, organizer_id')
          .not('tags', 'cs', ['quick_live'])
          .eq('organizer_id', supabase.auth.currentUser!.id);

      final collabResRaw = await supabase
          .from('event_collaborators')
          .select('events(id, title, event_date, is_virtual, location, cover_image_url, organizer_id)')
          .eq('user_id', supabase.auth.currentUser!.id);

      final collabRes = collabResRaw
          .map((e) => e['events'] as Map<String, dynamic>?)
          .where((e) => e != null)
          .cast<Map<String, dynamic>>()
          .toList();
      
      final ticketsRaw = await supabase
          .from('event_bookings')
          .select('events(id, title, event_date, is_virtual, location, cover_image_url, organizer_id)')
          .eq('user_id', supabase.auth.currentUser!.id);

      final myTickets = ticketsRaw
          .map((b) => b['events'] as Map<String, dynamic>?)
          .where((e) => e != null)
          .cast<Map<String, dynamic>>()
          .toList();

      final allHosted = [...hostedRes, ...collabRes];
      final seenHosted = <String>{};
      final uniqueHosted = <Map<String, dynamic>>[];
      for (var e in allHosted) {
        if (seenHosted.add(e['id'])) uniqueHosted.add(e);
      }
      uniqueHosted.sort((a, b) => DateTime.parse(a['event_date']).compareTo(DateTime.parse(b['event_date'])));

      final seenAll = <String>{};
      final uniqueAll = <Map<String, dynamic>>[];
      for (var e in uniqueHosted) {
         if (seenAll.add(e['id'])) uniqueAll.add(e);
      }
      for (var e in myTickets) {
         if (seenAll.add(e['id'])) uniqueAll.add(e);
      }
      uniqueAll.sort((a, b) => DateTime.parse(a['event_date']).compareTo(DateTime.parse(b['event_date'])));

      if (mounted) {
        setState(() {
          _allEvents = uniqueAll;
          _hostedEvents = uniqueHosted;
          _collabEvents = myTickets;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Events'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} event(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => _loading = true);
    try {
      await supabase.from('events').delete().inFilter('id', _selectedIds.toList());
      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
      _load();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  Widget _buildList(List<Map<String, dynamic>> events, bool isDark, Color text3, Color surface, Color surfaceHighlight, Color border, Color gold, String tabType) {
    final filteredEvents = events.where((e) {
      if (_searchQuery.isEmpty) return true;
      final title = (e['title'] as String?)?.toLowerCase() ?? '';
      return title.contains(_searchQuery);
    }).toList();

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tabType == 'hosted' ? LucideIcons.calendar : LucideIcons.ticket, size: 48, color: text3.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(_searchQuery.isNotEmpty ? 'No events matched your search' : (tabType == 'hosted' ? 'No hosted events yet' : 'No tickets yet'), style: TextStyle(color: text3, fontSize: 16)),
            const SizedBox(height: 16),
            if (tabType == 'hosted' && _searchQuery.isEmpty)
              ElevatedButton(
                onPressed: () => context.push('/events/create').then((_) => _load()),
                child: const Text('Host an event'),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final e = filteredEvents[index];
        final date = DateTime.parse(e['event_date']).toLocal();
        final isVirtual = e['is_virtual'] == true;
        final isOrganizer = e['organizer_id'] == supabase.auth.currentUser?.id;

        final bool isHost = _hostedEvents.any((h) => h['id'] == e['id']);

        final isSelected = _selectedIds.contains(e['id']);

        return InkWell(
          onLongPress: isOrganizer ? () {
            setState(() {
              _selectionMode = true;
              if (isSelected) {
                _selectedIds.remove(e['id']);
                if (_selectedIds.isEmpty) _selectionMode = false;
              } else {
                _selectedIds.add(e['id']);
              }
            });
          } : null,
          onTap: () {
            if (_selectionMode && isOrganizer) {
              setState(() {
                if (isSelected) {
                  _selectedIds.remove(e['id']);
                  if (_selectedIds.isEmpty) _selectionMode = false;
                } else {
                  _selectedIds.add(e['id']);
                }
              });
              return;
            }
            if (isHost) {
               context.push('/my-events/${e['id']}').then((_) => _load());
            } else {
               context.push('/my-tickets/${e['id']}').then((_) => _load());
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? gold.withValues(alpha: 0.1) : surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? gold : border, width: isSelected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      e['cover_image_url'] != null
                          ? Image.network(e['cover_image_url'], fit: BoxFit.cover)
                          : Container(
                              color: surfaceHighlight,
                              child: Icon(LucideIcons.image, color: text3),
                            ),
                      if (isOrganizer)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Hosted', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['title'] ?? 'Untitled Event',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, y').format(date),
                        style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(isVirtual ? LucideIcons.video : LucideIcons.map_pin, size: 12, color: text3),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isVirtual ? 'Online Event' : (e['location'] ?? 'TBD'),
                              style: TextStyle(color: text3, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final surfaceHighlight = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final gold = Theme.of(context).colorScheme.primary;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 260,
                      pinned: true,
                      backgroundColor: Colors.black87,
                      leading: _selectionMode 
                        ? IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: () => setState(() { _selectionMode = false; _selectedIds.clear(); }))
                        : (context.canPop() ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                          child: const BackButton(color: Colors.white),
                        ),
                      ) : null),
                      actions: [
                        if (_selectionMode)
                          IconButton(
                            icon: const Icon(LucideIcons.trash_2, color: Colors.redAccent),
                            onPressed: _deleteSelected,
                          )
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: EdgeInsets.only(left: context.canPop() ? 56 : 16, bottom: 12, right: 16),
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('My Events', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    hintText: 'Search events...',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                    prefixIcon: Icon(LucideIcons.search, size: 14, color: Colors.white.withValues(alpha: 0.6)),
                                    filled: true,
                                    fillColor: Colors.black.withValues(alpha: 0.4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [gold.withValues(alpha: 0.9), Colors.black87],
                            ),
                          ),
                          child: SafeArea(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 40, 16, 60),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.book_open, size: 14, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text('Daily Inspiration', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '"${_dailyVerse['text']}"',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic, height: 1.4),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _dailyVerse['reference']!,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          labelColor: gold,
                          unselectedLabelColor: text3,
                          indicatorColor: gold,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: const [
                            Tab(text: 'All'),
                            Tab(text: 'Hosted'),
                            Tab(text: 'My Tickets'),
                          ],
                        ),
                        surface,
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  children: [
                    _buildList(_allEvents, isDark, text3, surface, surfaceHighlight, border, gold, 'all'),
                    _buildList(_hostedEvents, isDark, text3, surface, surfaceHighlight, border, gold, 'hosted'),
                    _buildList(_collabEvents, isDark, text3, surface, surfaceHighlight, border, gold, 'tickets'),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || backgroundColor != oldDelegate.backgroundColor;
  }
}
