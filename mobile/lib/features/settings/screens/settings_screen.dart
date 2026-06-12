import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/theme_notifier.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _saving = false;
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final res = await supabase.from('profiles').select('*').eq('id', uid).single();
    final payments = await supabase.from('payments').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(10);
    if (mounted) setState(() {
      _profile = res;
      _payments = List<Map<String, dynamic>>.from(payments);
      _nameCtrl.text = res['voice_name'] ?? '';
      _bioCtrl.text = res['bio'] ?? '';
      _avatarUrl = res['avatar_url'];
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    await supabase.from('profiles').update({
      'voice_name': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
    }).eq('id', supabase.auth.currentUser!.id);
    setState(() => _saving = false);
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(LucideIcons.camera), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(LucideIcons.image), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 512);
    if (file == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final ext = file.name.split('.').last;
      final path = 'avatars/${uid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await file.readAsBytes();
      await supabase.storage.from('avatars').uploadBinary(path, bytes);
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('profiles').update({'avatar_url': url}).eq('id', uid);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (_) {}
    if (mounted) setState(() => _uploadingAvatar = false);
  }

  void _showPaymentHistory() {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: text3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              Icon(LucideIcons.receipt, size: 20, color: gold),
              const SizedBox(width: 10),
              Text('Payment History', style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500)),
            ]),
          ),
          Expanded(child: _payments.isEmpty
            ? Center(child: Text('No payments yet', style: TextStyle(color: text3)))
            : ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _payments.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: border),
                itemBuilder: (_, i) {
                  final p = _payments[i];
                  final amount = p['amount'] ?? 0;
                  final currency = p['currency'] ?? 'RWF';
                  final status = (p['status'] ?? 'pending').toString();
                  final phone = p['phone'] ?? '';
                  final date = DateTime.tryParse(p['created_at']?.toString() ?? '');
                  final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : '';
                  final statusColor = status == 'successful' ? Colors.green : status == 'failed' ? Colors.redAccent : Colors.orange;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor.withValues(alpha: 0.1)),
                        child: Icon(status == 'successful' ? LucideIcons.circle_check : status == 'failed' ? LucideIcons.circle_x : LucideIcons.clock, size: 16, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$amount $currency', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(phone, style: TextStyle(fontSize: 11, color: text3)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                        Text(dateStr, style: TextStyle(fontSize: 10, color: text3)),
                      ]),
                    ]),
                  );
                },
              ),
          ),
        ]),
      ),
    );
  }

  Widget _buildProSection(Color gold, bool isDark, Color surface, Color border, Color text3) {
    final isPro = _profile?['is_pro'] == true;
    final expiresAt = _profile?['pro_expires_at'] != null ? DateTime.tryParse(_profile!['pro_expires_at'].toString()) : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.12)),
            child: Icon(LucideIcons.crown, size: 20, color: gold),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ijwi Pro', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              isPro && !isExpired ? 'Active' : 'Inactive',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPro && !isExpired ? Colors.green : Colors.redAccent),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: gold.withValues(alpha: 0.3))),
            child: Text('2,000 RWF/mo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gold)),
          ),
        ]),
        if (isPro && !isExpired && expiresAt != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(LucideIcons.calendar, size: 14, color: gold),
              const SizedBox(width: 8),
              Text('Expires ${DateFormat('MMM d, yyyy').format(expiresAt)}', style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Text('Pro features:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text3, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _proFeature('Unlimited Sparks uploads'),
        _proFeature('Access Pro-only content'),
        _proFeature('Priority in Questions tab'),
        _proFeature('Pro badge on your profile'),
        if (!isPro || isExpired) ...[
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF1A1814), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            child: const Text('Subscribe via MoMo', style: TextStyle(fontWeight: FontWeight.w700)),
          )),
        ],
      ]),
    );
  }

  Widget _proFeature(String text) {
    final gold = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(LucideIcons.check, size: 14, color: gold),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12.5, color: Theme.of(context).textTheme.bodyMedium?.color)),
      ]),
    );
  }

  Widget _buildPaymentHistory(Color gold, bool isDark, Color surface, Color border, Color text3) {
    if (_payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
        child: Center(child: Column(children: [
          Icon(LucideIcons.receipt, size: 28, color: text3),
          const SizedBox(height: 8),
          Text('No payments yet', style: TextStyle(fontSize: 13, color: text3)),
        ])),
      );
    }

    return Container(
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
      child: Column(children: _payments.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final amount = p['amount'] ?? 0;
        final currency = p['currency'] ?? 'RWF';
        final status = (p['status'] ?? 'pending').toString();
        final phone = p['phone'] ?? '';
        final date = DateTime.tryParse(p['created_at']?.toString() ?? '');
        final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : '';
        final statusColor = status == 'successful' ? Colors.green : status == 'failed' ? Colors.redAccent : Colors.orange;

        return Column(children: [
          if (i > 0) Divider(height: 1, color: border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor.withValues(alpha: 0.1)),
                child: Icon(
                  status == 'successful' ? LucideIcons.circle_check : status == 'failed' ? LucideIcons.circle_x : LucideIcons.clock,
                  size: 16, color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$amount $currency', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(phone, style: TextStyle(fontSize: 11, color: text3)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(status[0].toUpperCase() + status.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                Text(dateStr, style: TextStyle(fontSize: 10, color: text3)),
              ]),
            ]),
          ),
        ]);
      }).toList()),
    );
  }

  void _changeEmail(BuildContext context) {
    final ctrl = TextEditingController(text: supabase.auth.currentUser?.email ?? '');
    final gold = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
            Text('Change Email', style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(controller: ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'New email address')),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                final email = ctrl.text.trim();
                if (email.isEmpty) return;
                try {
                  await supabase.auth.updateUser(UserAttributes(email: email));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {}
              },
              child: const Text('Update Email'),
            )),
            const SizedBox(height: 8),
            Text('A confirmation link will be sent to your new email', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ]),
        )),
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Theme.of(context).hintColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(99))),
            Text('Change Password', style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(fontSize: 12, color: Colors.redAccent))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                if (newCtrl.text.length < 6) { setSheetState(() => error = 'Password must be at least 6 characters'); return; }
                if (newCtrl.text != confirmCtrl.text) { setSheetState(() => error = 'Passwords do not match'); return; }
                try {
                  await supabase.auth.updateUser(UserAttributes(password: newCtrl.text));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) { setSheetState(() => error = 'Failed to update password'); }
              },
              child: const Text('Update Password'),
            )),
          ]),
        )),
      )),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) context.go('/auth/login');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This action is permanent. All your data will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Settings', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), children: [
        // Edit Profile section
        _SectionTitle('Profile'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
          child: Column(children: [
            // Avatar
            Center(child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gold.withValues(alpha: 0.12), border: Border.all(color: gold, width: 2)),
                  child: ClipOval(
                    child: _uploadingAvatar
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : _avatarUrl != null && _avatarUrl!.startsWith('http')
                            ? CachedNetworkImage(imageUrl: _avatarUrl!, width: 72, height: 72, fit: BoxFit.cover)
                            : Center(child: Text((_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : '?').toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: gold))),
                  ),
                ),
                Positioned(bottom: 0, right: 0, child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: gold, border: Border.all(color: surface, width: 2)),
                  child: const Icon(LucideIcons.camera, size: 12, color: Colors.white),
                )),
              ]),
            )),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Voice name')),
            const SizedBox(height: 12),
            TextField(controller: _bioCtrl, maxLines: 3, maxLength: 150, decoration: const InputDecoration(labelText: 'Bio', hintText: 'Share about your faith journey...', counterText: '')),
            Align(alignment: Alignment.centerRight, child: Text('${_bioCtrl.text.length}/150', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor))),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: Text(_saving ? 'Saving...' : 'Save changes'),
            )),
          ]),
        ),

        const SizedBox(height: 24),

        // Ijwi Pro
        _SectionTitle('Ijwi Pro'),
        _buildProSection(gold, isDark, surface, border, text3),

        const SizedBox(height: 24),

        // Payment History
        _SectionTitle('Payment History'),
        _buildPaymentHistory(gold, isDark, surface, border, text3),

        const SizedBox(height: 24),

        // Appearance
        _SectionTitle('Appearance'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
          child: Row(children: [
            Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 20, color: gold),
            const SizedBox(width: 14),
            Expanded(child: Text('Dark mode', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500))),
            Switch.adaptive(value: themeNotifier.isDark, onChanged: (_) => themeNotifier.toggle(), activeColor: gold),
          ]),
        ),

        const SizedBox(height: 24),

        // Account
        _SectionTitle('Account'),
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
          child: Column(children: [
            _SettingsItem(icon: LucideIcons.mail, label: 'Email', subtitle: supabase.auth.currentUser?.email ?? '', onTap: () => _changeEmail(context)),
            Divider(height: 1, color: border),
            _SettingsItem(icon: LucideIcons.lock, label: 'Change password', onTap: () => _changePassword(context)),
            Divider(height: 1, color: border),
            _SettingsItem(icon: LucideIcons.bell, label: 'Push notifications', onTap: () => context.push('/notification-prefs')),
            Divider(height: 1, color: border),
            _SettingsItem(icon: LucideIcons.shield, label: 'Privacy', subtitle: 'Anonymous posting, visibility', onTap: () => context.push('/privacy')),
            Divider(height: 1, color: border),
            _SettingsItem(icon: LucideIcons.receipt, label: 'Payment history', subtitle: '${_payments.length} transactions', onTap: _showPaymentHistory),
          ]),
        ),

        const SizedBox(height: 24),

        // Danger zone
        _SectionTitle(''),
        Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
          child: Column(children: [
            _SettingsItem(icon: LucideIcons.log_out, label: 'Sign out', color: Colors.redAccent, onTap: _signOut),
            Divider(height: 1, color: border),
            _SettingsItem(icon: LucideIcons.trash_2, label: 'Delete account', color: Colors.redAccent, onTap: _deleteAccount),
          ]),
        ),

        const SizedBox(height: 40),
        Center(child: Text('Ijwi v1.0.0', style: TextStyle(fontSize: 12, color: text3))),
        const SizedBox(height: 60),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Theme.of(context).hintColor)),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  const _SettingsItem({required this.icon, required this.label, this.subtitle, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: c)),
            if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          ])),
          Icon(LucideIcons.chevron_right, size: 16, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }
}
