import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../../services/haul_service.dart';

class HaulOwnerHistoryScreen extends StatefulWidget {
  const HaulOwnerHistoryScreen({super.key});

  @override
  State<HaulOwnerHistoryScreen> createState() => _HaulOwnerHistoryScreenState();
}

class _HaulOwnerHistoryScreenState extends State<HaulOwnerHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<HaulBookingModel> _bookings = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _load();
  }

  Future<void> _load() async {
    if (_uid == null) return;
    try {
      final docs = await HaulService.getOwnerHistory(_uid!);
      if (mounted) {
        setState(() {
          _bookings =
              docs.map((d) => HaulBookingModel.fromFirestore(d)).toList();
          _loading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalEarnings =>
      _bookings.fold(0, (sum, b) => sum + b.ownerEarnings);

  int get _completedCount =>
      _bookings.where((b) => b.status == HaulBookingModel.completed).length;

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBrown,
      body: CustomScrollView(slivers: [
        // ─── Brown Header ───────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          expandedHeight: _loading ? 0 : (_bookings.isEmpty ? 0 : 120),
          backgroundColor: AppColors.primaryBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Job History',
              style: TextStyle(fontWeight: FontWeight.bold)),
          flexibleSpace: _loading || _bookings.isEmpty
              ? null
              : FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF3E2723),
                          Color(0xFF5D4037),
                          Color(0xFF8D6E63),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
                        child: Row(children: [
                          _miniStat('${_bookings.length}', 'Total Jobs'),
                          _vDivider(),
                          _miniStat(_completedCount.toString(), 'Completed'),
                          _vDivider(),
                          _miniStat(
                              '₹${_totalEarnings.toStringAsFixed(0)}',
                              'Earnings'),
                        ]),
                      ),
                    ),
                  ),
                ),
        ),

        // ─── Body ───────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(
                        color: AppColors.primaryBrown),
                  ),
                )
              : _bookings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Column(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.bgBrown,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_rounded,
                                  color: AppColors.mediumBrown, size: 36),
                            ),
                            const SizedBox(height: 16),
                            const Text('No jobs yet',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: AppColors.textDark)),
                            const SizedBox(height: 6),
                            const Text(
                                'Completed bookings will appear here.',
                                style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(
                          children: _bookings
                              .map((b) => _BookingCard(booking: b))
                              .toList(),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.7))),
      ]),
    );
  }

  Widget _vDivider() {
    return Container(
        width: 1, height: 32, color: Colors.white.withOpacity(0.25));
  }
}

// ─── Booking Card ───────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final HaulBookingModel booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isCompleted = b.status == HaulBookingModel.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(7),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Top row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bgBrown,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(b.vehicleEmoji,
                    style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.vehicleTypeLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark)),
                    Text(b.customerName,
                        style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 12)),
                  ]),
            ),
            // Status pill
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFE8F5E9)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isCompleted ? '✓ Done' : b.status,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? AppColors.success
                        : Colors.red),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(b.pickupVillage,
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.timer_outlined,
                size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Text(b.durationLabel,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 12)),
          ]),
        ),

        const SizedBox(height: 10),
        Divider(height: 1, color: Colors.grey.shade100),

        // Bottom: earnings + load
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined,
                size: 13, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(b.loadDescription,
                  style: const TextStyle(
                      color: AppColors.textGrey, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(
              '₹${b.ownerEarnings.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primaryBrown),
            ),
          ]),
        ),
      ]),
    );
  }
}
