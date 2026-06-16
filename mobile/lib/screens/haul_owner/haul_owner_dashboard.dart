import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../../models/haul_vehicle_model.dart';
import '../../services/haul_service.dart';
import 'haul_owner_job_screen.dart';

class HaulOwnerDashboard extends StatefulWidget {
  const HaulOwnerDashboard({super.key});

  @override
  State<HaulOwnerDashboard> createState() => _HaulOwnerDashboardState();
}

class _HaulOwnerDashboardState extends State<HaulOwnerDashboard>
    with SingleTickerProviderStateMixin {
  HaulVehicleModel? _vehicle;
  HaulBookingModel? _activeBooking;
  double _todayEarnings = 0;
  int _todayJobs = 0;
  StreamSubscription? _bookingSub;
  StreamSubscription? _vehicleSub;
  bool _popupShown = false;
  bool _toggling = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);
    _init();
  }

  Future<void> _init() async {
    if (_uid == null) return;
    _vehicleSub = HaulService.watchOwnerVehicle(_uid!).listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _vehicle = HaulVehicleModel.fromFirestore(snap));
      }
    });
    try {
      final e = await HaulService.getOwnerEarningsToday(_uid!);
      if (mounted) {
        setState(() {
          _todayEarnings = (e['today'] ?? 0).toDouble();
          _todayJobs     = (e['count']  ?? 0).toInt();
        });
      }
    } catch (_) {}
    _listenBookings();
  }

  void _listenBookings() {
    _bookingSub?.cancel();
    _bookingSub = HaulService.watchIncomingBookings(_uid!).listen((snap) {
      if (!mounted) return;
      final list = snap.docs
          .map((d) => HaulBookingModel.fromFirestore(d))
          .toList();
      if (list.isNotEmpty && _activeBooking == null && !_popupShown) {
        _showBookingPopup(list.first);
      }
    });
  }

  void _showBookingPopup(HaulBookingModel booking) {
    if (!mounted || _popupShown) return;
    _popupShown = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingRequestModal(
        booking: booking,
        onAccept: () {
          Navigator.pop(context);
          _popupShown = false;
          _acceptBooking(booking);
        },
        onReject: () {
          Navigator.pop(context);
          _popupShown = false;
        },
      ),
    ).then((_) => _popupShown = false);
  }

  Future<void> _acceptBooking(HaulBookingModel booking) async {
    if (_uid == null) return;
    setState(() => _activeBooking = booking);
    await HaulService.acceptBooking(
        bookingId: booking.bookingId, ownerId: _uid!);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HaulOwnerJobScreen(
            booking: booking,
            onComplete: _onJobComplete,
          ),
        ),
      );
    }
  }

  void _onJobComplete() {
    _popupShown = true;
    setState(() => _activeBooking = null);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _popupShown = false);
        _listenBookings();
        _reloadEarnings();
      }
    });
  }

  Future<void> _reloadEarnings() async {
    if (_uid == null) return;
    try {
      final e = await HaulService.getOwnerEarningsToday(_uid!);
      if (mounted) {
        setState(() {
          _todayEarnings = (e['today'] ?? 0).toDouble();
          _todayJobs     = (e['count']  ?? 0).toInt();
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAvailability() async {
    if (_uid == null || _vehicle == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      await HaulService.updateVehicleAvailability(
          _uid!, !_vehicle!.isAvailable);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    _vehicleSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _vehicle;
    final isAvailable = v?.isAvailable ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFF57C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            v?.ownerName ?? 'GaamHaul Owner',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          Row(children: [
                            if (isAvailable)
                              FadeTransition(
                                opacity: _pulseAnim,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFFFE082),
                                      shape: BoxShape.circle),
                                ),
                              )
                            else
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(100),
                                    shape: BoxShape.circle),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              isAvailable
                                  ? 'Available for Bookings'
                                  : 'Unavailable',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isAvailable
                                      ? const Color(0xFFFFE082)
                                      : Colors.white60),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    Text(v?.vehicleEmoji ?? '🚛',
                        style: const TextStyle(fontSize: 40)),
                  ]),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Availability toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(10), blurRadius: 8)
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppColors.bgOrange : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAvailable ? Icons.check_circle : Icons.do_not_disturb,
                      color: isAvailable
                          ? AppColors.primaryOrange : AppColors.textGrey,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAvailable
                                ? 'Available — Accepting Bookings'
                                : 'Unavailable',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isAvailable
                                    ? AppColors.primaryOrange
                                    : AppColors.textGrey),
                          ),
                          Text(
                            isAvailable
                                ? 'Customers can book your vehicle'
                                : 'Toggle to accept new bookings',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey),
                          ),
                        ]),
                  ),
                  _toggling
                      ? const SizedBox(
                          width: 36, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primaryOrange))
                      : Switch.adaptive(
                          value: isAvailable,
                          onChanged: (_) => _toggleAvailability(),
                          activeColor: AppColors.primaryOrange,
                        ),
                ]),
              ),

              const SizedBox(height: 16),

              // Stats row
              Row(children: [
                _statCard('આજની કમાણી',
                    '₹${_todayEarnings.toStringAsFixed(0)}',
                    '$_todayJobs jobs today',
                    AppColors.primaryOrange),
                const SizedBox(width: 12),
                _statCard('Total Jobs',
                    '${v?.totalBookings ?? 0}',
                    'All time',
                    Colors.indigo),
              ]),

              const SizedBox(height: 16),

              // Vehicle info
              if (v != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(8), blurRadius: 8)
                    ],
                  ),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.bgOrange,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(v.vehicleEmoji ?? '🚛',
                              style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.vehicleTypeLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(v.vehicleNumber,
                                  style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 13)),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.bgOrange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹${v.ratePerHour.toStringAsFixed(0)}/hr',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryOrange),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(v.village,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.scale_outlined,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(v.capacity,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                    ]),
                  ]),
                ),
              ],

              // Unavailable prompt
              if (!isAvailable) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgOrange,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primaryOrange.withAlpha(80)),
                  ),
                  child: Column(children: [
                    const Text('🚛',
                        style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    const Text('ઉપલબ્ધ બનો · Go Available',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.primaryOrange)),
                    const SizedBox(height: 4),
                    const Text('Toggle to start receiving haul bookings',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textGrey)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _toggling ? null : _toggleAvailability,
                        child: const Text('Go Available',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _statCard(
      String label, String value, String sub, Color color) {
    // Parse numeric portion for animation (e.g. "₹1,200" → 1200, "5" → 5)
    final numericStr = value.replaceAll(RegExp(r'[^0-9]'), '');
    final targetNum = double.tryParse(numericStr) ?? 0;
    final prefix = value.contains('₹') ? '₹' : '';
    final suffix = value.replaceAll(RegExp(r'[₹0-9,]'), '');

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textGrey)),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: targetNum),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) {
              final display = targetNum >= 100
                  ? v.toInt().toString()
                  : v.toStringAsFixed(0);
              return Text(
                '$prefix$display$suffix',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color),
              );
            },
          ),
          Text(sub,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textGrey)),
        ]),
      ),
    );
  }
}

