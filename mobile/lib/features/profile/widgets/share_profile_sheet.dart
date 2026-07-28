import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme.dart';
import 'profile_dm_sheet.dart';

const _kDeepLinkBase = 'https://ijwi.app/profile';

void showShareProfileSheet(
  BuildContext context, {
  required String userId,
  required String name,
  required String? avatarUrl,
  required String? bio,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => _ShareProfileSheet(userId: userId, name: name, avatarUrl: avatarUrl, bio: bio),
  );
}

class _ShareProfileSheet extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? bio;
  const _ShareProfileSheet({required this.userId, required this.name, required this.avatarUrl, required this.bio});
  @override
  State<_ShareProfileSheet> createState() => _ShareProfileSheetState();
}

class _ShareProfileSheetState extends State<_ShareProfileSheet> with TickerProviderStateMixin {
  late final TabController _tabs;
  int _activeTab = 0;
  String get _profileUrl => '$_kDeepLinkBase/${widget.userId}';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _activeTab = _tabs.index));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _profileUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Link copied!'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _shareToApps() async {
    final text = 'Find ${widget.name} on Ijwi\u2728\n'
        '${widget.bio != null && widget.bio!.isNotEmpty ? '"${widget.bio}"\n' : ''}'
        '\n$_profileUrl';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _shareAsDm() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => ProfileDmSheet(
        userId: widget.userId,
        gold: Theme.of(context).colorScheme.primary,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(99))),

          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              Text('Share profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Icon(LucideIcons.x, size: IjwiSizes.iconMd, color: text3)),
            ])),

          const SizedBox(height: 16),

          // Pill tabs
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border, width: 0.5)),
              child: Row(children: [
                _PillBtn(label: 'QR Code', icon: LucideIcons.qr_code, active: _activeTab == 0, gold: gold,
                  onTap: () { _tabs.animateTo(0); setState(() => _activeTab = 0); }),
                _PillBtn(label: 'Share', icon: LucideIcons.share_2, active: _activeTab == 1, gold: gold,
                  onTap: () { _tabs.animateTo(1); setState(() => _activeTab = 1); }),
              ]))),

          const SizedBox(height: 20),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _activeTab == 0
                ? _QrView(key: const ValueKey('qr'), name: widget.name, avatarUrl: widget.avatarUrl,
                    bio: widget.bio, profileUrl: _profileUrl, gold: gold, isDark: isDark,
                    text3: text3, border: border, onShare: _shareToApps, onCopy: _copyLink)
                : _ShareOptionsView(key: const ValueKey('sh'), name: widget.name, bio: widget.bio,
                    profileUrl: _profileUrl, gold: gold, isDark: isDark, text3: text3, border: border,
                    onShareApps: _shareToApps, onDm: _shareAsDm, onCopy: _copyLink)),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _QrView extends StatelessWidget {
  final String name; final String? avatarUrl; final String? bio; final String profileUrl;
  final Color gold; final bool isDark; final Color text3; final Color border;
  final VoidCallback onShare; final VoidCallback onCopy;
  const _QrView({super.key, required this.name, required this.avatarUrl, required this.bio,
    required this.profileUrl, required this.gold, required this.isDark, required this.text3,
    required this.border, required this.onShare, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // App badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99), border: Border.all(color: gold.withValues(alpha: 0.3))),
        child: Text('\u2726 IJWI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: gold, letterSpacing: 1.2))),
      const SizedBox(height: 20),
      // Avatar
      Container(width: 70, height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: 2.5), color: gold.withValues(alpha: 0.1)),
        child: ClipOval(child: avatarUrl != null && avatarUrl!.startsWith('http')
            ? Image.network(avatarUrl!, fit: BoxFit.cover)
            : Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: gold))))),
      const SizedBox(height: 10),
      Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1A1814))),
      if (bio != null && bio!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(bio!, style: TextStyle(fontSize: 12, color: text3, height: 1.4), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)],
      const SizedBox(height: 20),
      // QR code
      Container(
        padding: const EdgeInsets.all(14),
        child: QrImageView(
          data: profileUrl, version: QrVersions.auto, size: 220, backgroundColor: Colors.transparent,
          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: isDark ? gold : const Color(0xFF1A1814)),
          dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: isDark ? gold : const Color(0xFF1A1814)))),
      const SizedBox(height: 14),
      Text('Scan to find me on Ijwi', style: TextStyle(fontSize: 11, color: text3, letterSpacing: 0.3)),
      const SizedBox(height: 16),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(child: _ActionBtn(icon: LucideIcons.copy, label: 'Copy link', gold: gold, outlined: true, onTap: onCopy)),
          const SizedBox(width: 10),
          Expanded(child: _ActionBtn(icon: LucideIcons.share_2, label: 'Share', gold: gold, outlined: false, onTap: onShare)),
        ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ShareOptionsView extends StatelessWidget {
  final String name; final String? bio; final String profileUrl;
  final Color gold; final bool isDark; final Color text3; final Color border;
  final VoidCallback onShareApps; final VoidCallback onDm; final VoidCallback onCopy;
  const _ShareOptionsView({super.key, required this.name, required this.bio, required this.profileUrl,
    required this.gold, required this.isDark, required this.text3, required this.border,
    required this.onShareApps, required this.onDm, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final bg2 = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Preview card
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg2, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gold.withValues(alpha: 0.2), width: 0.8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('\u2726 $name on Ijwi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
              color: isDark ? Colors.white : Colors.black87)),
            if (bio != null && bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('"$bio"', style: TextStyle(fontSize: 12, color: text3, fontStyle: FontStyle.italic, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)],
            const SizedBox(height: 8),
            Text(profileUrl, style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ])),
        const SizedBox(height: 20),
        Text('SEND VIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: text3, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        _ShareTile(icon: LucideIcons.message_circle, label: 'Send as a DM', subtitle: 'Share directly inside Ijwi',
          gold: gold, isDark: isDark, border: border, onTap: onDm),
        const SizedBox(height: 10),
        _ShareTile(icon: LucideIcons.share_2, label: 'Share to other apps', subtitle: 'Instagram, WhatsApp, Twitter and more',
          gold: gold, isDark: isDark, border: border, onTap: onShareApps),
        const SizedBox(height: 10),
        _ShareTile(icon: LucideIcons.copy, label: 'Copy profile link', subtitle: profileUrl,
          gold: gold, isDark: isDark, border: border, onTap: onCopy),
      ]));
  }
}

