import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EssayDraftService {
  static const String _draftKey = 'essay_draft_content';
  static const String _titleKey = 'essay_draft_title';
  
  Timer? _timer;

  // Auto save every X seconds if content changes
  void startAutoSave(
    Duration interval,
    ValueGetter<String> getTitle,
    ValueGetter<Map<String, dynamic>> getContent,
  ) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      final title = getTitle();
      final content = getContent();
      await saveDraft(title, content);
    });
  }

  void stopAutoSave() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> saveDraft(String title, Map<String, dynamic> content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleKey, title);
    await prefs.setString(_draftKey, jsonEncode(content));
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_titleKey);
    final contentStr = prefs.getString(_draftKey);
    
    if (title != null || contentStr != null) {
      return {
        'title': title ?? '',
        'content': contentStr != null ? jsonDecode(contentStr) : null,
      };
    }
    return null;
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_titleKey);
    await prefs.remove(_draftKey);
  }
}
