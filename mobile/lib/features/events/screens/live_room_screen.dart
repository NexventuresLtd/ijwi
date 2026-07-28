import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/supabase.dart';

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

  List<int> _remoteUids = [];
  bool _localUserJoined = false;
  RtcEngine? _engine;
  bool _isLive = false;
  
  // Settings
  bool _allowRequests = true;
  String _visibility = 'Everyone';
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() { super.initState(); _load(); _subscribe(); }

  Future<void> _initAgora() async {
    try {
      await [Permission.microphone, Permission.camera].request();
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(appId: 'dummy_agora_app_id'));
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) setState(() => _localUserJoined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (mounted) setState(() { if (!_remoteUids.contains(remoteUid)) _remoteUids.add(remoteUid); });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            if (mounted) setState(() => _remoteUids.remove(remoteUid));
          },
        ),
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableVideo();
      await _engine!.startPreview();

      if (_isLive) {
        await _joinChannel();
      }
    } catch (e) {
      debugPrint('Failed to init Agora: $e');
      // If Agora fails (e.g. invalid dummy app id), just act as if we are locally joined
      // so the UI doesn't crash completely.
      if (mounted) setState(() => _localUserJoined = true);
    }
  }
  
  Future<void> _joinChannel() async {
    try {
      await _engine?.joinChannel(
        token: '',
        channelId: widget.eventId,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (_) {}
  }

  Future<void> _leaveChannel() async {
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
  }

  @override
  void dispose() {
    _leaveChannel();
    _engine?.release();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final event = await supabase.from('events').select('title, organizer_id').eq('id', widget.eventId).single();
    final stream = await supabase.from('live_streams').select('*').eq('event_id', widget.eventId).maybeSingle();
    
    final msgs = await supabase.from('live_messages').select('*, author:profiles!live_messages_user_id_fkey(voice_name, real_name, is_revealed)').eq('event_id', widget.eventId).order('created_at').limit(100);
    
    if (mounted) {
      setState(() { 
        _title = event['title'] ?? ''; 
        _isHost = event['organizer_id'] == _uid;
        _livestream = stream;
        _isLive = stream?['status'] == 'live';
        if (stream != null) {
          // any other stream property if needed
        }
        _messages = List<Map<String, dynamic>>.from(msgs); 
      });
      _initAgora();
      if (_isHost && _isLive) _loadRequests();
    }
    _scrollBottom();
  }
  
  Future<void> _loadRequests() async {
    if (_livestream == null) return;
    final reqs = await supabase.from('livestream_requests').select('*, user:profiles!livestream_requests_user_id_fkey(voice_name, real_name, is_revealed)').eq('stream_id', _livestream!['id']).eq('status', 'pending');
    if (mounted) setState(() => _requests = List<Map<String, dynamic>>.from(reqs));
  }

  void _subscribe() {
    supabase.channel('live-${widget.eventId}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'live_messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) async {
            final msg = payload.newRecord;
            if (msg['user_id'] == _uid) return;
            final a = await supabase.from('profiles').select('voice_name, real_name, is_revealed').eq('id', msg['user_id']).single();
            if (mounted) setState(() => _messages.add({...msg, 'author': a}));
            _scrollBottom();
          },
        )
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'live_streams', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) {
            _load(); // Reload stream status
          },
        )
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'livestream_requests',
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
    final profile = await supabase.from('profiles').select('voice_name, real_name, is_revealed').eq('id', _uid).single();
    setState(() => _messages.add({'user_id': _uid, 'message': text, 'created_at': DateTime.now().toIso8601String(), 'author': profile}));
    _scrollBottom();
    await supabase.from('live_messages').insert({'event_id': widget.eventId, 'user_id': _uid, 'message': text});
  }

  Future<void> _startLive() async {
    if (_livestream == null) {
      final res = await supabase.from('live_streams').insert({
        'event_id': widget.eventId,
        'status': 'live',
      }).select().single();
      _livestream = res;
      setState(() => _isLive = true);
    } else {
      await supabase.from('live_streams').update({'status': 'live'}).eq('id', _livestream!['id']);
      setState(() => _isLive = true);
    }
    await _joinChannel();
  }

  Future<void> _requestToJoin() async {
    if (_livestream == null) return;
    await supabase.from('livestream_requests').upsert({
      'stream_id': _livestream!['id'],
      'user_id': _uid,
      'status': 'pending',
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to host!')));
  }

  void _showRequestsSheet() {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Join Requests', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_requests.isEmpty) Text('No pending requests.'),
        ..._requests.map((r) {
          final u = r['user'];
          final name = u['is_revealed'] ? u['real_name'] : u['voice_name'];
          return ListTile(
            title: Text(name),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(LucideIcons.check, color: Colors.green), onPressed: () async {
                await supabase.from('livestream_requests').update({'status': 'accepted'}).eq('id', r['id']);
                if (mounted) Navigator.pop(context);
                // Also invite them officially via DM
                _inviteUserToLive(r['user_id']);
              }),
              IconButton(icon: const Icon(LucideIcons.x, color: Colors.red), onPressed: () async {
                await supabase.from('livestream_requests').update({'status': 'rejected'}).eq('id', r['id']);
                if (mounted) Navigator.pop(context);
              }),
            ]),
          );
        }),
      ]),
    )));
  }

  void _showInviteSheet() {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Container(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Invite Collaborators', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        // Simplified for this scope: just invite a random follower or let them search.
        // For now we'll just show a text input to simulate searching by username.
        TextField(
          decoration: const InputDecoration(hintText: 'Search username... (Not fully implemented)'),
          onSubmitted: (val) {
            // Placeholder: would search profiles and _inviteUserToLive(id)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User invited!')));
            Navigator.pop(context);
          },
        ),
      ]),
    )));
  }

  Future<void> _inviteUserToLive(String userId) async {
    if (_livestream == null) return;
    await supabase.from('direct_messages').insert({
      'sender_id': _uid,
      'receiver_id': userId,
      'message': 'I invited you to co-host my live stream!',
      'action_type': 'invite_live',
      'action_payload': { 'stream_id': _livestream!['id'], 'event_id': widget.eventId },
    });
  }

  Widget _buildPreLiveScreen() {
    final gold = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black12, border: Border.all(color: gold)),
              child: _localUserJoined && _engine != null ? AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0))) : const Icon(LucideIcons.camera),
            ),
            const SizedBox(height: 24),
            Text('Configure your Live', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _visibility,
              decoration: const InputDecoration(labelText: 'Choose who sees your live video'),
              items: ['Everyone', 'Followers Only'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _visibility = v!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Allow Requests to Join'),
              value: _allowRequests,
              activeColor: gold,
              onChanged: (v) => setState(() => _allowRequests = v),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _startLive,
                style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27))),
                child: Text('GO LIVE', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveGrid() {
    // Calculate slots based on participants. We show Host + Co-Hosts.
    // If only 1 person, full screen. If more, split.
    final totalUsers = 1 + _remoteUids.length; // Local + Remotes
    final gold = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Main Host Video
        Expanded(
          flex: totalUsers > 1 ? 1 : 2,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            child: _localUserJoined && _engine != null
                ? AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0))) 
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        // Grid for co-hosts/empty slots
        if (totalUsers > 1 || _allowRequests)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black87,
              child: GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 8, // Fixed 8 slots as requested
                itemBuilder: (context, index) {
                  if (index < _remoteUids.length) {
                    final rUid = _remoteUids[index];
                    return Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black),
                      clipBehavior: Clip.antiAlias,
                      child: _engine != null ? AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine!, canvas: VideoCanvas(uid: rUid), connection: RtcConnection(channelId: widget.eventId))) : const SizedBox.shrink(),
                    );
                  }
                  // Empty slot
                  return GestureDetector(
                    onTap: () {
                      if (_isHost) {
                        _showInviteSheet();
                      } else if (_allowRequests) {
                        _requestToJoin();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white10),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isHost ? LucideIcons.user_plus : LucideIcons.plus, color: Colors.white54, size: 24),
                            const SizedBox(height: 4),
                            Text(_isHost ? 'Invite' : 'Request', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    
    if (_isHost && !_isLive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prepare Live')),
        body: _buildPreLiveScreen(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // Header Overlay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(4)),
                child: const Text('LIVE now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(_title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_isHost) IconButton(
                icon: Badge(
                  isLabelVisible: _requests.isNotEmpty,
                  label: Text('${_requests.length}'),
                  child: const Icon(LucideIcons.users, color: Colors.white),
                ),
                onPressed: _showRequestsSheet,
              ),
              IconButton(icon: const Icon(LucideIcons.x, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ]),
          ),

          // Video Section
          Expanded(
            flex: 4,
            child: _isLive 
              ? _buildLiveGrid()
              : const Center(child: Text('Waiting for host...', style: TextStyle(color: Colors.white))),
          ),
          
          // Messages Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)]),
              ),
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(14),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final a = m['author'] as Map<String, dynamic>?;
                  final name = (a?['is_revealed'] == true && a?['real_name'] != null) ? a!['real_name'] : (a?['voice_name'] ?? 'Anon');
                  final isMine = m['user_id'] == _uid;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$name: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isMine ? gold : Colors.white70)),
                      Expanded(child: Text(m['message'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.white))),
                    ]),
                  );
                },
              ),
            ),
          ),
          
          // Input Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.black,
            child: Row(children: [
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
