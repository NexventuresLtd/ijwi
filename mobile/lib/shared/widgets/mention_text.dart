import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase.dart';

class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  const MentionText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final mentionStyle = baseStyle.copyWith(color: gold, fontWeight: FontWeight.w600);
    final hashtagStyle = baseStyle.copyWith(color: gold, fontWeight: FontWeight.w700);

    final regex = RegExp(r'(@\w+|#\w+)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      final token = match.group(0)!;
      if (token.startsWith('@')) {
        final username = token.substring(1);
        spans.add(TextSpan(
          text: token,
          style: mentionStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _navigateToProfile(context, username),
        ));
      } else {
        spans.add(TextSpan(
          text: token,
          style: hashtagStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _searchHashtag(context, token.substring(1)),
        ));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    if (spans.isEmpty) {
      return Text(text, style: baseStyle, maxLines: maxLines, overflow: overflow);
    }

    return RichText(text: TextSpan(children: spans), maxLines: maxLines, overflow: overflow ?? TextOverflow.clip);
  }

  void _navigateToProfile(BuildContext context, String username) async {
    try {
      final res = await supabase.from('profiles').select('id').eq('voice_name', username).maybeSingle();
      if (res != null && context.mounted) context.push('/profile/${res['id']}');
    } catch (_) {}
  }

  void _searchHashtag(BuildContext context, String tag) {
    context.push('/explore?q=$tag');
  }
}
