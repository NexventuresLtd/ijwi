import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;
import 'package:camera/camera.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class LiveRoomScreen extends StatefulWidget {
  final String eventId;
  const LiveRoomScreen({super.key, required this.eventId});
  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String _title = '';
  String get _uid => supabase.auth.currentUser!.id;

  bool _isHost = false;
  Map<String, dynamic>? _livestream;
  bool _isLive = false;
  int _viewerCount = 0;
  
  // Settings
  bool _allowRequests = true;
  String _visibility = 'Everyone';
  List<Map<String, dynamic>> _requests = [];
  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  bool _isFrontCamera = true;
  bool _isMuted = false;
  List<Map<String, dynamic>> _coHosts = [];

  @override
  void initState() { super.initState(); _load(); _subscribe(); }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraCtrl = CameraController(front, ResolutionPreset.medium, enableAudio: true);
      await _cameraCtrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init failed: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;
      _isFrontCamera = !_isFrontCamera;
      final target = cameras.firstWhere(
        (c) => c.lensDirection == (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => cameras.first,
      );
      await _cameraCtrl?.dispose();
      _cameraCtrl = CameraController(target, ResolutionPreset.medium, enableAudio: true);
      await _cameraCtrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Switch camera failed: $e');
    }
  }

  Future<void> _load() async {
    try {
      final event = await supabase.from('events').select('title, organizer_id').eq('id', widget.eventId).single();
      final stream = await supabase.from('live_streams').select('*').eq('event_id', widget.eventId).maybeSingle();
      
      final msgs = await supabase.from('live_messages')
          .select('*, author:profiles!live_messages_user_id_fkey(voice_name, real_name, is_revealed, avatar_url)')
          .eq('event_id', widget.eventId)
          .order('created_at')
          .limit(100);
      
      if (mounted) {
        setState(() { 
          _title = event['title'] ?? ''; 
          _isHost = event['organizer_id'] == _uid;
          _livestream = stream;
          _isLive = stream?['status'] == 'live';
          _messages = List<Map<String, dynamic>>.from(msgs); 
        });
        if (_isHost && _isLive) _loadRequests();
        if (_isLive || _isHost) _initCamera();
        _updateViewerCount();
      }
      _scrollBottom();
    } catch (e) {
      debugPrint('LiveRoom _load error: $e');
    }
  }

  Future<void> _updateViewerCount() async {
    try {
      final count = await supabase.from('event_bookings').select('id').eq('event_id', widget.eventId).count();
      if (mounted) setState(() => _viewerCount = count.count);
    } catch (_) {}
  }
  
  Future<void> _loadRequests() async {
    if (_livestream == null) return;
    try {
      final reqs = await supabase.from('livestream_requests')
          .select('*, user:profiles!livestream_requests_user_id_fkey(voice_name, real_name, is_revealed)')
          .eq('stream_id', _livestream!['id'])
          .eq('status', 'pending');
      if (mounted) setState(() => _requests = List<Map<String, dynamic>>.from(reqs));
    } catch (_) {}
  }

  void _subscribe() {
    supabase.channel('live-${widget.eventId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert, 
          schema: 'public', 
          table: 'live_messages', 
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) async {
            final msg = payload.newRecord;
            if (msg['user_id'] == _uid) return;
            try {
              final a = await supabase.from('profiles').select('voice_name, real_name, is_revealed, avatar_url').eq('id', msg['user_id']).single();
              if (mounted) setState(() => _messages.add({...msg, 'author': a}));
              _scrollBottom();
            } catch (_) {}
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public', 
          table: 'live_streams', 
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) {
            _load();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public', 
          table: 'livestream_requests',
          callback: (payload) {
            if (_isHost && _isLive) _loadRequests();
          },
        )
        .subscribe();
  }

  void _scrollBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  });

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    try {
      final profile = await supabase.from('profiles').select('voice_name, real_name, is_revealed, avatar_url').eq('id', _uid).single();
      setState(() => _messages.add({'user_id': _uid, 'message': text, 'created_at': DateTime.now().toIso8601String(), 'author': profile}));
      _scrollBottom();
      await supabase.from('live_messages').insert({'event_id': widget.eventId, 'user_id': _uid, 'message': text});
    } catch (e) {
      debugPrint('Send message error: $e');
    }
  }

  Future<void> _startLive() async {
    try {
      if (_livestream == null) {
        final res = await supabase.from('live_streams').insert({
          'event_id': widget.eventId,
          'host_id': _uid,
          'status': 'live',
          'title': _title,
          'created_at': DateTime.now().toIso8601String(),
        }).select().single();
        _livestream = res;
      } else {
        await supabase.from('live_streams').update({'status': 'live'}).eq('id', _livestream!['id']);
      }
      await supabase.from('events').update({'is_live': true, 'is_virtual': true}).eq('id', widget.eventId);
      if (mounted) setState(() => _isLive = true);
      _initCamera();
    } catch (e) {
      debugPrint('Start live error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start live: $e')));
      }
    }
  }

  Future<void> _endLive() async {
    try {
      if (_livestream != null) {
        await supabase.from('live_streams').update({'status': 'ended'}).eq('id', _livestream!['id']);
      }
      await supabase.from('events').update({'is_live': false}).eq('id', widget.eventId);
      if (mounted) {
        setState(() => _isLive = false);
        _cameraCtrl?.dispose();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('End live error: $e');
    }
  }

  Future<void> _requestToJoin() async {
    if (_livestream == null) return;
    try {
      await supabase.from('livestream_requests').upsert({
        'stream_id': _livestream!['id'],
        'user_id': _uid,
        'status': 'pending',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to host!')));
    } catch (_) {}
  }

  void _showRequestsSheet() {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Join Requests', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_requests.isEmpty) const Text('No pending requests.'),
        ..._requests.map((r) {
          final u = r['user'] as Map<String, dynamic>?;
          final name = (u?['is_revealed'] == true) ? (u?['real_name'] ?? 'User') : (u?['voice_name'] ?? 'User');
          return ListTile(
            title: Text(name),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(LucideIcons.check, color: Colors.green), onPressed: () async {
                await supabase.from('livestream_requests').update({'status': 'accepted'}).eq('id', r['id']);
                if (mounted) Navigator.pop(context);
                _loadRequests();
              }),
              IconButton(icon: const Icon(LucideIcons.x, color: Colors.red), onPressed: () async {
                await supabase.from('livestream_requests').update({'status': 'rejected'}).eq('id', r['id']);
                if (mounted) Navigator.pop(context);
                _loadRequests();
              }),
            ]),
          );
        }),
      ]),
    )));
  }

  // ─── Pre-Live Configuration Screen (Host only) ─────────────────
  Widget _buildPreLiveScreen() {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;

    return Scaffold(
      appBar: AppBar(title: Text('Prepare Live', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _cameraReady && _cameraCtrl != null
                    ? ClipOval(child: SizedBox(width: 140, height: 140, child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _cameraCtrl!.value.previewSize?.height ?? 140, height: _cameraCtrl!.value.previewSize?.width ?? 140, child: CameraPreview(_cameraCtrl!)))))
                    : Icon(LucideIcons.camera, size: 48, color: gold),
              ),
              const SizedBox(height: 24),
              Text('Go Live', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_title, style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  DropdownButtonFormField<String>(
                    value: _visibility,
                    decoration: const InputDecoration(labelText: 'Who can see your live'),
                    items: ['Everyone', 'Followers Only'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _visibility = v!),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Allow Requests to Join'),
                    subtitle: const Text('Let viewers request to co-host'),
                    value: _allowRequests,
                    activeColor: gold,
                    onChanged: (v) => setState(() => _allowRequests = v),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _startLive,
                  icon: const Icon(LucideIcons.radio),
                  label: Text('GO LIVE', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold, 
                    foregroundColor: Colors.black, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Main Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    
    // Host sees pre-live config screen before going live
    if (_isHost && !_isLive) {
      return _buildPreLiveScreen();
    }

    // Viewers see waiting screen if not live yet
    if (!_isLive && !_isHost) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(_title, style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(LucideIcons.radio, size: 64, color: gold.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Waiting for host to start...', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // ─── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Colors.black.withValues(alpha: 0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis)),
              if (_viewerCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.eye, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text('$_viewerCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              if (_isHost) ...[
                IconButton(
                  icon: Badge(
                    isLabelVisible: _requests.isNotEmpty,
                    label: Text('${_requests.length}'),
                    child: const Icon(LucideIcons.users, color: Colors.white, size: 20),
                  ),
                  onPressed: _showRequestsSheet,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.square, color: Colors.redAccent, size: 20),
                  tooltip: 'End Live',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('End Live?'),
                      content: const Text('This will end the live session for all viewers.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(onPressed: () { Navigator.pop(ctx); _endLive(); }, child: const Text('End', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ),
              ],
              if (!_isHost)
                IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          // ─── Camera Grid ──────────────────────────────────
          if (_cameraReady && _cameraCtrl != null)
            SizedBox(
              height: 220,
              child: Row(children: [
                // Host camera
                Expanded(
                  flex: _coHosts.isEmpty ? 1 : 1,
                  child: Stack(children: [
                    Positioned.fill(
                      child: CameraPreview(_cameraCtrl!),
                    ),
                    Positioned(
                      bottom: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Text(_isHost ? 'You (Host)' : 'You', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: _switchCamera,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.switch_camera, size: 16, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                // Co-host grid slots (up to 3 empty slots)
                if (_isHost)
                  ...List.generate(3, (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: const Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(LucideIcons.user_plus, color: Colors.white30, size: 20),
                          SizedBox(height: 4),
                          Text('Invite', style: TextStyle(color: Colors.white30, fontSize: 9)),
                        ]),
                      ),
                    ),
                  )),
              ]),
            ),

          // ─── Live Chat Feed ────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, 
                  end: Alignment.bottomCenter, 
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
              child: _messages.isEmpty
                ? const Center(child: Text('Be the first to say something!', style: TextStyle(color: Colors.white38, fontSize: 14)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final a = m['author'] as Map<String, dynamic>?;
                      final name = (a?['is_revealed'] == true && a?['real_name'] != null) ? a!['real_name'] : (a?['voice_name'] ?? 'Anon');
                      final isMine = m['user_id'] == _uid;
                      final isHostMsg = _livestream != null && m['user_id'] == _livestream!['host_id'];
                      final avatar = a?['avatar_url'] as String?;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                            backgroundColor: gold.withValues(alpha: 0.2),
                            child: avatar == null ? const Icon(LucideIcons.user, size: 12, color: Colors.white54) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMine ? gold : (isHostMsg ? Colors.pinkAccent : Colors.white70))),
                              if (isHostMsg) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.pinkAccent, borderRadius: BorderRadius.circular(3)),
                                  child: const Text('HOST', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(m['message'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white)),
                          ])),
                        ]),
                      );
                    },
                  ),
            ),
          ),
          
          // ─── Bottom Input ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.black,
            child: Row(children: [
              if (!_isHost && _allowRequests && _livestream != null)
                GestureDetector(
                  onTap: _requestToJoin,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                    child: Icon(LucideIcons.hand, size: 18, color: gold),
                  ),
                ),
              Expanded(child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              )),
              const SizedBox(width: 8),
              GestureDetector(onTap: _send, child: CircleAvatar(radius: 20, backgroundColor: gold, child: const Icon(LucideIcons.send, size: 16, color: Colors.black))),
            ]),
          ),
        ]),
      ),
    );
  }
}
