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
import '../../services/auth_service.dart';
import '../../widgets/ride_request_popup.dart';
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
  RideModel? _incomingRide;
  RideModel? _activeRide;
  double _todayEarnings = 0;
  int _todayRides = 0;
  Position? _myPosition;
  StreamSubscription? _rideSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _saathiSub;

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
      if (rides.isNotEmpty && _isOnline && _activeRide == null) {
        setState(() => _incomingRide = rides.first);
      }
    });
  }

  Future<void> _toggleOnline() async {
    if (_uid == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      if (_isOnline) {
        await SaathiService.goOffline(_uid!);
        _locationSub?.cancel();
        setState(() { _isOnline = false; _incomingRide = null; });
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
      setState(() { _incomingRide = null; _activeRide = ride; });
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

  void _rejectRide() => setState(() => _incomingRide = null);

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? '🟢 Online' : '⭕ Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _isOnline ? AppColors.success : AppColors.textGrey,
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
                Switch.adaptive(
                  value: _isOnline,
                  onChanged: _toggling ? null : (_) => _toggleOnline(),
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
                  if (_incomingRide != null && _isOnline)
                    RideRequestPopup(
                      ride: _incomingRide!,
                      onAccept: () => _acceptRide(_incomingRide!),
                      onReject: _rejectRide,
                    ),
                  const SizedBox(height: 10),
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(_saathi?.vehicleNumber ?? '—',
                                    style: const TextStyle(
                                        color: AppColors.textGrey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

