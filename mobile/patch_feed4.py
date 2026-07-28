import re

with open('/Users/davidniyonshutii/Documents/Nexventures/ijwi/mobile/lib/features/feed/screens/feed_screen.dart', 'r') as f:
    content = f.read()

# Replace _PostCard
idx1 = content.find("class _PostCard extends StatelessWidget {")
idx2 = content.find("class _ReactionBtn extends StatelessWidget {")
if idx1 != -1 and idx2 != -1:
    content = content[:idx1] + """class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final Future<void> Function(String postId, String type) onReact;
  final Future<void> Function(String postId) onSave;
  final Future<void> Function(String postId) onRepost;
  final bool isLiked;
  final bool isSaved;
  final bool isReposted;
  const _PostCard({required this.post, required this.onReact, required this.onSave, required this.onRepost, required this.isLiked, required this.isSaved, required this.isReposted});

  @override
  Widget build(BuildContext context) {
    final author = post['author'] as Map<String, dynamic>?;
    final name = (author?['is_revealed'] == true && author?['real_name'] != null)
        ? author!['real_name']
        : (author?['voice_name'] ?? 'Anonymous');
    final avatarUrl = author?['avatar_url'] as String?;
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final contentType = (post['content_type'] ?? 'story').toString().replaceAll('_', ' ');

    final bool hasVideo = post['video_url'] != null && (post['video_url'] as String).isNotEmpty;
    final bool hasImage = post['cover_image_url'] != null;
    final bool hasMedia = hasImage || hasVideo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (post['content_type'] == 'short' || post['video_url'] != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SparksViewerScreen(initialIndex: 0, preloadedSparks: [post]),
            fullscreenDialog: true,
          ));
        } else {
          context.push('/post/${post['id']}');
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (author?['id'] != null) context.push('/profile/${author!['id']}');
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: gold.withValues(alpha: 0.1),
                            border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: ClipOval(
                            child: avatarUrl != null && avatarUrl.startsWith('http')
                                ? Image.network(avatarUrl, width: 38, height: 38, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      name.toString()[0].toUpperCase(),
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: gold),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (author?['id'] != null) context.push('/profile/${author!['id']}');
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(timeago.format(DateTime.parse(post['created_at'])), style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: gold.withValues(alpha: 0.2), width: 0.5),
                        ),
                        child: Text(contentType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gold, letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                  if (!hasVideo && post['title'] != null) ...[
                    const SizedBox(height: 12),
                    Text(post['title'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, height: 1.45), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (!hasVideo && post['body'] != null) ...[
                    const SizedBox(height: 10),
                    MentionText(post['body'], style: GoogleFonts.montserrat(fontSize: 13.5, height: 1.6), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  if (hasMedia) const SizedBox(height: 12),
                ],
              ),
            ),
            
            // MIDDLE BODY (Media)
            if (hasMedia)
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasImage && !hasVideo)
                        SizedBox(
                          height: 250,
                          child: CachedNetworkImage(
                            imageUrl: post['cover_image_url'],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: isDark ? IjwiColors.darkBg3 : IjwiColors.lightBg3),
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      if (hasVideo)
                        SizedBox(
                          height: 250,
                          child: _VideoPreview(url: post['video_url']),
                        ),
                    ],
                  ),
                  if (hasVideo && (post['title'] != null || post['body'] != null))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (post['title'] != null)
                                Text(
                                  post['title'],
                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (post['body'] != null) ...[
                                if (post['title'] != null) const SizedBox(height: 4),
                                Text(
                                  post['body'],
                                  style: GoogleFonts.montserrat(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.9)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text("Read more", style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            // BOTTOM ACTIONS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _ReactionBtn(
                    icon: LucideIcons.heart,
                    label: 'Like',
                    count: (post['reaction_healed'] ?? 0) + (post['reaction_amen'] ?? 0),
                    active: isLiked,
                    onTap: () => onReact(post['id'], 'healed'),
                  ),
                  _ReactionBtn(
                    icon: LucideIcons.repeat_2,
                    label: 'Repost',
                    count: 0,
                    active: isReposted,
                    onTap: () => onRepost(post['id']),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => onSave(post['id']),
                    child: Icon(
                      isSaved ? LucideIcons.bookmark_check : LucideIcons.bookmark,
                      size: 18,
                      color: isSaved ? gold : (isDark ? Colors.white54 : Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ActionBtn(icon: LucideIcons.message_circle, label: '${post['comment_count'] ?? 0}'),
                  const SizedBox(width: 4),
                  _ActionBtn(icon: LucideIcons.share, label: 'Echo', onTap: () => showEchoSheet(context, post)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

""" + content[idx2:]

with open('/Users/davidniyonshutii/Documents/Nexventures/ijwi/mobile/lib/features/feed/screens/feed_screen.dart', 'w') as f:
    f.write(content)
