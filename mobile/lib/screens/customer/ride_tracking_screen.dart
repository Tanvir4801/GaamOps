import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../widgets/sos_button.dart';
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
      case RideModel.searching: return AppStrings.searchingRide;
      case RideModel.accepted: return AppStrings.saathiOnWay;
      case RideModel.arriving: return AppStrings.saathiArrived;
      case RideModel.started: return AppStrings.rideStarted;
      default: return 'Ride Active';
    }
  }

  Color get _statusColor {
    switch (_ride?.status) {
      case RideModel.searching: return AppColors.warning;
      case RideModel.accepted: return AppColors.primaryGreen;
      case RideModel.arriving: return Colors.blue;
      case RideModel.started: return AppColors.primaryGreen;
      default: return AppColors.textGrey;
    }
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Ride?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await RideService.cancelRide(widget.rideId, 'Cancelled by customer');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _ride?.status == RideModel.searching || _ride == null;

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
              )
            else
              Container(color: AppColors.bgGreen),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusText,
                        style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!isSearching && _ride != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          Text(_ride!.saathiName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          if (_ride!.status == RideModel.arriving)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'OTP: ${_ride!.otp}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 2),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (isSearching) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        backgroundColor: AppColors.bgGreen,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _cancelRide,
                        child: const Text('Cancel Ride',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 16,
              child: SosButton(
                lat: _ride?.pickupLat,
                lng: _ride?.pickupLng,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
