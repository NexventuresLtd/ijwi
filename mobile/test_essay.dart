import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  var env = DotEnv(includePlatformEnvironment: true)..load();
  final supabaseUrl = env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    print('Missing SUPABASE_URL or SUPABASE_ANON_KEY');
    exit(1);
  }

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final res = await client
        .from('essays')
        .select('*, author:profiles(id, voice_name, avatar_url), analytics:essay_analytics(*)')
        .eq('is_published', true)
        .order('published_at', ascending: false);
    print('Essays fetched: \${res.length}');
  } catch (e) {
    print('Error: \$e');
  }
  exit(0);
}
