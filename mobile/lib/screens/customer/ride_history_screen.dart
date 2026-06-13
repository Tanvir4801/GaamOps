import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../utils/date_formatter.dart';
import 'ride_receipt_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<RideModel> _rides = [];
  bool _loading = true;
  String _filter = 'all';
  late TabController _tabCtrl;

  static const _tabs = [
    ('all', 'All'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _filter = _tabs[_tabCtrl.index].$1);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docs = await RideService.getCustomerHistory(uid);
    if (mounted) {
      setState(() {
        _rides = docs.map((d) => RideModel.fromFirestore(d)).toList();
        _loading = false;
      });
    }
  }

  List<RideModel> get _filtered {
    if (_filter == 'all') return _rides;
    return _rides.where((r) => r.status == _filter).toList();
  }

  double get _totalSpent => _rides
      .where((r) => r.status == RideModel.completed)
      .fold(0, (sum, r) => sum + r.fare);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Ride History',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primaryGreen,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
        ),
      ),
      body: _loading
          ? _ShimmerList()
          : Column(
              children: [
                if (_rides.isNotEmpty) _buildSummary(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: _tabs.map((t) {
                      final list = t.$1 == 'all'
                          ? _rides
                          : _rides.where((r) => r.status == t.$1).toList();
                      if (list.isEmpty) return _EmptyState(filter: t.$2);
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _RideCard(
                          ride: list[i],
                          index: i,
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, animation, __) =>
                                  RideReceiptScreen(ride: list[i]),
                              transitionsBuilder: (_, animation, __, child) =>
                                  FadeTransition(opacity: animation, child: child),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummary() {
    final completed = _rides.where((r) => r.status == RideModel.completed).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          _SummaryChip(
              label: '$completed Rides',
              icon: Icons.check_circle_outline,
              color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          _SummaryChip(
              label: '₹${_totalSpent.toStringAsFixed(0)} Spent',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.amber),
          const SizedBox(width: 10),
          _SummaryChip(
              label: '${_rides.length} Total',
              icon: Icons.receipt_long,
              color: Colors.blue),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RideCard extends StatefulWidget {
  final RideModel ride;
  final VoidCallback onTap;
  final int index;

  const _RideCard({required this.ride, required this.onTap, required this.index});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + widget.index * 50),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.ride.status) {
      case RideModel.completed: return AppColors.primaryGreen;
      case RideModel.cancelled: return AppColors.error;
      default: return Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (widget.ride.status) {
      case RideModel.completed: return Icons.check_circle_rounded;
      case RideModel.cancelled: return Icons.cancel_rounded;
      default: return Icons.access_time_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _statusColor.withAlpha(15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_statusIcon, color: _statusColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.pickupVillage} → ${r.destinationVillage}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            DateFormatter.format(r.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${r.fare.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primaryGreen),
                        ),
                        Text(r.status.toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _statusColor)),
                      ],
                    ),
                  ],
                ),
                if (r.saathiName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.bgGreen,
                        child: Icon(Icons.person, size: 14, color: AppColors.primaryGreen),
                      ),
                      const SizedBox(width: 8),
                      Text(r.saathiName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      if (r.rating > 0)
                        Row(
                          children: List.generate(
                            r.rating,
                            (_) => const Icon(Icons.star_rounded,
                                size: 13, color: Colors.amber),
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Icon(Icons.receipt_outlined,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 3),
                      const Text('Receipt',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textGrey)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.textGrey, size: 48),
          const SizedBox(height: 12),
          Text(
            filter == 'All' ? 'No rides yet' : 'No $filter rides',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          const Text('Book your first ride from the home screen',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ShimmerList extends StatefulWidget {
  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmer = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) => Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(-2 + _shimmer.value, 0),
              end: Alignment(2 + _shimmer.value, 0),
              colors: const [
                Color(0xFFEEEEEE),
                Color(0xFFF5F5F5),
                Color(0xFFEEEEEE),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
