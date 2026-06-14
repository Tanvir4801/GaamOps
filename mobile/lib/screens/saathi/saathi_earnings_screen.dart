import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/ride_service.dart';

// ─── Badge definitions ──────────────────────────────────────────────────────

class _Badge {
  final String title;
  final String titleGu;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredRides;
  const _Badge({
    required this.title, required this.titleGu, required this.description,
    required this.icon, required this.color, required this.requiredRides,
  });
}

const _badges = [
  _Badge(title: 'Bronze Saathi', titleGu: 'કાંસ્ય સાથી',
      description: '10+ rides', icon: Icons.emoji_events_outlined,
      color: Color(0xFFCD7F32), requiredRides: 10),
  _Badge(title: 'Silver Saathi', titleGu: 'ચાંદી સાથી',
      description: '50+ rides', icon: Icons.emoji_events,
      color: Color(0xFF9E9E9E), requiredRides: 50),
  _Badge(title: 'Gold Saathi', titleGu: 'સોના સાથી',
      description: '100+ rides', icon: Icons.emoji_events,
      color: Color(0xFFFFC107), requiredRides: 100),
  _Badge(title: 'Diamond Saathi', titleGu: 'હીરા સાથી',
      description: '500+ rides', icon: Icons.diamond,
      color: Color(0xFF29B6F6), requiredRides: 500),
];

// ─── Screen ─────────────────────────────────────────────────────────────────

class SaathiEarningsScreen extends StatefulWidget {
  const SaathiEarningsScreen({super.key});

  @override
  State<SaathiEarningsScreen> createState() => _SaathiEarningsScreenState();
}

class _SaathiEarningsScreenState extends State<SaathiEarningsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _earnings = {};
  double _rating = 5.0;
  int _totalRides = 0;
  bool _loading = true;
  String? _error;
  int? _selectedBarIndex;             // tapped bar in the chart

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final results = await Future.wait([
        RideService.getSaathiEarnings(uid),
        FirebaseFirestore.instance.collection('saathis').doc(uid).get(),
      ]);

      final earnings = results[0] as Map<String, dynamic>;
      final saathiSnap = results[1] as DocumentSnapshot;
      final sd = saathiSnap.exists
          ? saathiSnap.data() as Map<String, dynamic> : <String, dynamic>{};

      if (mounted) {
        setState(() {
          _earnings = earnings;
          _totalRides = (sd['totalRides'] ?? earnings['totalRides'] ?? 0).toInt();
          _rating = (sd['rating'] ?? 5.0).toDouble();
          _loading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ─── Badge helpers ───

  _Badge? get _currentBadge {
    _Badge? best;
    for (final b in _badges) { if (_totalRides >= b.requiredRides) best = b; }
    return best;
  }

  _Badge? get _nextBadge {
    for (final b in _badges) { if (_totalRides < b.requiredRides) return b; }
    return null;
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final todayEarnings  = (_earnings['today']  ?? 0.0).toDouble();
    final weekEarnings   = (_earnings['week']   ?? 0.0).toDouble();
    final monthEarnings  = (_earnings['month']  ?? 0.0).toDouble();
    final todayRides     = (_earnings['todayRides'] ?? 0).toInt();
    final dailyEarnings  = (_earnings['dailyEarnings'] as List<double>?) ?? List.filled(7, 0.0);
    final dailyRides     = (_earnings['dailyRides']    as List<int>?)    ?? List.filled(7, 0);
    final recentRides    = (_earnings['recentRides']   as List<Map<String, dynamic>>?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: CustomScrollView(slivers: [
                    // ── Gradient header ──
                    _Header(
                      monthEarnings: monthEarnings,
                      totalRides: _totalRides,
                      rating: _rating,
                      onRefresh: _load,
                    ),

                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(children: [
                        // ── Today / Week / Month stats ──
                        _StatsRow(
                          todayEarnings: todayEarnings,
                          todayRides: todayRides,
                          weekEarnings: weekEarnings,
                          monthEarnings: monthEarnings,
                        ),

                        const SizedBox(height: 16),

                        // ── 7-day bar chart ──
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.bgGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.bar_chart,
                                      color: AppColors.primaryGreen, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('છેલ્લા 7 દિવસ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    Text('Last 7 days earnings',
                                        style: TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 11)),
                                  ],
                                )),
                                // Selected bar detail
                                if (_selectedBarIndex != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgGreen,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '₹${dailyEarnings[_selectedBarIndex!].toStringAsFixed(0)}'
                                      ' · ${dailyRides[_selectedBarIndex!]} rides',
                                      style: const TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ]),
                              const SizedBox(height: 20),
                              _WeeklyBarChart(
                                dailyEarnings: dailyEarnings,
                                dailyRides: dailyRides,
                                selectedIndex: _selectedBarIndex,
                                onBarTap: (i) => setState(() =>
                                    _selectedBarIndex =
                                        _selectedBarIndex == i ? null : i),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Recent trips ──
                        if (recentRides.isNotEmpty) ...[
                          _RecentTripsCard(rides: recentRides),
                          const SizedBox(height: 16),
                        ],

                        // ── Badge / level ──
                        _BadgeCard(
                          totalRides: _totalRides,
                          rating: _rating,
                          currentBadge: _currentBadge,
                          nextBadge: _nextBadge,
                        ),

                        const SizedBox(height: 16),

                        // ── Payment info ──
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(children: [
                                Icon(Icons.payments_outlined,
                                    color: AppColors.primaryGreen, size: 20),
                                SizedBox(width: 8),
                                Text('Payment Info',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ]),
                              const SizedBox(height: 14),
                              _PayRow('App Commission', '0% (no cut for now)'),
                              _PayRow('You Keep', '100% of fare'),
                              _PayRow('Payment Mode', 'Cash from customer'),
                              _PayRow('Your Rating',
                                  '${_rating.toStringAsFixed(1)} ★  ($_totalRides rides)'),
                            ],
                          ),
                        ),
                      ]),
                    )),
                  ]),
                ),
    );
  }
}

