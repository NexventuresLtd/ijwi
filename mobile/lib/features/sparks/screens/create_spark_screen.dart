import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/publish_success_screen.dart';

class CreateSparkScreen extends StatefulWidget {
  const CreateSparkScreen({super.key});
  @override
  State<CreateSparkScreen> createState() => _CreateSparkScreenState();
}

class _CreateSparkScreenState extends State<CreateSparkScreen> {
  File? _video;
  String? _videoName;
  final _titleCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _agreed = false;
  bool _uploading = false;
  String? _error;
  VideoPlayerController? _previewCtrl;

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: source, maxDuration: const Duration(seconds: 60));
    if (file == null) return;
    final videoFile = File(file.path);
    _previewCtrl?.dispose();
    final ctrl = VideoPlayerController.file(videoFile);
    await ctrl.initialize();
    if (mounted) setState(() {
      _video = videoFile;
      _videoName = file.name;
      _previewCtrl = ctrl;
    });
  }

  bool get _canPublish => _video != null && _captionCtrl.text.trim().isNotEmpty && _agreed && !_uploading;

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() { _uploading = true; _error = null; });

    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = _videoName?.split('.').last ?? 'mp4';
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await _video!.readAsBytes();

      await supabase.storage.from('shorts').uploadBinary(path, bytes);
      final publicUrl = supabase.storage.from('shorts').getPublicUrl(path);

      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().toLowerCase().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .take(5)
          .toList();

      final res = await supabase.from('posts').insert({
        'author_id': uid,
        'content_type': 'short',
        'title': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        'body': _captionCtrl.text.trim(),
        'video_url': publicUrl,
        'is_anonymous': false,
        'tags': tags,
        'reaction_fire': 0,
        'reaction_amen': 0,
        'reaction_healed': 0,
        'reaction_needed': 0,
        'reaction_sharing': 0,
      }).select('id').single();

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PublishSuccessScreen(postId: res['id'], type: 'spark')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  void dispose() {
    _previewCtrl?.dispose();
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final border = isDark ? IjwiColors.darkBorder2 : IjwiColors.lightBorder2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(LucideIcons.x, size: 22), onPressed: () => context.pop()),
        title: Text('Share a Spark', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _canPublish ? _publish : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: const Color(0xFF1A1814),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(_uploading ? 'Uploading...' : 'Publish', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Subtitle
          Text(
            'A moment of faith — a testimony, a worship clip, a word from God.',
            style: TextStyle(fontSize: 13, color: text3, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Video picker
          if (_video == null)
            _VideoPickerBox(gold: gold, isDark: isDark, border: border, onCamera: () => _pickVideo(ImageSource.camera), onGallery: () => _pickVideo(ImageSource.gallery))
          else
            _VideoPreviewBox(ctrl: _previewCtrl!, name: _videoName!, onRemove: () => setState(() { _previewCtrl?.dispose(); _previewCtrl = null; _video = null; _videoName = null; })),

          const SizedBox(height: 20),

          // Title
          TextField(
            controller: _titleCtrl,
            maxLength: 80,
            style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Title (optional)',
              hintStyle: GoogleFonts.fraunces(fontSize: 18, color: text3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: gold)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Caption
          TextField(
            controller: _captionCtrl,
            maxLength: 500,
            maxLines: 4,
            minLines: 3,
            style: GoogleFonts.dmSans(fontSize: 14, height: 1.6),
            decoration: InputDecoration(
              hintText: 'What\'s happening in this video? Share the testimony, the word, the moment...',
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: text3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: gold)),
              contentPadding: const EdgeInsets.all(14),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),

          // Tags
          TextField(
            controller: _tagsCtrl,
            style: GoogleFonts.dmSans(fontSize: 13),
            decoration: InputDecoration(
              hintText: '#worship, #testimony, #healing',
              hintStyle: GoogleFonts.dmSans(fontSize: 13, color: text3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: gold)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Content guideline checkbox
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                border: Border.all(color: _agreed ? gold : border),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _agreed ? gold : border, width: 2),
                    color: _agreed ? gold : Colors.transparent,
                  ),
                  child: _agreed ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.5, color: isDark ? IjwiColors.darkText2 : IjwiColors.lightText2, height: 1.5),
                    children: [
                      const TextSpan(text: 'I confirm this content glorifies God and is appropriate for a Christian community. No profanity, sexual content, or content that dishonors the Lord. '),
                      TextSpan(text: 'Ephesians 4:29', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
              ]),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.5)),
            ),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _VideoPickerBox extends StatelessWidget {
  final Color gold;
  final bool isDark;
  final Color border;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _VideoPickerBox({required this.gold, required this.isDark, required this.border, required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.3), width: 1.5),
        color: gold.withValues(alpha: 0.04),
      ),
      child: Column(children: [
        Icon(LucideIcons.video, size: 36, color: gold),
        const SizedBox(height: 12),
        Text('Select a video', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Record or choose from gallery', style: TextStyle(fontSize: 12, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _PickBtn(icon: LucideIcons.camera, label: 'Record', gold: gold, onTap: onCamera),
          const SizedBox(width: 16),
          _PickBtn(icon: LucideIcons.image, label: 'Gallery', gold: gold, onTap: onGallery),
        ]),
      ]),
    );
  }
}

class _PickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gold;
  final VoidCallback onTap;
  const _PickBtn({required this.icon, required this.label, required this.gold, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: gold.withValues(alpha: 0.1),
          border: Border.all(color: gold.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: gold),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gold)),
        ]),
      ),
    );
  }
}

class _VideoPreviewBox extends StatelessWidget {
  final VideoPlayerController ctrl;
  final String name;
  final VoidCallback onRemove;
  const _VideoPreviewBox({required this.ctrl, required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        AspectRatio(
          aspectRatio: ctrl.value.aspectRatio.clamp(0.5, 2.0),
          child: VideoPlayer(ctrl),
        ),
        Positioned(top: 8, right: 8, child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
            child: const Icon(LucideIcons.x, color: Colors.white, size: 16),
          ),
        )),
        Positioned(bottom: 8, left: 8, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
        )),
      ]),
    );
  }
}
