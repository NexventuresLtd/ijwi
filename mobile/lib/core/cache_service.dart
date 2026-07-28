import 'dart:convert';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory LRU cache with TTL + persistent fallback via SharedPreferences.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const int _maxEntries = 200;
  static const Duration _defaultTtl = Duration(minutes: 5);

  final LinkedHashMap<String, _CacheEntry> _mem = LinkedHashMap();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── GET ──────────────────────────────────────────────────────────────────
  /// Returns cached data if available and not expired, otherwise null.
  T? get<T>(String key) {
    // Memory first
    final entry = _mem[key];
    if (entry != null) {
      if (entry.isValid) {
        // Move to end (LRU refresh)
        _mem.remove(key);
        _mem[key] = entry;
        return entry.data as T?;
      } else {
        _mem.remove(key);
      }
    }

    // Persistent fallback
    final raw = _prefs?.getString('cache_$key');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final expiry = DateTime.fromMillisecondsSinceEpoch(map['exp'] as int);
        if (expiry.isAfter(DateTime.now())) {
          final data = map['data'];
          set(key, data, Duration(milliseconds: expiry.difference(DateTime.now()).inMilliseconds));
          return data as T?;
        } else {
          _prefs?.remove('cache_$key');
        }
      } catch (_) {
        _prefs?.remove('cache_$key');
      }
    }

    return null;
  }

  // ── SET ──────────────────────────────────────────────────────────────────
  void set(String key, dynamic data, [Duration ttl = _defaultTtl]) {
    if (_mem.length >= _maxEntries) {
      _mem.remove(_mem.keys.first); // evict oldest
    }
    _mem[key] = _CacheEntry(data: data, expiry: DateTime.now().add(ttl));
  }

  /// Persist to disk (for critical data that should survive restarts).
  Future<void> persist(String key, dynamic data, [Duration ttl = const Duration(hours: 1)]) async {
    set(key, data, ttl);
    final exp = DateTime.now().add(ttl).millisecondsSinceEpoch;
    try {
      await _prefs?.setString('cache_$key', jsonEncode({'data': data, 'exp': exp}));
    } catch (_) {}
  }

  // ── INVALIDATION ────────────────────────────────────────────────────────
  void invalidate(String key) {
    _mem.remove(key);
    _prefs?.remove('cache_$key');
  }

  void invalidatePrefix(String prefix) {
    final keys = _mem.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      _mem.remove(k);
    }
    // Clean persisted
    final allKeys = _prefs?.getKeys() ?? {};
    for (final k in allKeys) {
      if (k.startsWith('cache_$prefix')) {
        _prefs?.remove(k);
      }
    }
  }

  void clear() {
    _mem.clear();
    final allKeys = _prefs?.getKeys() ?? {};
    for (final k in allKeys) {
      if (k.startsWith('cache_')) {
        _prefs?.remove(k);
      }
    }
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;
  const _CacheEntry({required this.data, required this.expiry});
  bool get isValid => expiry.isAfter(DateTime.now());
}