// ─────────────────────────────────────────
// Header (SliverAppBar)
// ─────────────────────────────────────────

class _Header extends StatelessWidget {
  final double monthEarnings;
  final int totalRides;
  final double rating;
  final VoidCallback onRefresh;

  const _Header({
    required this.monthEarnings,
    required this.totalRides,
    required this.rating,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(0xFFE65100),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: onRefresh,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBF360C), Color(0xFFE65100), Color(0xFFFF8F00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Earnings · કમાણી',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${monthEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1),
                  ),
                  const Text('this month',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _HeaderChip(
                        icon: Icons.electric_rickshaw,
                        label: '$totalRides total rides'),
                    const SizedBox(width: 8),
                    _HeaderChip(
                        icon: Icons.star_rounded,
                        label: '${rating.toStringAsFixed(1)} rating'),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// Stats row — Today / Week / Month
// ─────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double todayEarnings;
  final int todayRides;
  final double weekEarnings;
  final double monthEarnings;

  const _StatsRow({
    required this.todayEarnings,
    required this.todayRides,
    required this.weekEarnings,
    required this.monthEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(
        label: 'આજ / Today',
        amount: todayEarnings,
        sub: '$todayRides rides',
        color: AppColors.primaryGreen,
        icon: Icons.today,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        label: 'આ અઠવાડિયું',
        amount: weekEarnings,
        sub: 'This week',
        color: const Color(0xFF00897B),
        icon: Icons.date_range,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        label: 'આ મહિનો',
        amount: monthEarnings,
        sub: 'This month',
        color: AppColors.primaryOrange,
        icon: Icons.calendar_month,
      )),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final String sub;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label, required this.amount, required this.sub,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text('₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(sub,
            style: const TextStyle(fontSize: 9, color: AppColors.textGrey)),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// 7-day bar chart (pure Flutter, no package)
// ─────────────────────────────────────────

class _WeeklyBarChart extends StatefulWidget {
  final List<double> dailyEarnings;
  final List<int> dailyRides;
  final int? selectedIndex;
  final ValueChanged<int> onBarTap;

  const _WeeklyBarChart({
    required this.dailyEarnings,
    required this.dailyRides,
    required this.selectedIndex,
    required this.onBarTap,
  });

  @override
  State<_WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<_WeeklyBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const maxBarHeight = 120.0;
    final maxVal = widget.dailyEarnings.fold(0.0, (a, b) => a > b ? a : b);
    final now = DateTime.now();

    // Day labels: last 7 days starting from 6 days ago
    final dayLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      if (i == 6) return 'Today';
      return DateFormat('EEE').format(d); // Mon, Tue…
    });

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final val = widget.dailyEarnings[i];
          final barFrac = maxVal > 0 ? (val / maxVal) : 0.0;
          final barH = ((barFrac * maxBarHeight) * _anim.value)
              .clamp(4.0, maxBarHeight);
          final isToday = i == 6;
          final isSelected = widget.selectedIndex == i;
          final hasData = val > 0;

          final barColor = isSelected
              ? AppColors.primaryOrange
              : isToday
                  ? AppColors.primaryGreen
                  : hasData
                      ? const Color(0xFF81C784)
                      : Colors.grey.shade200;

          return GestureDetector(
            onTap: () => widget.onBarTap(i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 36,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Amount above bar (only if selected or today)
                  if (hasData && (isSelected || isToday))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '₹${val.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primaryOrange
                                : AppColors.primaryGreen),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    const SizedBox(height: 16),

                  // Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 28 : 22,
                    height: barH,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: AppColors.primaryOrange.withAlpha(80),
                              blurRadius: 8, offset: const Offset(0, -2))]
                          : [],
                    ),
                  ),

                  // Ride count dot
                  if (widget.dailyRides[i] > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.bgGreen : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${widget.dailyRides[i]}',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? AppColors.primaryGreen
                                  : AppColors.textGrey),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 13),

                  const SizedBox(height: 4),

                  // Day label
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: isToday
                            ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? AppColors.primaryGreen : AppColors.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Recent trips card
