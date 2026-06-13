import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../widgets/loading_overlay.dart';
import 'ride_complete_screen.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  StreamSubscription? _sub;
  RideModel? _ride;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _sub = RideService.watchRide(widget.rideId).listen((snap) {
      if (snap.exists && mounted) {
        final ride = RideModel.fromFirestore(snap);
        setState(() {
          _ride = ride;
          _updateMarkers(ride);
        });
        if (ride.status == RideModel.completed) {
          _sub?.cancel();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => RideCompleteScreen(ride: ride)),
            (route) => route.isFirst,
          );
        }
      }
    });
  }

  void _updateMarkers(RideModel ride) {
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(ride.pickupLat, ride.pickupLng),
        infoWindow: InfoWindow(title: 'Pickup: ${ride.pickupVillage}'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(ride.destinationLat, ride.destinationLng),
        infoWindow: InfoWindow(title: 'Destination: ${ride.destinationVillage}'),
      ),
      if (ride.saathiLat != 0)
        Marker(
          markerId: const MarkerId('saathi'),
          position: LatLng(ride.saathiLat, ride.saathiLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: '🛵 ${ride.saathiName}'),
        ),
    };
  }

  String get _statusText {
    switch (_ride?.status) {
      case RideModel.searching:
        return '🔍 ' + AppStrings.searchingRide;
      case RideModel.accepted:
        return '🛵 ' + AppStrings.saathiOnWay;
      case RideModel.arriving:
        return '📍 ' + AppStrings.saathiArrived;
      case RideModel.started:
        return '🚀 ' + AppStrings.rideStarted;
      default:
        return 'Ride Active';
    }
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('સવારી રદ કરવી? / Cancel Ride?'),
        content: const Text(
            'શું તમે ખરેખર સવારી રદ કરવા ઈચ્છો છો?\nAre you sure you want to cancel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ના / No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('હા / Yes',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await RideService.cancelRide(widget.rideId, 'Cancelled by customer');
      if (mounted) Navigator.pop(context);
    }
  }

  void _callSaathi() async {
    if (_ride?.saathiPhone == null) return;
    final uri = Uri(scheme: 'tel', path: _ride!.saathiPhone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _showSOS() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching =
        _ride?.status == RideModel.searching || _ride == null;
    final saathiName = _ride?.saathiName ?? '—';
    final vehicleType = _ride?.vehicleType ?? '—';

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _ride == null,
        child: Stack(
          children: [
            if (_ride != null && _ride!.pickupLat != 0)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_ride!.pickupLat, _ride!.pickupLng),
                  zoom: 14,
                ),
                markers: _markers,
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              )
            else
              Container(color: AppColors.bgGreen),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    4, MediaQuery.of(context).padding.top + 4, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    BackButton(
                      color: Colors.white,
                      onPressed: isSearching ? _cancelRide : null,
                    ),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showSOS,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.sosRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'SOS 🆘',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isSearching) ...[
                      const LinearProgressIndicator(
                        backgroundColor: AppColors.bgGreen,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'સાથી શોધી રહ્યા છીએ...',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark),
                      ),
                      const Text(
                        'Searching for Saathi near you',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _cancelRide,
                        child: const Text('સવારી રદ કરો / Cancel Ride',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.bgGreen,
                            child: Text(
                              saathiName.isNotEmpty
                                  ? saathiName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  saathiName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$vehicleType · ${_statusText.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim()}',
                                  style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _callSaathi,
                            icon: const Icon(Icons.call,
                                color: AppColors.primaryGreen),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.bgGreen,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                      if (_ride?.status == RideModel.arriving) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgGreen,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.primaryGreen),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'સાથીને આ OTP આપો',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500),
                              ),
                              const Text(
                                'Give this OTP to Saathi',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _ride?.otp ?? '—',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                  letterSpacing: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