// ─── Booking Request Modal ─────────────────────────────────────────────────

class _BookingRequestModal extends StatefulWidget {
  final HaulBookingModel booking;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _BookingRequestModal({
    required this.booking,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_BookingRequestModal> createState() => _BookingRequestModalState();
}

class _BookingRequestModalState extends State<_BookingRequestModal> {
  static const int _total = 30;
  int _seconds = _total;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_seconds <= 1) {
        t.cancel();
        widget.onReject();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final frac = _seconds / _total;
    final timerColor = frac > 0.5
        ? AppColors.primaryOrange
        : frac > 0.25
            ? Colors.deepOrange
            : Colors.red;

    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          const SizedBox(height: 6),
          Text('$_seconds seconds to respond',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textGrey)),
          const SizedBox(height: 14),
          Text(b.vehicleEmoji,
              style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 4),
          const Text('🚛 નવી બુકિંગ વિનંતી!',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('New Haul Booking Request',
              style: TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chip(Icons.person, b.customerName),
                  const SizedBox(height: 8),
                  _chip(Icons.location_on_outlined, b.pickupVillage),
                  const SizedBox(height: 8),
                  _chip(Icons.inventory_2_outlined, b.loadDescription),
                  const SizedBox(height: 8),
                  _chip(Icons.timer_outlined, b.durationLabel),
                  const SizedBox(height: 8),
                  _chip(Icons.currency_rupee,
                      '₹${b.ownerEarnings.toStringAsFixed(0)} earnings',
                      bold: true, color: AppColors.primaryOrange),
                ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('✓ Accept Job',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ]),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label,
      {bool bold = false, Color? color}) {
    return Row(children: [
      Icon(icon, size: 15,
          color: color ?? AppColors.primaryOrange),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.textDark)),
      ),
    ]);
  }
}

extension on HaulVehicleModel {
  String? get vehicleEmoji {
    switch (vehicleType.toLowerCase()) {
      case 'tractor':    return '🚜';
      case 'pickup':     return '🛻';
      case 'truck_407':  return '🚚';
      default:           return '🚛';
    }
  }
}
