import 'package:supabase/supabase.dart';
void main() async {
  final supabase = SupabaseClient('http://localhost:54321', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1cGFiYXNlIiwicm9sZSI6ImFub24iLCJpYXQiOjE2ODg1Njg4OTAsImV4cCI6MTk5MjM1MjY0MH0.x');
  final res = await supabase.from('profiles').select('voice_name').limit(10);
  print(res);
}
