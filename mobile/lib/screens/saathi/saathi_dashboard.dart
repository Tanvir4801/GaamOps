import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/saathi_model.dart';
import '../../models/ride_model.dart';
import '../../services/saathi_service.dart';
import '../../services/ride_service.dart';
import '../../widgets/sos_button.dart';
import 'saathi_ride_screen.dart';

class SaathiDashboard extends StatefulWidget {
  const SaathiDashboard({super.key});

  @override
  State<SaathiDashboard> createState() => _SaathiDashboardState();
}

class _SaathiDashboardState extends State<SaathiDashboard>
    with SingleTickerProviderStateMixin {
  bool _isOnline = false;
  bool _toggling = false;
  SaathiModel? _saathi;
  RideModel? _activeRide;
  double _todayEarnings = 0;
  int _todayRides = 0;
  Position? _myPosition;
  StreamSubscription? _rideSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _saathiSub;
  bool _popupShown = false;
  late AnimationController _onlineCtrl;
  late Animation<double> _onlineAnim;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _onlineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _onlineAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_onlineCtrl);
    _init();
  }

  Future<void> _init() async {
    if (_uid == null) return;
    _saathiSub = SaathiService.watchSaathi(_uid!).listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _saathi = SaathiModel.fromFirestore(snap));
      }
    });
    try {
      final earnings = await RideService.getSaathiEarnings(_uid!);
      if (mounted) {
        setState(() {
          _todayEarnings = (earnings['today'] ?? 0).toDouble();
          _todayRides = (earnings['todayRides'] ?? 0).toInt();
        });
      }
    } catch (_) {}
    _listenForRides();
  }

  void _listenForRides() {
    _rideSub?.cancel();
    _rideSub = RideService.watchIncomingRides().listen((snap) {
      if (!mounted) return;
      final rides = snap.docs.map((d) => RideModel.fromFirestore(d)).toList();
      if (rides.isNotEmpty && _isOnline && _activeRide == null && !_popupShown) {
        _showRideRequestPopup(rides.first);
      }
    });
  }

  void _showRideRequestPopup(RideModel ride) {
    if (!mounted || _popupShown) return;
    _popupShown = true;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _RideRequestModal(
        ride: ride,
        onAccept: () {
          Navigator.pop(context);
          _popupShown = false;
          _acceptRide(ride);
        },
        onReject: () {
          Navigator.pop(context);
          _popupShown = false;
        },
      ),
    ).then((_) => _popupShown = false);
  }

  Future<void> _toggleOnline() async {
    if (_uid == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      if (_isOnline) {
        await SaathiService.goOffline(_uid!);
        _locationSub?.cancel();
        setState(() => _isOnline = false);
      } else {
        await SaathiService.goOnline(_uid!);
        setState(() => _isOnline = true);
        _startLocationUpdates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _startLocationUpdates() {
    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      _myPosition = pos;
      if (_uid != null) {
        SaathiService.updateLocation(_uid!, pos.latitude, pos.longitude);
        if (_activeRide != null) {
          RideService.updateSaathiLocation(
            rideId: _activeRide!.rideId,
            lat: pos.latitude,
            lng: pos.longitude,
          );
        }
      }
    });
  }

  Future<void> _acceptRide(RideModel ride) async {
    if (_uid == null || _saathi == null) return;
    // Set immediately — prevents race-condition popup during the async gap
    setState(() => _activeRide = ride);
    await RideService.acceptRide(
      rideId: ride.rideId,
      saathiId: _uid!,
      saathiName: _saathi!.name,
      saathiPhone: _saathi!.phone,
    );
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SaathiRideScreen(
          ride: ride,
          onComplete: _onRideComplete,
        ),
      ));
    }
  }

  void _onRideComplete() {
    // Mark as busy briefly so popup doesn't fire the instant we land on dashboard
    _popupShown = true;
    setState(() => _activeRide = null);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _popupShown = false);
        // Re-subscribe so the stream fires immediately with current Firestore data
        _listenForRides();
      }
    });
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _locationSub?.cancel();
    _saathiSub?.cancel();
    _onlineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(slivers: [
        // Header app bar
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: AppColors.primaryGreen,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _saathi?.name ?? 'Gaam Saathi',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Row(children: [
                          if (_isOnline)
                            FadeTransition(
                              opacity: _onlineAnim,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF69F0AE),
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
                            _isOnline
                                ? AppStrings.onlineGu : AppStrings.offlineGu,
                            style: TextStyle(
                                fontSize: 13,
                                color: _isOnline
                                    ? const Color(0xFF69F0AE) : Colors.white60),
                          ),
                        ]),
                      ],
                    )),
                    // SOS button
                    if (_myPosition != null)
                      SosButton(
                        lat: _myPosition?.latitude,
                        lng: _myPosition?.longitude,
                      ),
                    const SizedBox(width: 8),
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
              // Online toggle card — animated gradient
              GestureDetector(
                onTap: _toggling ? null : _toggleOnline,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isOnline
                          ? const [Color(0xFF1B5E20), Color(0xFF2E7D32)]
                          : const [Color(0xFF616161), Color(0xFF757575)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (_isOnline
                                ? AppColors.primaryGreen
                                : Colors.grey)
                            .withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_isOnline),
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isOnline
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? '🟢 Online' : '⭕ Offline',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _isOnline
                              ? 'Customers can find you · GPS active'
                              : 'Tap to go online and earn',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    )),
                    _toggling
                        ? const SizedBox(
                            width: 36, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Switch.adaptive(
                            value: _isOnline,
                            onChanged: (_) => _toggleOnline(),
                            activeColor: Colors.white,
                            activeTrackColor: Colors.white.withOpacity(0.4),
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor:
                                Colors.white.withOpacity(0.3),
                          ),
                  ]),
                ),
              ),

              const SizedBox(height: 16),

              // Earnings row
              Row(children: [
                _earningsCard('આજની કમાણી',
                    '₹${_todayEarnings.toStringAsFixed(0)}',
                    '$_todayRides rides today',
                    AppColors.primaryGreen),
                const SizedBox(width: 12),
                _earningsCard('Rating',
                    '${(_saathi?.rating ?? 5.0).toStringAsFixed(1)} ★',
                    'Saathi score',
                    AppColors.warning),
              ]),

              const SizedBox(height: 16),

              // Vehicle card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bgGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.electric_rickshaw,
                        color: AppColors.primaryGreen, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Vehicle',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textGrey)),
                      Text(_saathi?.vehicleType ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_saathi?.vehicleNumber ?? '—',
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 13)),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _saathi?.isBlocked == true
                          ? Colors.red.shade50 : AppColors.bgGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _saathi?.isBlocked == true
                          ? 'Blocked' : '✓ Active',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: _saathi?.isBlocked == true
                              ? Colors.red : AppColors.primaryGreen),
                    ),
                  ),
                ]),
              ),

              // Offline motivational banner / Online tip
              const SizedBox(height: 16),
              if (!_isOnline) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.30),
                        blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('💪 Ready to Earn Today?',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text(
                      '"તમારી ગાડી, તમારી કમાણી.\n'
                      'GaamRide સાથે આજે જ Online થાઓ!"',
                      style: TextStyle(fontSize: 13,
                          color: Colors.white80, height: 1.5)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _statPill('💰', 'Avg ₹400/day'),
                      const SizedBox(width: 8),
                      _statPill('⏱️', 'Flexible hours'),
                      const SizedBox(width: 8),
                      _statPill('🌟', 'Daily earnings'),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _toggling ? null : _toggleOnline,
                        child: const Text('Go Online Now',
                            style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]),
                ),
              ] else ...[
                // Online — rotating motivational tip
                _SaathiMotivationBanner(),
              ],

              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _earningsCard(
      String label, String amount, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text(amount,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(sub,
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
        ]),
      ),
    );
  }
}

