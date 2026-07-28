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
    final document = quill.Document.fromJson(widget.essay['content']['ops'] ?? widget.essay['content']);
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hintColor = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    final coverImageUrl = widget.essay['cover_image_url'] as String?;
    final title = widget.essay['title'] as String? ?? 'Untitled';
    final readingTime = widget.essay['reading_time_mins'] as int? ?? 1;
    final author = widget.essay['author'] as Map<String, dynamic>? ?? {};
    final authorName = author['voice_name'] as String? ?? 'Anonymous';
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
                    config: const quill.QuillEditorConfig(
                      autoFocus: false,
                      expands: false,
                      scrollable: false,
                      padding: EdgeInsets.zero,
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
