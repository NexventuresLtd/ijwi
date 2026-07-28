import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase.dart';

class MentionText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  const MentionText(this.text, {super.key, this.style, this.maxLines, this.overflow});

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  static final Map<String, bool> _validUsersCache = {};
  List<InlineSpan> _spans = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parseText();
  }

  @override
  void didUpdateWidget(covariant MentionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _parseText();
    }
  }

  Future<void> _parseText() async {
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final gold = Theme.of(context).colorScheme.primary;
    final mentionStyle = baseStyle.copyWith(color: gold, fontWeight: FontWeight.w600);
    final hashtagStyle = baseStyle.copyWith(color: gold, fontWeight: FontWeight.w700);

    // Regex to match hashtag OR a mention with up to two words
    final regex = RegExp(r'(#\w+)|@([a-zA-Z0-9_]+(?:\s[a-zA-Z0-9_]+)?)');
    
    // First, find all potential mentions to query
    final Set<String> toQuery = {};
    for (final match in regex.allMatches(widget.text)) {
      if (match.group(1) == null) {
        // It's a mention
        final fullMatch = match.group(2)!;
        toQuery.add(fullMatch);
        final parts = fullMatch.split(' ');
        if (parts.length > 1) {
          toQuery.add(parts[0]);
        }
      }
    }

    // Query missing ones
    final missing = toQuery.where((u) => !_validUsersCache.containsKey(u)).toList();
    if (missing.isNotEmpty) {
      try {
        final orQuery = missing.map((m) => 'voice_name.ilike."$m"').join(',');
        final res = await supabase.from('profiles').select('voice_name').or(orQuery);
        final found = (res as List).map((e) => e['voice_name'].toString().toLowerCase()).toSet();
        for (final m in missing) {
          _validUsersCache[m] = found.contains(m.toLowerCase());
        }
      } catch (_) {
        // On error, assume false for missing
      }
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(widget.text)) {
      if (match.group(1) != null) {
        // Hashtag
        if (match.start > lastEnd) {
          spans.add(TextSpan(text: widget.text.substring(lastEnd, match.start), style: baseStyle));
        }
        final token = match.group(1)!;
        spans.add(TextSpan(
          text: token,
          style: hashtagStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _searchHashtag(context, token.substring(1)),
        ));
        lastEnd = match.end;
      } else {
        // Mention
        final fullMatch = match.group(2)!;
        final parts = fullMatch.split(' ');
        String validName = '';
        int matchLen = 0;

        if (_validUsersCache[fullMatch] == true) {
          validName = fullMatch;
          matchLen = fullMatch.length + 1; // +1 for @
        } else if (parts.length > 1 && _validUsersCache[parts[0]] == true) {
          validName = parts[0];
          matchLen = parts[0].length + 1;
        }

        if (validName.isNotEmpty) {
          final actualStart = match.start;
          final actualEnd = actualStart + matchLen;
          
          if (actualStart > lastEnd) {
            spans.add(TextSpan(text: widget.text.substring(lastEnd, actualStart), style: baseStyle));
          }
          spans.add(TextSpan(
            text: '@$validName',
            style: mentionStyle,
            recognizer: TapGestureRecognizer()..onTap = () => _navigateToProfile(context, validName),
          ));
          lastEnd = actualEnd;
        }
      }
    }

    if (lastEnd < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastEnd), style: baseStyle));
    }

    if (mounted) {
      setState(() {
        _spans = spans;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_spans.isEmpty) {
      return Text(widget.text, style: widget.style ?? DefaultTextStyle.of(context).style, maxLines: widget.maxLines, overflow: widget.overflow);
    }
    return RichText(text: TextSpan(children: _spans), maxLines: widget.maxLines, overflow: widget.overflow ?? TextOverflow.clip);
  }

  void _navigateToProfile(BuildContext context, String username) async {
    try {
      final res = await supabase.from('profiles').select('id').eq('voice_name', username).maybeSingle();
      if (res != null && context.mounted) {
        final myId = supabase.auth.currentUser?.id;
        if (myId != null && res['id'] == myId) {
          context.go('/profile');
        } else {
          context.push('/profile/${res['id']}');
        }
      }
    } catch (_) {}
  }

  void _searchHashtag(BuildContext context, String tag) {
    context.push('/explore?q=$tag');
  }
}
