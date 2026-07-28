import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase.dart';

class EssayService {
  static final _supabase = supabase; // From core/supabase.dart

  // Save or update an essay draft
  static Future<String> saveEssay({
    String? id,
    required String title,
    String? coverImageUrl,
    required Map<String, dynamic> content,
    required String contentHtml,
    required int readingTimeMins,
    required List<String> topics,
    String? bgColorHex,
    String? musicUrl,
    required bool isPublished,
    bool isAnonymous = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final payload = {
      'author_id': userId,
      'title': title,
      'cover_image_url': coverImageUrl,
      'content': content,
      'content_html': contentHtml,
      'reading_time_mins': readingTimeMins,
      'topics': topics,
      'music_url': musicUrl,
      'is_published': isPublished,
      'is_anonymous': isAnonymous,
    };

    if (isPublished) {
      payload['published_at'] = DateTime.now().toUtc().toIso8601String();
    }

    if (id != null && id.isNotEmpty) {
      final response = await _supabase
          .from('essays')
          .update(payload)
          .eq('id', id)
          .select('id')
          .single();
      return response['id'] as String;
    } else {
      final response = await _supabase
          .from('essays')
          .insert(payload)
          .select('id')
          .single();
      return response['id'] as String;
    }
  }

  // Get essays (feed)
  static Future<List<Map<String, dynamic>>> getPublishedEssays() async {
    return await _supabase
        .from('essays')
        .select('*, author:profiles(id, voice_name, avatar_url), analytics:essay_analytics(*)')
        .eq('is_published', true)
        .order('published_at', ascending: false);
  }

  // Record an essay read
  static Future<void> incrementReadCount(String essayId) async {
    try {
      final current = await _supabase.from('essay_analytics').select('reads').eq('essay_id', essayId).maybeSingle();
      if (current == null) {
        await _supabase.from('essay_analytics').insert({'essay_id': essayId, 'reads': 1});
      } else {
        await _supabase.from('essay_analytics').update({'reads': (current['reads'] as int) + 1}).eq('essay_id', essayId);
      }
    } catch (e) {
      // Ignored for analytics
    }
  }

  // Record completion
  static Future<void> incrementCompletionCount(String essayId) async {
    try {
      final current = await _supabase.from('essay_analytics').select('completions').eq('essay_id', essayId).maybeSingle();
      if (current != null) {
        await _supabase.from('essay_analytics').update({'completions': (current['completions'] as int) + 1}).eq('essay_id', essayId);
      }
    } catch (e) {
      // Ignored
    }
  }

  // Save a highlight
  static Future<void> saveHighlight({
    required String essayId,
    required String highlightedText,
    required int startIndex,
    required int endIndex,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('essay_highlights').insert({
      'essay_id': essayId,
      'reader_id': userId,
      'highlighted_text': highlightedText,
      'start_index': startIndex,
      'end_index': endIndex,
    });
  }
}
