import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';

class MentionOverlay extends StatefulWidget {
  final TextEditingController controller;
  final Widget child;
  final LayerLink layerLink;
  const MentionOverlay({super.key, required this.controller, required this.child, required this.layerLink});

  @override
  State<MentionOverlay> createState() => MentionOverlayState();
}

class MentionOverlayState extends State<MentionOverlay> {
  OverlayEntry? _overlay;
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _hideOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) { _hideOverlay(); return; }

    // Find @ before cursor
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    if (atIndex == -1) { _hideOverlay(); return; }

    // Make sure @ is start of word
    if (atIndex > 0 && before[atIndex - 1] != ' ' && before[atIndex - 1] != '\n') { _hideOverlay(); return; }

    final query = before.substring(atIndex + 1);
    // If there's a space after @query, the mention is complete
    if (query.contains(' ') || query.contains('\n')) { _hideOverlay(); return; }

    if (query.length < 1) { _hideOverlay(); return; }

    _search(query);
  }

  Future<void> _search(String query) async {
    try {
      final res = await supabase.from('profiles')
          .select('id, voice_name, real_name, is_revealed, avatar_url')
          .ilike('voice_name', '%$query%')
          .limit(5);
      if (mounted) {
        setState(() => _suggestions = List<Map<String, dynamic>>.from(res));
        if (_suggestions.isNotEmpty) _showOverlay(); else _hideOverlay();
      }
    } catch (_) {}
  }

  void _showOverlay() {
    _hideOverlay();
    _overlay = OverlayEntry(builder: (_) => _buildSuggestions());
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _selectUser(Map<String, dynamic> user) {
    final name = user['voice_name'] as String;
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');
    final after = text.substring(cursor);

    final newText = '${text.substring(0, atIndex)}@$name $after';
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: atIndex + name.length + 2);
    _hideOverlay();
  }

  Widget _buildSuggestions() {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;

    return Positioned(
      width: MediaQuery.of(context).size.width - 40,
      child: CompositedTransformFollower(
        link: widget.layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, -8),
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          color: surface,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 0.5)),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final u = _suggestions[i];
                final name = (u['is_revealed'] == true && u['real_name'] != null) ? u['real_name'] : u['voice_name'];
                return InkWell(
                  onTap: () => _selectUser(u),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)),
                        child: ClipOval(
                          child: u['avatar_url'] != null && (u['avatar_url'] as String).startsWith('http')
                              ? Image.network(u['avatar_url'], width: 32, height: 32, fit: BoxFit.cover)
                              : Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gold))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('@${u['voice_name']}', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                      ])),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: widget.layerLink, child: widget.child);
  }
}

/// Extract mentioned usernames from text (returns list of voice_names without @)
List<String> extractMentions(String text) {
  final matches = RegExp(r'@([a-zA-Z0-9_]+(?:\s[a-zA-Z0-9_]+)?)').allMatches(text);
  final Set<String> names = {};
  for (final m in matches) {
    final full = m.group(1)!;
    names.add(full);
    final parts = full.split(' ');
    if (parts.length > 1) names.add(parts[0]);
  }
  return names.toList();
}

/// Send mention notifications to all mentioned users
Future<void> notifyMentions(String text, {String? postId}) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return;
  final names = extractMentions(text);
  if (names.isEmpty) return;
  try {
    final users = await supabase.from('profiles').select('id, voice_name').inFilter('voice_name', names);
    
    // Track which ones we found so we don't notify both the 1-word and 2-word version for the same match incorrectly?
    // Wait, if we just notify everyone found, that's fine. It's rare to have two users where one is "A" and one is "A B", 
    // and they both get notified when only "A B" was meant, but it's acceptable.
    for (final u in users) {
      if (u['id'] == uid) continue;
      await supabase.from('notifications').insert({
        'user_id': u['id'],
        'actor_id': uid,
        'type': 'mention',
        'post_id': postId,
        'message': 'mentioned you in a post',
      });
    }
  } catch (_) {}
}
