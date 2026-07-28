import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:ijwi_mobile/core/image_helper.dart';

import '../../../core/theme.dart';
import '../../../core/storage_helper.dart';

class ManageEventScreen extends StatefulWidget {
  final String eventId;
  const ManageEventScreen({super.key, required this.eventId});

  @override
  State<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends State<ManageEventScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _attendees = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final eRes = await supabase
          .from('events')
          .select()
          .eq('id', widget.eventId)
          .single();
          
      List<Map<String, dynamic>> tRes = [];
      try {
        final tRaw = await supabase
            .from('event_tickets')
            .select('id, status, amount, attended, profiles(id, username, display_name, avatar_url)')
            .eq('event_id', widget.eventId);
        tRes = List<Map<String, dynamic>>.from(tRaw);
      } catch (err) {
        debugPrint('Error loading tickets: $err');
        try {
          final tRaw2 = await supabase
              .from('event_tickets')
              .select('id, status, amount, attended, user_id')
              .eq('event_id', widget.eventId);
          tRes = List<Map<String, dynamic>>.from(tRaw2);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _event = eRes;
          _attendees = tRes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _uploadMoments() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);

    try {
      List<String> urls = List<String>.from(_event!['moments_urls'] ?? []);
      for (var f in result.files) {
        if (f.path == null) continue;
        final fixedPath = await ImageHelper.compressAndFixRotation(f.path!);
        final file = File(fixedPath);
        final bytes = await file.readAsBytes();
        final url = await uploadToStorage(bucket: 'images', path: 'events/${widget.eventId}/moments/${f.name}', bytes: bytes);
        if (url != null) urls.add(url);
      }

      await supabase.from('events').update({'moments_urls': urls}).eq('id', widget.eventId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moments uploaded!')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload moments: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_event == null) return const Scaffold(body: Center(child: Text('Event not found')));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final gold = Theme.of(context).colorScheme.primary;

    final isVirtual = _event!['is_virtual'] == true;
    final eventDate = DateTime.parse(_event!['event_date']).toLocal();
    final isPast = DateTime.now().isAfter(eventDate);
    final coverImage = _event!['cover_image_url'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.black87, // keep it dark when collapsed
            leading: context.canPop() ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                child: const BackButton(color: Colors.white),
              ),
            ) : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverImage != null)
                    Image.network(coverImage, fit: BoxFit.cover)
                  else
                    Container(color: gold.withValues(alpha: 0.1)),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Manage Event', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text(_event!['title'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.calendar, size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(DateFormat('MMM d, yyyy • h:mm a').format(eventDate), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Attendees', style: TextStyle(color: text3, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text('${_attendees.length}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Checked In', style: TextStyle(color: text3, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text('${_attendees.where((t) => t['attended'] == true).length}', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Collection Rate', style: TextStyle(color: text3, fontSize: 13)),
                              const SizedBox(height: 8),
                              Builder(builder: (context) {
                                final expected = _event!['max_attendees'];
                                String rateStr = 'N/A';
                                if (expected != null && expected > 0) {
                                  final rate = (_attendees.length / expected) * 100;
                                  rateStr = '${rate.toStringAsFixed(1)}%';
                                }
                                return Text(rateStr, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: gold));
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Text('Actions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  
                  // Actions Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _ActionCard(
                        icon: LucideIcons.pencil,
                        label: 'Edit Event',
                        onTap: () => context.push('/events/create?eventId=${widget.eventId}').then((_) => _load()),
                      ),
                      if (!isVirtual)
                        _ActionCard(
                          icon: LucideIcons.scan_line,
                          label: 'Scan Tickets',
                          onTap: () => context.push('/my-events/${widget.eventId}/scan').then((_) => _load()),
                        ),
                      if (isVirtual)
                        _ActionCard(
                          icon: LucideIcons.video,
                          label: 'Start Stream',
                          onTap: () {},
                        ),
                      if (isPast)
                        _ActionCard(
                          icon: LucideIcons.camera,
                          label: _uploading ? 'Uploading...' : 'Upload Moments',
                          onTap: _uploading ? null : _uploadMoments,
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  Text('Registrations', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  
                  if (_attendees.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                      child: Column(
                        children: [
                          Icon(LucideIcons.users, size: 48, color: text3.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text('No attendees yet', style: TextStyle(color: text3, fontSize: 16)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attendees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final t = _attendees[index];
                        final profile = t['profiles'];
                        final hasProfile = profile != null;
                        final name = hasProfile ? (profile['display_name'] ?? profile['username']) : 'User ${t['user_id']?.toString().substring(0,6)}';
                        final avatar = hasProfile ? profile['avatar_url'] : null;
                        final attended = t['attended'] == true;
                        
                        return Container(
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              backgroundColor: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                              child: avatar == null ? Icon(LucideIcons.user, color: text3) : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Ticket: #${t['id'].toString().substring(0,8).toUpperCase()}', style: TextStyle(color: text3, fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: attended ? Colors.green.withValues(alpha: 0.1) : gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                attended ? 'Attended' : 'Pending',
                                style: TextStyle(color: attended ? Colors.green : gold, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionCard({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final gold = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: gold),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
