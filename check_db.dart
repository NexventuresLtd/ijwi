import 'dart:io';

void main() async {
  // Read supabase/migrations/* to find exactly how live_messages is created
  final dir = Directory('supabase/migrations');
  final files = dir.listSync();
  for (var f in files) {
    if (f is File) {
      final content = f.readAsStringSync();
      if (content.contains('CREATE TABLE') && content.contains('live_messages')) {
        print(f.path);
        final lines = content.split('\n');
        bool inTable = false;
        for (var line in lines) {
          if (line.contains('CREATE TABLE') && line.contains('live_messages')) {
            inTable = true;
          }
          if (inTable) {
            print(line);
            if (line.contains(';')) {
              inTable = false;
            }
          }
        }
      }
    }
  }
}
