import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase.dart';
import 'cache_service.dart';

/// Tracks user navigation patterns and prefetches data for predicted screens.
class PrefetchService {
  PrefetchService._();
  static final PrefetchService instance = PrefetchService._();

  // Navigation transition counts: current_screen -> {next_screen -> count}
  final Map<String, Map<String, int>> _transitions = {};
  String? _currentScreen;
  Timer? _bgSyncTimer;

  // ── INIT ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadTransitions();
    _startBackgroundSync();
  }

  void dispose() {
    _bgSyncTimer?.cancel();
  }

  // ── RECORD NAVIGATION ──────────────────────────────────────────────────
  void recordNavigation(String screen) {
    if (_currentScreen != null && _currentScreen != screen) {
      _transitions.putIfAbsent(_currentScreen!, () => {});
      _transitions[_currentScreen!]!.update(screen, (v) => v + 1, ifAbsent: () => 1);
      _saveTransitions();
    }
    _currentScreen = screen;
    _prefetchForScreen(screen);
  }

  // ── PREDICTION ─────────────────────────────────────────────────────────
  /// Returns top 2 most likely next screens based on Markov chain.
  List<String> predictNextScreens(String currentScreen) {
    final next = _transitions[currentScreen];
    if (next == null || next.isEmpty) return [];

    final sorted = next.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(2).map((e) => e.key).toList();
  }

  // ── PREFETCH ───────────────────────────────────────────────────────────
  void _prefetchForScreen(String screen) {
    final predictions = predictNextScreens(screen);
    for (final predicted in predictions) {
      _prefetchDataFor(predicted);
    }
  }

  Future<void> _prefetchDataFor(String screen) async {
    final cache = CacheService.instance;

    try {
      switch (screen) {
        case '/feed':
          if (cache.get('prefetch_feed') == null) {
            final posts = await supabase
                .from('posts')
                .select('*, author:profiles!posts_author_id_fkey(id, voice_name, avatar_url, is_revealed, real_name)')
                .or('status.eq.published,status.is.null')
                .order('created_at', ascending: false)
                .limit(20);
            cache.set('prefetch_feed', posts, const Duration(minutes: 3));
          }
          break;

        case '/events':
          if (cache.get('prefetch_events') == null) {
            final events = await supabase
                .from('events')
                .select('*, organizer:profiles!events_organizer_id_fkey(id, voice_name, avatar_url)')
                .not('tags', 'cs', ['quick_live'])
                .gte('event_date', DateTime.now().toIso8601String())
                .order('event_date')
                .limit(20);
            cache.set('prefetch_events', events, const Duration(minutes: 3));
          }
          break;

        case '/dms':
          if (cache.get('prefetch_dms') == null) {
            final uid = supabase.auth.currentUser?.id;
            if (uid != null) {
              final messages = await supabase
                  .from('direct_messages')
                  .select('sender_id, receiver_id, message, created_at, read_at')
                  .or('sender_id.eq.$uid,receiver_id.eq.$uid')
                  .order('created_at', ascending: false)
                  .limit(50);
              cache.set('prefetch_dms', messages, const Duration(minutes: 2));
            }
          }
          break;

        case '/profile':
          if (cache.get('prefetch_profile') == null) {
            final uid = supabase.auth.currentUser?.id;
            if (uid != null) {
              final profile = await supabase.from('profiles').select('*').eq('id', uid).maybeSingle();
              if (profile != null) {
                cache.set('prefetch_profile', profile, const Duration(minutes: 5));
              }
            }
          }
          break;
      }
    } catch (_) {
      // Prefetch is best-effort, never block on failure
    }
  }

  // ── BACKGROUND SYNC ───────────────────────────────────────────────────
  void _startBackgroundSync() {
    _bgSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _backgroundSync());
  }

  Future<void> _backgroundSync() async {
    if (supabase.auth.currentUser == null) return;

    // Refresh frequently accessed data in background
    try {
      await _prefetchDataFor('/feed');
      await _prefetchDataFor('/dms');
      await _prefetchDataFor('/events');
    } catch (_) {}
  }

  // ── PERSISTENCE ────────────────────────────────────────────────────────
  Future<void> _loadTransitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('ijwi_nav_transitions');
      if (raw != null) {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(
          (raw.isNotEmpty) ? _simpleJsonDecode(raw) : {},
        );
        for (final entry in decoded.entries) {
          _transitions[entry.key] = Map<String, int>.from(entry.value as Map);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveTransitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only top transitions to avoid unbounded growth
      final trimmed = <String, Map<String, int>>{};
      for (final entry in _transitions.entries) {
        final sorted = entry.value.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        trimmed[entry.key] = Map.fromEntries(sorted.take(10));
      }
      await prefs.setString('ijwi_nav_transitions', jsonEncode(trimmed));
    } catch (_) {}
  }

  Map<String, dynamic> _simpleJsonDecode(String raw) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(raw) as Map,
      );
    } catch (_) {
      return {};
    }
   }
}
