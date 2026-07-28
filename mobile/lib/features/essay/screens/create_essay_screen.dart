import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:audioplayers/audioplayers.dart';

import 'package:file_picker/file_picker.dart';
import 'package:ijwi_mobile/core/image_helper.dart';

import '../../../core/supabase.dart';
import '../../../core/storage_helper.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/mention_overlay.dart';
import '../services/essay_service.dart';
import '../services/essay_draft_service.dart';
import '../utils/reading_time_calculator.dart';

class CreateEssayScreen extends StatefulWidget {
  const CreateEssayScreen({super.key});
  @override
  State<CreateEssayScreen> createState() => _CreateEssayScreenState();
}

class _CreateEssayScreenState extends State<CreateEssayScreen> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  late final quill.QuillController _quillController;
  final _quillFocus = FocusNode();
  final EssayDraftService _draftService = EssayDraftService();

  String? _profileName;
  bool _isAnonymous = false;

  bool _publishing = false;
  bool _discarded = false;
  
  // Essay metadata
  File? _coverImageFile;
  String? _coverImageUrl;
  List<String> _topics = []; // Will be populated from hashtags
  String? _bgColorHex;

  String? _musicUrl;
  
  // Mention overlays
  final _titleLink = LayerLink();
  final _titleMentionKey = GlobalKey<MentionOverlayState>();

  bool _isAutoSaving = false;
  DateTime? _lastSaved;

  bool get _canPublish => _titleCtrl.text.trim().isNotEmpty && !_quillController.document.isEmpty() && !_publishing;

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    _loadProfile();
    _initDraft();
  }

  Future<void> _loadProfile() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final p = await supabase.from('profiles').select('voice_name, anonymous_default').eq('id', uid).maybeSingle();
    if (p != null && mounted) setState(() { _profileName = p['voice_name']; _isAnonymous = p['anonymous_default'] == true; });
  }

  Future<void> _initDraft() async {
    final draft = await EssayDraftService.loadDraft();
    if (draft != null && mounted) {
      _titleCtrl.text = draft['title'] ?? '';
      if (draft['content'] != null) {
        _quillController.document = quill.Document.fromJson(draft['content']);
      }
    }

    _draftService.startAutoSave(
      const Duration(seconds: 15),
      () => _titleCtrl.text,
      () => {'ops': _quillController.document.toDelta().toJson()},
    );

    // Listen to changes to show "Auto-saving..."
    _quillController.addListener(_onContentChanged);
    _titleCtrl.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_isAutoSaving) {
      setState(() {
        _isAutoSaving = true;
        _lastSaved = DateTime.now();
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isAutoSaving = false);
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final fixedPath = await ImageHelper.compressAndFixRotation(result.files.single.path!);
      setState(() {
        _coverImageFile = File(fixedPath);
        _coverImageUrl = null; // Will upload on publish
      });
    }
  }

  Future<String?> _uploadCoverImage() async {
    if (_coverImageFile == null) return null;
    final uid = supabase.auth.currentUser!.id;
    final fileName = 'essay_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$uid/$fileName';
    
    await supabase.storage.from('images').upload(path, _coverImageFile!);
    return supabase.storage.from('images').getPublicUrl(path);
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _publishing = true);
    try {
      // 1. Upload Cover Image if exists
      String? finalCoverUrl = _coverImageUrl;
      if (_coverImageFile != null) {
        finalCoverUrl = await _uploadCoverImage();
      }

      // 2. Extract plain text for reading time
      final plainText = _quillController.document.toPlainText();
      final readingTime = ReadingTimeCalculator.calculateReadingTimeMins(plainText);

      // 3. Save Essay via EssayService
      final essayId = await EssayService.saveEssay(
        title: _titleCtrl.text.trim(),
        coverImageUrl: finalCoverUrl,
        content: {'ops': _quillController.document.toDelta().toJson()},
        contentHtml: '', // TODO: quill to html if needed, or just rely on Delta JSON
        readingTimeMins: readingTime,
        topics: _topics,
        bgColorHex: _bgColorHex,
        musicUrl: _musicUrl,
        isPublished: true,
        isAnonymous: _isAnonymous,
      );

      _discarded = true;
      _draftService.stopAutoSave();
      await EssayDraftService.clearDraft();

      if (mounted) context.go('/publish-success/$essayId/essay');
    } catch (e) {
      debugPrint('Error publishing essay: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
        setState(() => _publishing = false);
      }
    }
  }

  void _confirmDiscard(BuildContext context) {
    if (_titleCtrl.text.trim().isEmpty && _quillController.document.isEmpty()) {
      _discarded = true;
      _draftService.stopAutoSave();
      EssayDraftService.clearDraft();
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
          TextButton(
            onPressed: () { 
              Navigator.pop(ctx); 
              _discarded = true; 
              _draftService.stopAutoSave();
              EssayDraftService.clearDraft();
          Future.delayed(const Duration(milliseconds: 100), () { 
            if (mounted && context.mounted) context.pop(); 
          }); 
            }, 
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _draftService.stopAutoSave();
    if (!_discarded && !_publishing) {
      EssayDraftService.saveDraft(_titleCtrl.text, {'ops': _quillController.document.toDelta().toJson()});
    }
    _quillController.dispose();
    _quillFocus.dispose();
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final dividerColor = Theme.of(context).dividerColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(children: [
          // ─── Header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
            child: Row(children: [
              GestureDetector(
                onTap: () => _confirmDiscard(context),
                child: Icon(LucideIcons.x, size: IjwiSizes.iconLg, color: onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_profileName ?? '', style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: onSurface)),
                    Row(
                      children: [
                        Icon(LucideIcons.cloud, size: 12, color: _isAutoSaving ? gold : hintColor),
                        const SizedBox(width: 4),
                        Text(
                          _isAutoSaving ? 'Saving...' : (_lastSaved != null ? 'Draft saved' : 'Draft'),
                          style: TextStyle(fontSize: 11, color: _isAutoSaving ? gold : hintColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _canPublish ? _publish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canPublish ? gold : (isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                  foregroundColor: _canPublish ? Colors.white : hintColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text(_publishing ? '...' : 'Publish', style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // ─── Toolbar ──────────────────────────────────────────
          quill.QuillSimpleToolbar(
            controller: _quillController,
            config: const quill.QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: false,
              showInlineCode: false,
              showCodeBlock: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showStrikeThrough: false,
              showIndent: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
            ),
          ),
          Divider(height: 1, color: dividerColor),

          // ─── Editor Body ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // Cover Image
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      width: double.infinity,
                      height: _coverImageFile != null || _coverImageUrl != null ? 200 : 100,
                      decoration: BoxDecoration(
                        color: isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dividerColor),
                        image: _coverImageFile != null 
                          ? DecorationImage(image: FileImage(_coverImageFile!), fit: BoxFit.cover)
                          : (_coverImageUrl != null ? DecorationImage(image: NetworkImage(_coverImageUrl!), fit: BoxFit.cover) : null),
                      ),
                      child: _coverImageFile == null && _coverImageUrl == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.image, color: hintColor, size: 28),
                                const SizedBox(height: 8),
                                Text('Add Cover Image', style: TextStyle(color: hintColor, fontWeight: FontWeight.w500)),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title Input
                  MentionOverlay(
                    key: _titleMentionKey,
                    controller: _titleCtrl,
                    layerLink: _titleLink,
                    child: CompositedTransformTarget(
                      link: _titleLink,
                      child: TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w800, color: onSurface),
                        decoration: InputDecoration(
                          hintText: 'Essay Title',
                          hintStyle: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w800, color: hintColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quill Editor
                  Container(
                    constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.5),
                    child: quill.QuillEditor.basic(
                      controller: _quillController,
                      focusNode: _quillFocus,
                      config: const quill.QuillEditorConfig(
                        placeholder: 'Write your essay here...',
                        padding: EdgeInsets.symmetric(vertical: 16),
                        scrollable: false,
                        expands: false,
                        autoFocus: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),

          // ─── Bottom ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface, border: Border(top: BorderSide(color: dividerColor))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Hashtag suggestions
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['testimony', 'worship', 'faith', 'prayer', 'healing', 'grace', 'hope'].map((tag) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        // insert tag at end of quill document
                        final len = _quillController.document.length;
                        _quillController.document.insert(len > 0 ? len - 1 : 0, ' #$tag ');
                        if (!_topics.contains(tag)) _topics.add(tag);
                      },
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
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _bgColorHex != null ? gold.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bgColorHex != null ? gold : hintColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.palette, size: 13, color: _bgColorHex != null ? gold : hintColor),
                      const SizedBox(width: 4),
                      Text('Color', style: TextStyle(fontSize: 11, color: _bgColorHex != null ? gold : hintColor, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickMusic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _musicUrl != null ? gold.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _musicUrl != null ? gold : hintColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.music, size: 13, color: _musicUrl != null ? gold : hintColor),
                      const SizedBox(width: 4),
                      Text('Music', style: TextStyle(fontSize: 11, color: _musicUrl != null ? gold : hintColor, fontWeight: FontWeight.w500)),
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

  void _pickMusic() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => const _MusicPickerSheet(),
    );
    if (result != null) {
      if (result == 'none') {
        setState(() => _musicUrl = null);
      } else {
        setState(() => _musicUrl = 'backgroundmusic/$result');
      }
    }
  }

  void _showColorPicker() {
    final colors = [
      {'name': 'Default', 'value': null},
      {'name': 'Crimson', 'value': '#DC143C'},
      {'name': 'Gold', 'value': '#FFD700'},
      {'name': 'Emerald', 'value': '#50C878'},
      {'name': 'Sapphire', 'value': '#0F52BA'},
      {'name': 'Amethyst', 'value': '#9966CC'},
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            children: colors.map((c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: c['value'] == null ? Colors.transparent : Color(int.parse((c['value'] as String).replaceFirst('#', '0xFF'))),
                child: c['value'] == null ? const Icon(LucideIcons.ban, size: 16) : null,
              ),
              title: Text(c['name'] as String),
              onTap: () {
                setState(() => _bgColorHex = c['value'] as String?);
                Navigator.pop(ctx);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _MusicPickerSheet extends StatefulWidget {
  const _MusicPickerSheet();
  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  final _player = AudioPlayer();
  String? _playingTrack;
  bool _isPlaying = false;

  final List<String> tracks = [
    'Amazing-Grace-2011(chosic.com).mp3',
    'Anonymous_Choir_-_Amicus_Meus(chosic.com).mp3',
    'Anonymous_Choir_-_Caligaverunt_Oculi_Mei(chosic.com).mp3',
    'Anonymous_Choir_-_Cantate_Domino(chosic.com).mp3',
    'Arcadia(chosic.com).mp3',
    'Camelot-Monastery-MP3(chosic.com).mp3',
    'Easter-chosic.com_.mp3',
    'Eternal-Hope(chosic.com).mp3',
    'Gregorian-Chant(chosic.com).mp3',
    'Market_Day(chosic.com).mp3',
    'Minstrel_Dance(chosic.com).mp3',
    'Solemn-Choral-Piece-No.-1(chosic.com).mp3',
    'sb_soulsearcher(chosic.com).mp3',
  ];

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay(String track) async {
    if (_playingTrack == track && _isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        final url = supabase.storage.from('public_assets').getPublicUrl('backgroundmusic/$track');
        await _player.play(UrlSource(url));
        setState(() {
          _playingTrack = track;
          _isPlaying = true;
        });
      } catch (e) {
        debugPrint('Error playing track: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Background Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          ),
          ListTile(
            title: const Text('None'),
            onTap: () => Navigator.pop(context, 'none'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (ctx, i) {
                final t = tracks[i];
                final name = t.replaceAll(RegExp(r'\(chosic\.com\)'), '').replaceAll('.mp3', '').replaceAll('_', ' ').replaceAll('-', ' ');
                final isCurrent = _playingTrack == t;
                return ListTile(
                  leading: IconButton(
                    icon: Icon(
                      isCurrent && _isPlaying ? LucideIcons.pause : LucideIcons.play,
                      color: isCurrent ? Theme.of(context).colorScheme.primary : Theme.of(context).hintColor,
                    ),
                    onPressed: () => _togglePlay(t),
                  ),
                  title: Text(name),
                  onTap: () => Navigator.pop(context, t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
