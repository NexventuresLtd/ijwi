import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await supabase
          .from('user_blocks')
          .select('blocked_id, profiles!user_blocks_blocked_id_fkey(name, avatar_url)')
          .eq('blocker_id', uid);
      if (mounted) {
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblockUser(String blockedId) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', blockedId);
      setState(() {
        _blockedUsers.removeWhere((u) => u['blocked_id'] == blockedId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Blocked users', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.shield_check, size: 64, color: text3),
                      const SizedBox(height: 16),
                      Text('No blocked users', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('When you block someone, they will appear here.', style: TextStyle(color: text3)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: border),
                  itemBuilder: (context, i) {
                    final block = _blockedUsers[i];
                    final profile = block['profiles'] as Map<String, dynamic>?;
                    final name = profile?['name'] ?? 'Unknown User';
                    final avatarUrl = profile?['avatar_url'];

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: surface,
                            backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null || !avatarUrl.startsWith('http')
                                ? Text(name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)),
                          ),
                          TextButton(
                            onPressed: () => _unblockUser(block['blocked_id']),
                            child: const Text('Unblock', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