// ─────────────────────────────────────────

class _RecentTripsCard extends StatelessWidget {
  final List<Map<String, dynamic>> rides;
  const _RecentTripsCard({required this.rides});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.history, color: AppColors.primaryGreen, size: 20),
          SizedBox(width: 8),
          Text('Recent Trips',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        ...rides.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          final fare = (d['fare'] ?? 0).toDouble();
          final pickup = d['pickupVillage'] ?? '—';
          final dest = d['destinationVillage'] ?? '—';
          final completedAt = d['completedAt'] != null
              ? (d['completedAt'] as Timestamp).toDate() : null;
          final dateStr = completedAt != null
              ? DateFormat('d MMM, h:mm a').format(completedAt) : '';

          return Column(children: [
            if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                // Index badge
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.bgGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primaryGreen)),
                  ),
                ),
                const SizedBox(width: 12),
                // Route
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.circle, size: 7,
                          color: AppColors.primaryGreen),
                      const SizedBox(width: 5),
                      Expanded(child: Text(pickup,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(width: 1, height: 10,
                          color: Colors.grey.shade300),
                    ),
                    Row(children: [
                      const Icon(Icons.location_on, size: 9,
                          color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Expanded(child: Text(dest,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textGrey)),
                    ],
                  ],
                )),
                const SizedBox(width: 8),
                // Fare
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryGreen)),
                  const Text('cash',
                      style: TextStyle(
                          fontSize: 9, color: AppColors.textGrey)),
                ]),
              ]),
            ),
          ]);
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// Badge card
// ─────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final int totalRides;
  final double rating;
  final _Badge? currentBadge;
  final _Badge? nextBadge;

  const _BadgeCard({
    required this.totalRides, required this.rating,
    required this.currentBadge, required this.nextBadge,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.military_tech, color: AppColors.primaryGreen, size: 20),
          SizedBox(width: 8),
          Text('Saathi Level · સ્તર',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 16),

        // Current badge display
        if (currentBadge != null)
          Center(child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: currentBadge!.color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                    color: currentBadge!.color.withAlpha(80), width: 2),
              ),
              child: Icon(currentBadge!.icon,
                  color: currentBadge!.color, size: 36),
            ),
            const SizedBox(height: 8),
            Text(currentBadge!.title,
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 16, color: currentBadge!.color)),
            Text(currentBadge!.titleGu,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textGrey)),
          ]))
        else
          Center(child: Column(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: Colors.grey[100], shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_outlined,
                  color: Colors.grey, size: 30),
            ),
            const SizedBox(height: 8),
            const Text('Complete 10 rides to earn Bronze badge',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ])),

        // Next badge progress
        if (nextBadge != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.arrow_upward, color: nextBadge!.color, size: 14),
            const SizedBox(width: 6),
            Text('Next: ${nextBadge!.title}',
                style: TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 13, color: nextBadge!.color)),
            const Spacer(),
            Text('$totalRides/${nextBadge!.requiredRides} rides',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textGrey)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (totalRides / nextBadge!.requiredRides).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(nextBadge!.color),
            ),
          ),
          const SizedBox(height: 6),
          Text('${nextBadge!.requiredRides - totalRides} more rides to go!',
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),
        const Text('All Badges',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 10),

        // All badges row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _badges.map((b) {
            final unlocked = totalRides >= b.requiredRides;
            return Column(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: unlocked ? b.color.withAlpha(30) : Colors.grey[100],
                  shape: BoxShape.circle,
                  border: unlocked
                      ? Border.all(color: b.color.withAlpha(100), width: 1.5)
                      : null,
                ),
                child: Icon(b.icon,
                    color: unlocked ? b.color : Colors.grey[400], size: 24),
              ),
              const SizedBox(height: 4),
              Text(b.title.split(' ').first,
                  style: TextStyle(
                      fontSize: 9,
                      color: unlocked ? b.color : Colors.grey[400],
                      fontWeight: FontWeight.w600)),
              Text(unlocked ? '✓' : '${b.requiredRides}',
                  style: TextStyle(
                      fontSize: 8,
                      color: unlocked ? b.color : Colors.grey[400])),
            ]);
          }).toList(),
        ),
      ],
    ));
  }
}

// ─────────────────────────────────────────
// Shared card container
// ─────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────
// Pay info row
// ─────────────────────────────────────────

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  const _PayRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Error view
// ─────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        const Text('Could not load earnings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        Text(error,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Retry',
              style: TextStyle(color: Colors.white)),
          onPressed: onRetry,
        ),
      ]),
    ));
  }
}
