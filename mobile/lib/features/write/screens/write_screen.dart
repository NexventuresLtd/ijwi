import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ijwi_mobile/core/image_helper.dart';
import '../../../core/supabase.dart';
import '../../../shared/widgets/mention_text_editing_controller.dart';
import '../../../core/theme.dart';
import '../../../core/storage_helper.dart';
import '../../../shared/widgets/mention_overlay.dart';
import '../../camera/screens/custom_camera_screen.dart';

class WriteScreen extends StatefulWidget {
  const WriteScreen({super.key});
  @override
  State<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends State<WriteScreen> {
  final _title = TextEditingController();
  final _body = MentionTextEditingController();
  final _titleLink = LayerLink();
  final _bodyLink = LayerLink();
  final _titleMentionKey = GlobalKey<MentionOverlayState>();
  final _bodyMentionKey = GlobalKey<MentionOverlayState>();
  String _type = 'story';
  String _audience = 'anyone';
  bool _loading = false;
  String? _profileName;
  String? _avatarUrl;
  File? _coverImage;
  bool _isAnonymous = false;

  final _types = ['story', 'devotional', 'spoken_word', 'prayer_request', 'question', 'encouragement', 'letter'];

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final p = await supabase.from('profiles').select('voice_name, avatar_url, anonymous_default').eq('id', uid).maybeSingle();
    if (p != null && mounted) setState(() { _profileName = p['voice_name']; _avatarUrl = p['avatar_url']; _isAnonymous = p['anonymous_default'] == true; });
  }

  bool get _canPublish => _body.text.trim().isNotEmpty && !_loading;

