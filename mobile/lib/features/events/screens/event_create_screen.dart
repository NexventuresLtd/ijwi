import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import '../../../core/storage_helper.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:ijwi_mobile/core/image_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EventCreateScreen extends StatefulWidget {
  final String? type;
  final String? eventId;
  const EventCreateScreen({super.key, this.type, this.eventId});
  @override
  State<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends State<EventCreateScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _ticketPrice = TextEditingController();
  final _maxAttendees = TextEditingController();
  final _streamUrl = TextEditingController();

  final List<TicketTierInput> _tiers = [TicketTierInput()];
  final List<String> _deletedTierIds = [];
  final List<CollaboratorInput> _collaborators = [];

  bool _isFree = true;
  bool _isVirtual = false;
  bool _amplify = false;
  String _amplifyPlan = '3days';
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  bool _loading = false;
  String? _error;
  File? _coverImage;
  String? _existingCoverUrl;
  bool _uploadingCover = false;

  bool get _isLivePrayer => widget.type == 'live_prayer';

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null) {
      _title.text = 'Loading...';
      _loadEvent();
    } else if (_isLivePrayer) {
      _isVirtual = true;
      _isFree = true;
      _title.text = 'Live Prayer Room';
    }
  }

  Future<void> _loadEvent() async {
    setState(() => _loading = true);
    try {
      final e = await supabase.from('events').select('*').eq('id', widget.eventId!).single();
      _title.text = e['title'] ?? '';
      _description.text = e['description'] ?? '';
      _location.text = e['location'] ?? '';
      _ticketPrice.text = (e['ticket_price'] ?? '').toString();
      _maxAttendees.text = (e['max_attendees'] ?? '').toString();
      _streamUrl.text = e['stream_url'] ?? '';
      _isVirtual = e['is_virtual'] ?? false;
      _isFree = e['is_free'] ?? false;
      _amplify = e['is_amplified'] ?? false;
      if (e['event_date'] != null) {
        _eventDate = DateTime.parse(e['event_date']);
      }
      _existingCoverUrl = e['cover_image_url'];

      final collabs = await supabase.from('event_collaborators').select('role, profiles(voice_name)').eq('event_id', widget.eventId!);
      for (var c in collabs) {
        final profile = c['profiles'];
        if (profile != null) {
          final ci = CollaboratorInput();
          ci.usernameCtrl.text = profile['voice_name'] ?? '';
          ci.role = c['role'] ?? 'usher';
          _collaborators.add(ci);
        }
      }
      
      final tiersData = await supabase.from('ticket_tiers').select('*').eq('event_id', widget.eventId!);
      if (tiersData.isNotEmpty) {
        _tiers.clear();
        for (var t in tiersData) {
          final ti = TicketTierInput();
          ti.id = t['id'];
          ti.nameCtrl.text = t['name'] ?? '';
          ti.priceCtrl.text = t['price'].toString();
          ti.capacityCtrl.text = t['capacity'].toString();
          _tiers.add(ti);
        }
      }
    } catch (err) {
      _error = err.toString();
    }
    setState(() => _loading = false);
  }

  final _amplifyPlans = [
    {'key': '3days', 'label': '3 Days', 'price': '3,000 RWF', 'amount': 3000, 'desc': 'Shown on events page'},
    {'key': '7days', 'label': '7 Days', 'price': '7,000 RWF', 'amount': 7000, 'desc': 'Events page + home feed'},
    {'key': '14days', 'label': '14 Days', 'price': '14,000 RWF', 'amount': 14000, 'desc': 'Featured everywhere'},
  ];

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final fixedPath = await ImageHelper.compressAndFixRotation(result.files.single.path!);
      setState(() => _coverImage = File(fixedPath));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_eventDate));
      setState(() {
        _eventDate = DateTime(picked.year, picked.month, picked.day, time?.hour ?? 18, time?.minute ?? 0);
      });
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = 'Title and description are required.');
      return;
    }
    if (!_isFree) {
      for (var t in _tiers) {
        if (t.nameCtrl.text.trim().isEmpty || t.priceCtrl.text.trim().isEmpty) {
          setState(() => _error = 'All ticket tiers must have a name and price.');
          return;
        }
      }
    }
    if (_amplify) {
      _showAmplifyPaymentModal();
    } else {
      _finalizeEventCreation();
    }
  }

  Future<void> _showAmplifyPaymentModal() async {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final plan = _amplifyPlans.firstWhere((p) => p['key'] == _amplifyPlan);
    final amount = plan['amount'] as int;
    final priceLabel = plan['price'] as String;

    String phone = '';
    bool isPaying = false;
    String? payError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20, right: 20, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amplify Event Payment', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('You selected the ${plan['label']} plan for $priceLabel. Enter your Mobile Money number to pay.', 
                    style: TextStyle(fontSize: 13, color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3)),
                  const SizedBox(height: 20),
                  
                  TextField(
                    onChanged: (v) => phone = v,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (e.g. 078...)',
                      prefixIcon: const Icon(LucideIcons.phone, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  
                  if (payError != null) ...[
                    const SizedBox(height: 12),
                    Text(payError!, style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                  ],
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isPaying ? null : () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isPaying ? null : () async {
                            if (phone.trim().isEmpty) {
                              setModalState(() => payError = 'Phone number required');
                              return;
                            }
                            setModalState(() { isPaying = true; payError = null; });
                            try {
                              final res = await supabase.functions.invoke('opuspay-checkout', body: {
                                'phone': phone.trim(),
                                'amount': amount,
                                'merchant_reference': 'amplify_req_${DateTime.now().millisecondsSinceEpoch}',
                              });
                              
                              final paymentId = res.data['payment_id'];
                              final clientToken = res.data['client_token'];
                              if (paymentId == null || clientToken == null) {
                                throw Exception(res.data['error'] ?? 'Unknown error connecting to payment gateway');
                              }

                              bool isCompleted = false;
                              while (!isCompleted) {
                                if (!mounted) return;
                                await Future.delayed(const Duration(seconds: 3));
                                final statusRes = await supabase.functions.invoke('opuspay-status', body: {
                                  'payment_id': paymentId,
                                });
                                final status = statusRes.data['status'];
                                if (status == 'successful') {
                                  isCompleted = true;
                                } else if (status == 'failed') {
                                  throw Exception('Payment failed. Please try again.');
                                }
                              }
                              
                              // Payment success
                              if (mounted) Navigator.pop(ctx);
                              _finalizeEventCreation();

                            } catch (e) {
                              setModalState(() => payError = e.toString());
                            } finally {
                              setModalState(() => isPaying = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: isPaying
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text('Pay & Amplify', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finalizeEventCreation() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = supabase.auth.currentUser!.id;
      // Upload cover image if selected
      String? coverUrl;
      if (_coverImage != null) {
        final ext = _coverImage!.path.split('.').last;
        final path = '$uid/event_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final bytes = await _coverImage!.readAsBytes();
        coverUrl = await uploadToStorage(bucket: 'covers', path: path, bytes: bytes);
      } else {
        coverUrl = _existingCoverUrl;
      }
      final eventData = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'location': _isVirtual ? null : _location.text.trim(),
        'event_date': _eventDate.toIso8601String(),
        'is_free': _isFree,
        'ticket_price': _isFree ? null : double.tryParse(_ticketPrice.text),
        'max_attendees': _isFree ? (_maxAttendees.text.isNotEmpty ? int.tryParse(_maxAttendees.text) : null) : _tiers.fold<int>(0, (sum, t) => sum + (int.tryParse(t.capacityCtrl.text.trim()) ?? 100)),
        'is_virtual': _isVirtual,
        'stream_url': (_isVirtual && _streamUrl.text.trim().isNotEmpty) ? _streamUrl.text.trim() : null,
        'cover_image_url': coverUrl,
        'is_amplified': _amplify,
      };

      String eventId;
      if (widget.eventId != null) {
        await supabase.from('events').update(eventData).eq('id', widget.eventId!);
        eventId = widget.eventId!;
      } else {
        eventData['organizer_id'] = uid;
        eventData['ticket_currency'] = 'RWF';
        final insertedEvent = await supabase.from('events').insert(eventData).select('id').single();
        eventId = insertedEvent['id'];
      }

      if (!_isFree && _tiers.isNotEmpty) {
        final tiersData = _tiers.map((t) {
          final data = <String, dynamic>{
            'event_id': eventId,
            'name': t.nameCtrl.text.trim(),
            'price': double.tryParse(t.priceCtrl.text.trim()) ?? 0.0,
            'capacity': int.tryParse(t.capacityCtrl.text.trim()) ?? 100,
          };
          if (t.id != null) data['id'] = t.id;
          return data;
        }).toList();
        await supabase.from('ticket_tiers').upsert(tiersData);
      }
      if (_deletedTierIds.isNotEmpty) {
        await supabase.from('ticket_tiers').delete().inFilter('id', _deletedTierIds);
      }

      if (widget.eventId != null) {
        await supabase.from('event_collaborators').delete().eq('event_id', eventId);
      }
      if (_collaborators.isNotEmpty) {
        for (var c in _collaborators) {
          final username = c.usernameCtrl.text.trim();
          if (username.isNotEmpty) {
            final profile = await supabase.from('profiles').select('id').eq('voice_name', username).maybeSingle();
            if (profile != null) {
              await supabase.from('event_collaborators').insert({
                'event_id': eventId,
                'user_id': profile['id'],
                'role': c.role,
              });
            }
          }
        }
      }

      if (mounted) {
        if (widget.eventId != null) {
          context.pop(); // Go back to detail screen
        } else {
          context.push('/events/success');
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
    final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(LucideIcons.x, size: 22), onPressed: () => context.pop()),
        title: Text(widget.eventId != null ? 'Edit Event' : (_isLivePrayer ? 'Host Live Prayer' : 'Host an Event'), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cover Image
          _label('Event poster (optional)'),
          GestureDetector(
            onTap: _pickCover,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (_coverImage != null || _existingCoverUrl != null) ? gold : border, width: (_coverImage != null || _existingCoverUrl != null) ? 1.5 : 1, style: BorderStyle.solid),
                  color: (_coverImage != null || _existingCoverUrl != null) ? null : (isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _coverImage != null || _existingCoverUrl != null
                    ? Stack(children: [
                        Positioned.fill(child: _coverImage != null 
                            ? Image.file(_coverImage!, fit: BoxFit.cover) 
                            : CachedNetworkImage(imageUrl: _existingCoverUrl!, fit: BoxFit.cover)),
                        Positioned(top: 8, right: 8, child: GestureDetector(
                          onTap: () => setState(() { _coverImage = null; _existingCoverUrl = null; }),
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                            child: const Icon(LucideIcons.x, color: Colors.white, size: 14),
                          ),
                        )),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(LucideIcons.image, size: 36, color: gold.withValues(alpha: 0.6)),
                        const SizedBox(height: 10),
                        Text('Add event poster', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text3)),
                        const SizedBox(height: 4),
                        Text('4:5 ratio recommended', style: TextStyle(fontSize: 11, color: text3)),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 20),


          const SizedBox(height: 20),

          // Title
          _label('Event title *'),
          TextField(controller: _title, decoration: const InputDecoration(hintText: 'Worship Night at Kigali Arena')),
          const SizedBox(height: 16),

          // Description
          _label('Description *'),
          TextField(controller: _description, maxLines: 4, decoration: const InputDecoration(hintText: 'What to expect, who it\'s for...')),
          const SizedBox(height: 16),

          // Date
          _label('Date & time *'),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Row(children: [
                Icon(LucideIcons.calendar, size: 16, color: gold),
                const SizedBox(width: 10),
                Text('${_eventDate.day}/${_eventDate.month}/${_eventDate.year} at ${_eventDate.hour.toString().padLeft(2, '0')}:${_eventDate.minute.toString().padLeft(2, '0')}', style: GoogleFonts.poppins(fontSize: 14)),
                const Spacer(),
                Icon(LucideIcons.chevron_down, size: 16, color: text3),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Toggles
          if (!_isLivePrayer) ...[
            _toggle('Online / virtual event', _isVirtual, (v) => setState(() => _isVirtual = v), gold),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),

          if (_isVirtual) ...[
            _label('Stream URL (optional)'),
            TextField(controller: _streamUrl, decoration: const InputDecoration(hintText: 'Leave empty to use Ijwi Live')),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('No URL = in-app live chat room', style: TextStyle(fontSize: 12, color: text3))),
            const SizedBox(height: 16),
          ] else ...[
            _label('Location'),
            TextField(controller: _location, decoration: const InputDecoration(hintText: 'Kigali Arena, Kigali')),
            const SizedBox(height: 16),
          ],

          if (!_isLivePrayer) ...[
            _toggle('Free event', _isFree, (v) => setState(() => _isFree = v), gold),
            const SizedBox(height: 12),
          ],

          if (!_isFree) ...[
            _label('Ticket Tiers'),
            ..._tiers.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: TextField(controller: t.nameCtrl, decoration: const InputDecoration(hintText: 'Tier Name (e.g. VIP)'))),
                    if (_tiers.length > 1) ...[
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(LucideIcons.trash_2, color: Colors.redAccent, size: 18), onPressed: () => setState(() {
                        if (t.id != null) _deletedTierIds.add(t.id!);
                        _tiers.removeAt(i);
                      })),
                    ]
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: t.priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Price (RWF)', prefixText: 'RWF '))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: t.capacityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Capacity (opt)'))),
                  ]),
                ]),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _tiers.add(TicketTierInput())),
              icon: Icon(LucideIcons.plus, size: 16, color: gold),
              label: Text('Add another tier', style: TextStyle(color: gold)),
            ),
            const SizedBox(height: 16),
          ],

          if (_isFree) ...[
            _label('Max attendees (optional)'),
            TextField(controller: _maxAttendees, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '200')),
            const SizedBox(height: 20),
          ],

          // Collaborators
          _label('Collaborators (Admins / Ushers)'),
          ..._collaborators.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
              child: Row(children: [
                Expanded(
                  child: RawAutocomplete<Map<String, dynamic>>(
                    textEditingController: c.usernameCtrl,
                    focusNode: c.focusNode,
                    optionsBuilder: (textEditingValue) async {
                      if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                      try {
                        final res = await supabase
                            .from('profiles')
                            .select('id, voice_name, real_name, is_revealed, avatar_url')
                            .ilike('voice_name', '%${textEditingValue.text}%')
                            .limit(5);
                        return List<Map<String, dynamic>>.from(res);
                      } catch (_) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                    },
                    displayStringForOption: (opt) => opt['voice_name'] ?? '',
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search voice username...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final gold = Theme.of(context).colorScheme.primary;
                      final surface = isDark ? IjwiColors.darkSurface : IjwiColors.lightSurface;
                      final border = isDark ? IjwiColors.darkBorder : IjwiColors.lightBorder;

                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(14),
                          color: surface,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              shrinkWrap: true,
                              itemCount: options.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: border),
                              itemBuilder: (context, index) {
                                final opt = options.elementAt(index);
                                final avatar = opt['avatar_url'] as String?;
                                final voiceName = opt['voice_name'] as String? ?? '';
                                final realName = opt['real_name'] as String?;
                                final isRevealed = opt['is_revealed'] == true;

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                                    backgroundColor: gold.withValues(alpha: 0.15),
                                    child: avatar == null ? Icon(LucideIcons.user, size: 16, color: gold) : null,
                                  ),
                                  title: Text('@$voiceName', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: isRevealed && realName != null ? Text(realName, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)) : null,
                                  onTap: () {
                                    c.userId = opt['id'];
                                    onSelected(opt);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text('Usher', style: TextStyle(fontSize: 13, color: text3)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(LucideIcons.trash_2, color: Colors.redAccent, size: 18), onPressed: () => setState(() => _collaborators.removeAt(i))),
              ]),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _collaborators.add(CollaboratorInput())),
            icon: Icon(LucideIcons.plus, size: 16, color: gold),
            label: Text('Add collaborator', style: TextStyle(color: gold)),
          ),
          const SizedBox(height: 28),

          // Amplify section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _amplify ? gold : border, width: _amplify ? 1.5 : 0.5),
              color: _amplify ? gold.withValues(alpha: 0.05) : surface,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(LucideIcons.rocket, size: 20, color: gold),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Amplify your event', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Get more attendees with paid promotion', style: TextStyle(fontSize: 12, color: text3)),
                ])),
                Switch.adaptive(value: _amplify, onChanged: (v) => setState(() => _amplify = v), activeColor: gold),
              ]),
              if (_amplify) ...[
                const SizedBox(height: 16),
                ..._amplifyPlans.map((plan) {
                  final selected = _amplifyPlan == plan['key'];
                  return GestureDetector(
                    onTap: () => setState(() => _amplifyPlan = plan['key'] as String),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? gold : border, width: selected ? 1.5 : 0.5),
                        color: selected ? gold.withValues(alpha: 0.08) : Colors.transparent,
                      ),
                      child: Row(children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? gold : text3, width: 2)),
                          child: selected ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: gold))) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(plan['label'] as String, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(plan['desc'] as String, style: TextStyle(fontSize: 11, color: text3)),
                        ])),
                        Text(plan['price'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: gold)),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Text('Payment will be processed via MoMo after creating the event.', style: TextStyle(fontSize: 11, color: text3, fontStyle: FontStyle.italic)),
              ],
            ]),
          ),

          const SizedBox(height: 24),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
            ),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_loading ? (widget.eventId != null ? 'Saving...' : 'Creating...') : (widget.eventId != null ? 'Save changes' : (_amplify ? 'Create & Amplify \u2192' : 'Create event \u2192'))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).brightness == Brightness.dark ? IjwiColors.darkText2 : IjwiColors.lightText2)),
  );

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged, Color gold) {
    return Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 14))),
      Switch.adaptive(value: value, onChanged: onChanged, activeColor: gold),
    ]);
  }
}

class TicketTierInput {
  String? id;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController capacityCtrl = TextEditingController();
}

class CollaboratorInput {
  final TextEditingController usernameCtrl = TextEditingController();
  final FocusNode focusNode = FocusNode();
  String role = 'usher';
  String? userId;
}

