import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';

/// Ensures a public bucket exists (creates it if missing) then uploads bytes.
/// Returns the public URL of the uploaded file, or null on failure.
Future<String?> uploadToStorage({
  required String bucket,
  required String path,
  required Uint8List bytes,
  String contentType = 'image/jpeg',
}) async {
  final storage = supabase.storage;

  // Try to create bucket — silently ignore if it already exists
  try {
    await storage.createBucket(bucket, const BucketOptions(public: true));
  } catch (_) {
    // Bucket already exists or no permission to create — continue
  }

  // Upload
  await storage.from(bucket).uploadBinary(path, bytes);
  return storage.from(bucket).getPublicUrl(path);
}