  void _confirmDiscard(BuildContext context) {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      context.pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('Your changes will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(ctx); context.pop(); }, child: const Text('Discard', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == 'camera') {
      final String? path = await context.push('/camera?video=false');
      if (path != null) {
        final fixedPath = await ImageHelper.compressAndFixRotation(path);
        setState(() => _coverImage = File(fixedPath));
      }
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final fixedPath = await ImageHelper.compressAndFixRotation(result.files.first.path!);
      setState(() => _coverImage = File(fixedPath));
    }
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _loading = true);
    final uid = supabase.auth.currentUser!.id;
    String? coverUrl;
    if (_coverImage != null) {
      final ext = _coverImage!.path.split('.').last;
      final path = '$uid/post_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await _coverImage!.readAsBytes();
      coverUrl = await uploadToStorage(bucket: 'covers', path: path, bytes: bytes);
    }
    final res = await supabase.from('posts').insert({
      'author_id': uid,
      'content_type': _type,
      'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      'body': _body.text.trim(),
      'cover_image_url': coverUrl,
      'status': 'published',
      'is_anonymous': _isAnonymous,
    }).select('id').single();
    // Notify mentions
    final fullText = '${_title.text} ${_body.text}';
    notifyMentions(fullText, postId: res['id']);
    if (mounted) {
      if (mounted) context.go('/publish-success/${res['id']}/${_type.replaceAll('_', ' ')}');
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

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ─── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
            child: Row(children: [
              GestureDetector(
                onTap: () => _confirmDiscard(context),
                child: Icon(LucideIcons.x, size: 22, color: onSurface),
              ),
              const SizedBox(width: 14),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1), border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5)),
                child: ClipOval(
                  child: _avatarUrl != null && _avatarUrl!.startsWith('http')
                      ? Image.network(_avatarUrl!, width: 34, height: 34, fit: BoxFit.cover)
                      : Center(child: Text((_profileName ?? '?')[0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gold))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_profileName ?? '', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
                GestureDetector(
                  onTap: () => _showAudiencePicker(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_audience == 'anyone' ? LucideIcons.globe : LucideIcons.users, size: 11, color: gold),
                    const SizedBox(width: 3),
                    Text(_audience == 'anyone' ? 'Anyone' : 'Followers', style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w500)),
                    Icon(LucideIcons.chevron_down, size: 12, color: gold),
                  ]),
                ),
              ])),
              ElevatedButton(
                onPressed: _canPublish ? _publish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canPublish ? gold : (isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                  foregroundColor: _canPublish ? Colors.white : hintColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(_loading ? '...' : 'Publish', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // ─── Content ──────────────────────────────────────────
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 14),

              // Type chips
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = _types[i];
                    final active = t == _type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: active ? gold.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: active ? gold : dividerColor, width: active ? 1 : 0.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(t.replaceAll('_', ' '), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: active ? gold : hintColor)),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Cover image preview
              if (_coverImage != null) ...[
                GestureDetector(
                  onLongPress: () => setState(() => _coverImage = null),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Stack(children: [
                        Positioned.fill(child: Image.file(_coverImage!, fit: BoxFit.cover)),
                        Positioned(top: 6, right: 6, child: GestureDetector(
                          onTap: () => setState(() => _coverImage = null),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                            child: const Icon(LucideIcons.x, color: Colors.white, size: 13),
                          ),
                        )),
                        Positioned(bottom: 6, left: 6, child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Cover · Long-press to remove', style: TextStyle(color: Colors.white, fontSize: 10)),
                        )),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Title
              MentionOverlay(
                key: _titleMentionKey,
                controller: _title,
                layerLink: _titleLink,
                child: TextField(
                  controller: _title,
                  autofocus: true,
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Title (optional)',
                    hintStyle: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: hintColor),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),

              // Divider
              const SizedBox(height: 8),

              // Body
              MentionOverlay(
                key: _bodyMentionKey,
                controller: _body,
                layerLink: _bodyLink,
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  minLines: 10,
                  style: GoogleFonts.montserrat(fontSize: 15, height: 1.7, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Share your voice...',
                    hintStyle: GoogleFonts.poppins(fontSize: 15, color: hintColor),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent, filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                ),
              ),

              const SizedBox(height: 80),
            ]),
          )),

          // ─── Bottom ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: dividerColor))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Hashtag suggestions
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['testimony', 'worship', 'faith', 'prayer', 'healing', 'grace', 'hope'].map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { _body.text = '${_body.text} #$tag'; _body.selection = TextSelection.collapsed(offset: _body.text.length); setState(() {}); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withValues(alpha: 0.2))),
                        child: Text('#$tag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gold)),
                      ),
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(LucideIcons.type, size: 14, color: hintColor),
                const SizedBox(width: 6),
                Text(_type.replaceAll('_', ' '), style: TextStyle(fontSize: 12, color: hintColor, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${_body.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words', style: TextStyle(fontSize: 11, color: hintColor)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickCoverImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _coverImage != null ? gold.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _coverImage != null ? gold : hintColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.image, size: 13, color: _coverImage != null ? gold : hintColor),
                      const SizedBox(width: 4),
                      Text('Cover', style: TextStyle(fontSize: 11, color: _coverImage != null ? gold : hintColor, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  void _showAudiencePicker(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Text('Who can see this?', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w500, color: onSurface)),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(LucideIcons.globe, color: _audience == 'anyone' ? gold : Theme.of(context).hintColor),
            title: Text('Anyone', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('Visible to everyone on Ijwi', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            trailing: _audience == 'anyone' ? Icon(LucideIcons.check, size: 18, color: gold) : null,
            onTap: () { setState(() => _audience = 'anyone'); Navigator.pop(ctx); },
          ),
          ListTile(
            leading: Icon(LucideIcons.users, color: _audience == 'followers' ? gold : Theme.of(context).hintColor),
            title: Text('Followers only', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('Only people who follow you', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            trailing: _audience == 'followers' ? Icon(LucideIcons.check, size: 18, color: gold) : null,
            onTap: () { setState(() => _audience = 'followers'); Navigator.pop(ctx); },
          ),
        ]),
      )),
    );
  }
}
