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
import '../../widgets/earnings_card.dart';
import '../../widgets/sos_button.dart';
import 'saathi_ride_screen.dart';

class SaathiDashboard extends StatefulWidget {
  const SaathiDashboard({super.key});

  @override
  State<SaathiDashboard> createState() => _SaathiDashboardState();
}

class _SaathiDashboardState extends State<SaathiDashboard> {
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

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_uid == null) return;
    _saathiSub = SaathiService.watchSaathi(_uid!).listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _saathi = SaathiModel.fromFirestore(snap));
      }
    });
    final earnings = await RideService.getSaathiEarnings(_uid!);
    if (mounted) {
      setState(() {
        _todayEarnings = (earnings['today'] ?? 0).toDouble();
        _todayRides = (earnings['todayRides'] ?? 0).toInt();
      });
    }
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
        setState(() {
          _isOnline = false;
        });
      } else {
        await SaathiService.goOnline(_uid!);
        setState(() => _isOnline = true);
        _startLocationUpdates();
      }
    } finally {
      setState(() => _toggling = false);
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
    await RideService.acceptRide(
      rideId: ride.rideId,
      saathiId: _uid!,
      saathiName: _saathi!.name,
      saathiPhone: _saathi!.phone,
    );
    if (mounted) {
      setState(() => _activeRide = ride);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SaathiRideScreen(
            ride: ride,
            onComplete: () => setState(() => _activeRide = null),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _locationSub?.cancel();
    _saathiSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _saathi?.name ?? 'Saathi Dashboard',
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            Text(
              _isOnline ? AppStrings.onlineGu : AppStrings.offlineGu,
              style: TextStyle(
                fontSize: 11,
                color: _isOnline ? AppColors.success : AppColors.textGrey,
              ),
            ),
          ],
        ),
        actions: [
          if (_myPosition != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SosButton(
                lat: _myPosition?.latitude,
                lng: _myPosition?.longitude,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isOnline ? AppColors.success : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    boxShadow: _isOnline
                        ? [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? 'Online — Ready for Rides' : 'Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _isOnline
                              ? AppColors.success
                              : AppColors.textGrey,
                        ),
                      ),
                      Text(
                        _isOnline
                            ? AppStrings.gpsActive
                            : 'Go online to receive rides',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
                _toggling
                    ? const SizedBox(
                        width: 36,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch.adaptive(
                        value: _isOnline,
                        onChanged: (_) => _toggleOnline(),
                        activeColor: AppColors.primaryGreen,
                      ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: EarningsCard(
                          label: "Today's Earnings",
                          amount: _todayEarnings,
                          rides: _todayRides,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EarningsCard(
                          label: 'Rating',
                          amount: _saathi?.rating ?? 5.0,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Vehicle',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.electric_rickshaw,
                                color: AppColors.primaryGreen, size: 32),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_saathi?.vehicleType ?? '—',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(_saathi?.vehicleNumber ?? '—',
                                    style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_isOnline) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.bgGreen,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.power_settings_new,
                              color: AppColors.primaryGreen, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'ઓનલાઇન થઈ સવારી સ્વીકારો',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen),
                          ),
                          Text(
                            'Go online to start accepting rides',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
    return WillPopScope(
      onWillPop: () async => false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _timerValue,
                minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_seconds સેકન્ડ / seconds',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textGrey),
            ),
            const SizedBox(height: 14),
            const Text(
              '🛵 નવી સવારી વિનંતી!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'New Ride Request',
              style: TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle,
                          color: AppColors.primaryGreen, size: 12),
                      const SizedBox(width: 8),
                      Text(
                        ride.pickupVillage,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 5),
                    height: 18,
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primaryOrange, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        ride.destinationVillage,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  '📍 ${((ride.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 14),
                ),
                Container(
                    width: 1, height: 20, color: Colors.grey.shade300),
                Text(
                  '💰 ₹${ride.fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
                Container(
                    width: 1, height: 20, color: Colors.grey.shade300),
                Text(
                  '👤 ${ride.customerName}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
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
                    child: const Text(
                      'સ્વીકારો / Accept',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
