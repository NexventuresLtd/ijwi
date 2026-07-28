import 'package:flutter/material.dart';

class MentionTextEditingController extends TextEditingController {
  MentionTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final gold = Theme.of(context).colorScheme.primary;
    final mentionStyle = style?.copyWith(color: gold, fontWeight: FontWeight.w600) ?? TextStyle(color: gold, fontWeight: FontWeight.w600);
    final hashtagStyle = style?.copyWith(color: gold, fontWeight: FontWeight.w700) ?? TextStyle(color: gold, fontWeight: FontWeight.w700);

    final regex = RegExp(r'(#\w+)|@([a-zA-Z0-9_]+(?:\s[a-zA-Z0-9_]+)?)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: style));
      }
      
      final fullMatch = match.group(0)!;
      if (fullMatch.startsWith('@')) {
        spans.add(TextSpan(text: fullMatch, style: mentionStyle));
      } else {
        spans.add(TextSpan(text: fullMatch, style: hashtagStyle));
      }
      
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return TextSpan(style: style, children: spans);
  }
}
