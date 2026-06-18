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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

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
      backgroundColor: AppColors.bgBrown,
      body: CustomScrollView(slivers: [
        // ─── Premium Brown Header ───────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 150,
          pinned: true,
          backgroundColor: AppColors.primaryBrown,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _greeting,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.65),
                                letterSpacing: 0.3),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            v?.ownerName ?? 'GaamHaul Owner',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            if (isAvailable)
                              FadeTransition(
                                opacity: _pulseAnim,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFA5D6A7),
                                      shape: BoxShape.circle),
                                ),
                              )
                            else
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(80),
                                    shape: BoxShape.circle),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              isAvailable
                                  ? 'Available for Bookings'
                                  : 'Offline — Toggle to go online',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isAvailable
                                      ? const Color(0xFFA5D6A7)
                                      : Colors.white54),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    // Vehicle emoji large
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          v?.vehicleTypeEmoji ?? '🚛',
                          style: const TextStyle(fontSize: 34),
                        ),
                      ),
                    ),
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
              // ─── Availability Toggle ──────────────────────────────────────
              GestureDetector(
                onTap: _toggling ? null : _toggleAvailability,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAvailable
                          ? const [Color(0xFF5D4037), Color(0xFF8D6E63)]
                          : const [Color(0xFF616161), Color(0xFF757575)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: (isAvailable
                                ? AppColors.primaryBrown
                                : Colors.grey)
                            .withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(isAvailable),
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAvailable
                              ? Icons.local_shipping_rounded
                              : Icons.do_not_disturb_on_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAvailable
                                ? '🟢 Available'
                                : '⭕ Offline',
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAvailable
                                ? 'Customers can book your vehicle'
                                : 'Tap to start accepting bookings',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    _toggling
                        ? const SizedBox(
                            width: 36, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : Switch.adaptive(
                            value: isAvailable,
                            onChanged: (_) => _toggleAvailability(),
                            activeColor: Colors.white,
                            activeTrackColor:
                                Colors.white.withOpacity(0.35),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor:
                                Colors.white.withOpacity(0.25),
                          ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Stats Row ────────────────────────────────────────────────
              Row(children: [
                _statCard(
                    '₹${_todayEarnings.toStringAsFixed(0)}',
                    'Today\'s Earnings',
                    '$_todayJobs jobs',
                    AppColors.primaryBrown,
                    Icons.currency_rupee_rounded),
                const SizedBox(width: 12),
                _statCard(
                    '${v?.totalBookings ?? 0}',
                    'Total Jobs',
                    'All time',
                    AppColors.mediumBrown,
                    Icons.work_history_outlined),
              ]),

              const SizedBox(height: 16),

              // ─── Vehicle Info Card ────────────────────────────────────────
              if (v != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withAlpha(7),
                          blurRadius: 12,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.bgBrown,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(v.vehicleTypeEmoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${v.vehicleTypeEmoji}  ${v.vehicleTypeLabel}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              v.vehicleNumber.isNotEmpty
                                  ? v.vehicleNumber
                                  : 'No plate set',
                              style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.bgBrown,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₹${v.ratePerHour.toStringAsFixed(0)}/hr',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBrown),
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
                      Text(
                          v.capacity.isNotEmpty ? v.capacity : '—',
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(v.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                    ]),
                  ]),
                ),

              // ─── Offline Prompt / Online Tip ──────────────────────────────
              const SizedBox(height: 16),
              if (!isAvailable)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E342E), Color(0xFF6D4C41)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primaryBrown.withOpacity(0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🚛 Ready to Earn Today?',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text(
                        '"તમારી ગાડી, તમારી કમાણી.\n'
                        'GaamHaul સાથે આજે જ Online થાઓ!"',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        _pill('💰 Avg ₹600/day'),
                        const SizedBox(width: 8),
                        _pill('⏰ Flexible'),
                        const SizedBox(width: 8),
                        _pill('🌟 Village work'),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _toggling
                              ? null
                              : _toggleAvailability,
                          child: const Text(
                            'Go Available Now',
                            style: TextStyle(
                                color: AppColors.primaryBrown,
                                fontWeight: FontWeight.bold,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _HaulMotivationBanner(),

              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _statCard(String value, String label, String sub, Color color,
      IconData icon) {
    final numericStr = value.replaceAll(RegExp(r'[^0-9]'), '');
    final targetNum = double.tryParse(numericStr) ?? 0;
    final prefix = value.contains('₹') ? '₹' : '';
    final suffix = value.replaceAll(RegExp(r'[₹0-9,]'), '');

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color),
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

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Motivation Banner ──────────────────────────────────────────────────────

class _HaulMotivationBanner extends StatefulWidget {
  const _HaulMotivationBanner();

  @override
  State<_HaulMotivationBanner> createState() =>
      _HaulMotivationBannerState();
}

class _HaulMotivationBannerState extends State<_HaulMotivationBanner> {
  static const _tips = [
    'Online રહો, Booking વધારો ⚡',
    'GaamHaul — Village Logistics Hero 🏆',
    'દરરોજ નવી Job, નવી કમાણી 🌟',
    'GaamHaul સાથે Earn More 💪',
  ];
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _cycle();
  }

  void _cycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _tips.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgBrown,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBrown.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.local_fire_department_rounded,
            color: AppColors.primaryBrown, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              _tips[_i],
              key: ValueKey(_i),
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryBrown,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Booking Request Modal ──────────────────────────────────────────────────

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
  State<_BookingRequestModal> createState() =>
      _BookingRequestModalState();
}

class _BookingRequestModalState extends State<_BookingRequestModal> {
  static const int _total = 30;
  int _seconds = _total;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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

  Widget _chip(IconData icon, String text,
      {bool bold = false, Color? color}) {
    return Row(children: [
      Icon(icon, size: 15, color: color ?? AppColors.mediumBrown),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.textDark)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final frac = _seconds / _total;
    final timerColor = frac > 0.5
        ? AppColors.primaryBrown
        : frac > 0.25
            ? const Color(0xFF8D6E63)
            : Colors.red;

    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child:
            Column(mainAxisSize: MainAxisSize.min, children: [
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
          const SizedBox(height: 16),
          Text(b.vehicleEmoji,
              style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 4),
          const Text('🚛 નવી Booking Request!',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('New Haul Booking',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgBrown,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chip(Icons.person_outline, b.customerName),
                  const SizedBox(height: 8),
                  _chip(Icons.location_on_outlined,
                      b.pickupVillage),
                  const SizedBox(height: 8),
                  _chip(Icons.inventory_2_outlined,
                      b.loadDescription),
                  const SizedBox(height: 8),
                  _chip(Icons.timer_outlined, b.durationLabel),
                  const SizedBox(height: 8),
                  _chip(
                    Icons.currency_rupee,
                    '₹${b.ownerEarnings.toStringAsFixed(0)} earnings',
                    bold: true,
                    color: AppColors.primaryBrown,
                  ),
                ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onReject,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Decline',
                    style: TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('✓ Accept Job',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
