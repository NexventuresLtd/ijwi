import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../core/theme.dart';

class EssayReaderScreen extends StatefulWidget {
  final Map<String, dynamic> essay;

  const EssayReaderScreen({super.key, required this.essay});

  @override
  State<EssayReaderScreen> createState() => _EssayReaderScreenState();
}

class _EssayReaderScreenState extends State<EssayReaderScreen> {
  late final quill.QuillController _quillController;

  @override
  void initState() {
    super.initState();
    final contentRaw = widget.essay['content'];
    dynamic contentData;
    if (contentRaw != null) {
      contentData = contentRaw['ops'] ?? contentRaw;
    } else {
      contentData = [
        {'insert': widget.essay['body']?.toString() ?? 'No content available.\n'},
        {'insert': '\n'}
      ];
    }
    final document = quill.Document.fromJson(contentData);
    _quillController = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true, // Render as read-only
    );
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverColorHex = widget.essay['cover_color'] as String?;
    final hasCoverColor = coverColorHex != null && coverColorHex.isNotEmpty;
    
    Color scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    if (hasCoverColor) {
      scaffoldBg = Color(int.parse(coverColorHex.replaceFirst('#', '0xFF')));
    }
    
    final isBgDark = scaffoldBg.computeLuminance() < 0.5;
    
    final onSurface = hasCoverColor 
        ? (isBgDark ? Colors.white : Colors.black87)
        : Theme.of(context).colorScheme.onSurface;
        
    final hintColor = hasCoverColor
        ? (isBgDark ? Colors.white70 : Colors.black54)
        : (isDark ? IjwiColors.darkText3 : IjwiColors.lightText3);

    final coverImageUrl = widget.essay['cover_image_url'] as String?;
    final title = widget.essay['title'] as String? ?? 'Untitled';
    final readingTime = widget.essay['reading_time_mins'] as int? ?? 1;
    final author = widget.essay['author'] as Map<String, dynamic>? ?? {};
    final isAnonymous = widget.essay['is_anonymous'] == true;
    final authorName = isAnonymous ? 'Anonymous' : (author['voice_name'] as String? ?? 'Anonymous');
    final topics = (widget.essay['topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: coverImageUrl != null ? 300.0 : kToolbarHeight,
            pinned: true,
            backgroundColor: scaffoldBg,
            leading: IconButton(
              icon: Icon(LucideIcons.arrow_left, color: onSurface),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: coverImageUrl != null
                  ? Image.network(coverImageUrl, fit: BoxFit.cover)
                  : const SizedBox(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata Row
                  Row(
                    children: [
                      Icon(LucideIcons.user, size: 14, color: hintColor),
                      const SizedBox(width: 4),
                      Text(authorName, style: TextStyle(color: hintColor, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Icon(LucideIcons.clock, size: 14, color: hintColor),
                      const SizedBox(width: 4),
                      Text('$readingTime min read', style: TextStyle(color: hintColor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Topics
                  if (topics.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: topics
                          .map((t) => Chip(
                                label: Text(t, style: const TextStyle(fontSize: 12)),
                                backgroundColor: gold.withValues(alpha: 0.1),
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
                  if (topics.isNotEmpty) const SizedBox(height: 24),

                  // Content
                  quill.QuillEditor.basic(
                    controller: _quillController,
                    config: quill.QuillEditorConfig(
                      autoFocus: false,
                      expands: false,
                      scrollable: false,
                      padding: EdgeInsets.zero,
                      customStyles: quill.DefaultStyles(
                        paragraph: quill.DefaultTextBlockStyle(
                          TextStyle(color: onSurface, fontSize: 16, height: 1.5),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                        h1: quill.DefaultTextBlockStyle(
                          TextStyle(color: onSurface, fontSize: 32, fontWeight: FontWeight.bold),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(16, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                        h2: quill.DefaultTextBlockStyle(
                          TextStyle(color: onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(8, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                        h3: quill.DefaultTextBlockStyle(
                          TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.bold),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(8, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                        ),
                        lists: quill.DefaultListBlockStyle(
                          TextStyle(color: onSurface, fontSize: 16),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          const quill.VerticalSpacing(0, 0),
                          null,
                          null,
                        ),
                        quote: quill.DefaultTextBlockStyle(
                          TextStyle(color: onSurface.withValues(alpha: 0.8), fontSize: 16, fontStyle: FontStyle.italic),
                          const quill.HorizontalSpacing(0, 0),
                          const quill.VerticalSpacing(8, 8),
                          const quill.VerticalSpacing(0, 0),
                          BoxDecoration(border: Border(left: BorderSide(width: 4, color: hintColor.withValues(alpha: 0.3)))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
