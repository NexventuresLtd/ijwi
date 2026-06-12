import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/mention_overlay.dart';

class EditPostScreen extends StatefulWidget {
  final String postId;
  const EditPostScreen({super.key, required this.postId});
  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _titleLink = LayerLink();
  final _bodyLink = LayerLink();
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final post = await supabase.from('posts').select('title, body').eq('id', widget.postId).maybeSingle();
    if (post != null && mounted) {
      _title.text = post['title'] ?? '';
      _body.text = post['body'] ?? '';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await supabase.from('posts').update({
      'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      'body': _body.text.trim(),
    }).eq('id', widget.postId);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('posts').delete().eq('id', widget.postId);
      if (mounted) context.go('/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final dividerColor = Theme.of(context).dividerColor;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(), child: Icon(LucideIcons.x, size: 22, color: onSurface)),
              const SizedBox(width: 14),
              Text('Edit Post', style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500)),
              const Spacer(),
              // Delete button
              GestureDetector(
                onTap: _delete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))),
                  child: Text('Delete', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                ),
              ),
              const SizedBox(width: 8),
              // Save button
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(_saving ? '...' : 'Save', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // Content
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              MentionOverlay(
                controller: _title,
                layerLink: _titleLink,
                child: TextField(
                  controller: _title,
                  autofocus: true,
                  style: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w700, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w700, color: hintColor),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true, contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              Container(height: 0.5, margin: const EdgeInsets.symmetric(vertical: 4), color: dividerColor),
              MentionOverlay(
                controller: _body,
                layerLink: _bodyLink,
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  minLines: 10,
                  style: GoogleFonts.roboto(fontSize: 15, height: 1.7, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Share your voice...',
                    hintStyle: GoogleFonts.roboto(fontSize: 15, color: hintColor),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true, contentPadding: EdgeInsets.zero,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(height: 80),
            ]),
          )),

          // Bottom bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: dividerColor))),
            child: Row(children: [
              Icon(LucideIcons.pen_line, size: 14, color: hintColor),
              const SizedBox(width: 6),
              Text('Editing', style: TextStyle(fontSize: 12, color: hintColor)),
              const Spacer(),
              Text('${_body.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words', style: TextStyle(fontSize: 11, color: hintColor)),
            ]),
          ),
        ]),
      ),
    );
  }
}
