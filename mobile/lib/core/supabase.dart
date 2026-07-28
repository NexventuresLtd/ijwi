import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_service.dart';

const supabaseUrl = 'https://cfdudlfwvbnqltjppcep.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmZHVkbGZ3dmJucWx0anBwY2VwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NDQ5MzIsImV4cCI6MjA5MTQyMDkzMn0.77JJ3OQhofD4fsNUXjAjsf--6u8DLtS3cjo2r_YscrA';

SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
}

/// Helper extension for cached queries
extension SupabaseCacheExt on SupabaseClient {
  Future<dynamic> cachedQuery(String cacheKey, Future<dynamic> Function() queryFn, {Duration ttl = const Duration(minutes: 5)}) async {
    final cached = CacheService.instance.get(cacheKey);
    if (cached != null) {
      // Refresh in background
      queryFn().then((data) => CacheService.instance.set(cacheKey, data, ttl)).catchError((_) {});
      return cached;
    }
    final data = await queryFn();
    CacheService.instance.set(cacheKey, data, ttl);
    return data;
  }
}
