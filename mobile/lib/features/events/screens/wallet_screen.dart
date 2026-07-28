import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/supabase.dart';
import '../../../core/theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late AnimationController _refreshController;
  bool _loading = true;
  double _availableBalance = 0;
  List<Map<String, dynamic>> _payouts = [];
  List<Map<String, dynamic>> _ticketSales = [];

  @override
  void initState() { 
    super.initState(); 
    _refreshController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _loadData(); 
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _refreshController.repeat();
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _refreshController.stop();
        return;
      }

      // Fetch user's events
      final eventsRes = await supabase.from('events').select('id, title').not('tags', 'cs', ['quick_live']).eq('organizer_id', userId);
      final eventIds = (eventsRes as List).map((e) => e['id']).toList();

      double grossSales = 0;
      List<Map<String, dynamic>> sales = [];

      if (eventIds.isNotEmpty) {
        // Fetch ticket sales
        final bookingsRes = await supabase
            .from('event_bookings')
            .select('id, created_at, payment_status, amount, events(title, ticket_price), ticket_tiers(name, price)')
            .inFilter('event_id', eventIds)
            .eq('payment_status', 'completed')
            .order('created_at', ascending: false);

        sales = List<Map<String, dynamic>>.from(bookingsRes);
        for (final b in sales) {
          final price = b['amount'] ?? b['ticket_tiers']?['price'] ?? b['events']?['ticket_price'] ?? 0;
          grossSales += price;
        }
      }

      // Opus takes 2%, Ijwi Platform takes 2% (4% total fees)
      const double opusRate = 0.02;
      const double ijwiRate = 0.02;
      final double totalFees = opusRate + ijwiRate;
      
      final netEarnings = (grossSales * (1 - totalFees)).floorToDouble();

      // Fetch payouts
      final payoutsRes = await supabase
          .from('organizer_payouts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
          
      final payoutsList = List<Map<String, dynamic>>.from(payoutsRes);
      
      double cashedOut = 0;
      for (final p in payoutsList) {
        if (p['status'] == 'pending' || p['status'] == 'completed') {
          cashedOut += (p['amount'] as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _ticketSales = sales;
          _payouts = payoutsList;
          _availableBalance = netEarnings - cashedOut - 300; // Deduct Opus 300 RWF fee
          if (_availableBalance < 0) _availableBalance = 0;
          _loading = false;
        });
        _refreshController.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _refreshController.stop();
      }
      debugPrint("Wallet load error: $e");
    }
  }

  void _showCashoutSheet() async {
    if (_availableBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum 300 RWF required for cashout.')));
      return;
    }
    final result = await context.push<bool>('/wallet/cashout', extra: _availableBalance);
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = Theme.of(context).colorScheme.primary;
    final text3 = isDark ? IjwiColors.darkText3 : IjwiColors.lightText3;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Wallet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: RotationTransition(
                turns: _refreshController,
                child: const Icon(LucideIcons.refresh_cw),
              ),
              onPressed: _loading ? null : _loadData,
            ),
            IconButton(
              icon: const Icon(LucideIcons.settings),
              onPressed: () => context.push('/wallet/settings'),
            ),
          ],
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _loading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Floating Card (Fixed)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [gold, gold.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: gold.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text(
                          '${_availableBalance.toInt()} RWF',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('Includes 300 RWF Opus withdrawal fee', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _showCashoutSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: gold,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text('Cashout Funds', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: text3,
                      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: gold,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Ticket Sales'),
                        Tab(text: 'Cashout History'),
                      ],
                    ),
                  ),
                ),
                
                // Tab Views (Scrollable)
                Expanded(
                  child: TabBarView(
                    children: [
                      // Ticket Sales Tab
                      _ticketSales.isEmpty
                          ? Center(child: Text('No ticket sales yet.', style: TextStyle(color: text3)))
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: gold,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: _ticketSales.length,
                                itemBuilder: (context, index) {
                                  final b = _ticketSales[index];
                                  final price = b['amount'] ?? b['ticket_tiers']?['price'] ?? b['events']?['ticket_price'] ?? 0;
                                  final tierName = b['ticket_tiers']?['name'] != null ? ' (${b['ticket_tiers']['name']})' : '';
                                  return _buildTransactionTile(
                                    icon: LucideIcons.ticket,
                                    title: 'Ticket: ${b['events']?['title'] ?? 'Event'}$tierName',
                                    subtitle: _formatDate(b['created_at']),
                                    amount: '+${price.toInt()} RWF',
                                    amountColor: Colors.green,
                                    status: null,
                                  );
                                },
                              ),
                            ),
                            
                      // Cashout Tab
                      _payouts.isEmpty
                          ? Center(child: Text('No cashout history yet.', style: TextStyle(color: text3)))
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: gold,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: _payouts.length,
                                itemBuilder: (context, index) {
                                  final p = _payouts[index];
                                  return _buildTransactionTile(
                                    icon: LucideIcons.arrow_up_right,
                                    title: 'Cashout to ${p['recipient_number']}',
                                    subtitle: _formatDate(p['created_at']),
                                    amount: '-${(p['amount'] as num).toInt()} RWF',
                                    amountColor: isDark ? Colors.white : Colors.black,
                                    status: p['status'],
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildTransactionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
    String? status,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = Theme.of(context).colorScheme.primary;
    final bg = isDark ? IjwiColors.darkBg2 : IjwiColors.lightBg2;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: gold.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: gold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(subtitle, style: TextStyle(color: isDark ? IjwiColors.darkText3 : IjwiColors.lightText3, fontSize: 12)),
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'completed' ? Colors.green.withValues(alpha: 0.2) : (status == 'failed' ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: status == 'completed' ? Colors.green : (status == 'failed' ? Colors.red : Colors.orange),
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: amountColor)),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final d = DateTime.parse(isoString);
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