// ─── Shared sub-widgets ──────────────────────────────────────────────────────
class _PillBtn extends StatelessWidget {
  final String label; final IconData icon; final bool active; final Color gold; final VoidCallback onTap;
  const _PillBtn({required this.label, required this.icon, required this.active, required this.gold, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    return Expanded(child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: active ? gold : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: active ? Colors.white : inactive),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : inactive)),
        ]))));
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color gold; final bool outlined; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.gold, required this.outlined, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(color: outlined ? Colors.transparent : gold,
        borderRadius: BorderRadius.circular(14), border: outlined ? Border.all(color: gold) : null),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: IjwiSizes.iconSm, color: outlined ? gold : Colors.white),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: outlined ? gold : Colors.white)),
      ])));
}

class _ShareTile extends StatelessWidget {
  final IconData icon; final String label; final String subtitle;
  final Color gold; final bool isDark; final Color border; final VoidCallback onTap;
  const _ShareTile({required this.icon, required this.label, required this.subtitle,
    required this.gold, required this.isDark, required this.border, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    return GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
          color: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.1)),
            child: Icon(icon, size: IjwiSizes.iconSm, color: gold)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: text3, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(LucideIcons.chevron_right, size: IjwiSizes.iconSm, color: text3),
        ])));
  }
}