Widget _statPill(String emoji, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text('$emoji $label',
        style: const TextStyle(color: Colors.white,
            fontSize: 11, fontWeight: FontWeight.w500)),
  );
}

class _SaathiMotivationBanner extends StatefulWidget {
  const _SaathiMotivationBanner();

  @override
  State<_SaathiMotivationBanner> createState() => _SaathiMotivationBannerState();
}

class _SaathiMotivationBannerState extends State<_SaathiMotivationBanner> {
  static const _tips = [
    'દરરોજ નવી રાઇડ, નવી કમાણી 🌟',
    'Online રહો, Earning વધારો ⚡',
    'ગામના Hero — GaamRide Saathi 🏆',
    'GaamRide સાથે Earn More 💪',
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
        color: AppColors.bgGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.local_fire_department_rounded,
            color: AppColors.primaryGreen, size: 20),
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
                  fontSize: 13, color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RideRequestModal extends StatefulWidget {
  final RideModel ride;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RideRequestModal({
    required this.ride,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_RideRequestModal> createState() => _RideRequestModalState();
}

class _RideRequestModalState extends State<_RideRequestModal> {
  static const int _totalSeconds = 30;
  int _seconds = _totalSeconds;
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

  double get _timerValue => _seconds / _totalSeconds;

  Color get _timerColor {
    if (_timerValue > 0.5) return AppColors.primaryGreen;
    if (_timerValue > 0.25) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Timer bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _timerValue,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_seconds સેકન્ડ / seconds',
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),

          const SizedBox(height: 14),
          const Text('🛵 નવી સવારી વિનંતી!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('New Ride Request',
              style: TextStyle(color: AppColors.textGrey)),

          const SizedBox(height: 18),

          // Route info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.circle, color: AppColors.primaryGreen, size: 12),
                const SizedBox(width: 8),
                Text(ride.pickupVillage,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Container(
                  margin: const EdgeInsets.only(left: 5),
                  height: 18, width: 2, color: Colors.grey.shade300),
              Row(children: [
                const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 14),
                const SizedBox(width: 8),
                Text(ride.destinationVillage,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),

          const SizedBox(height: 14),

          // Ride details chips
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _infoChip('📍', '${((ride.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km'),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            _infoChip('💰', '₹${ride.fare.toStringAsFixed(0)}', bold: true),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            _infoChip('👤', ride.customerName),
          ]),

          const SizedBox(height: 18),

          // Action buttons
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
                child: const Text('નામંજૂર / Reject',
                    style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('✓ સ્વીકારો / Accept',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ),
          ]),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }

  Widget _infoChip(String emoji, String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text('$emoji $text',
          style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppColors.primaryGreen : AppColors.textDark)),
    );
  }
}
