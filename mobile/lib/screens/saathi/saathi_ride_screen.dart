import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../widgets/sos_button.dart';

class SaathiRideScreen extends StatefulWidget {
  final RideModel ride;
  final VoidCallback onComplete;

  const SaathiRideScreen({
    super.key,
    required this.ride,
    required this.onComplete,
  });

  @override
  State<SaathiRideScreen> createState() => _SaathiRideScreenState();
}

class _SaathiRideScreenState extends State<SaathiRideScreen> {
  StreamSubscription? _sub;
  RideModel? _ride;
  GoogleMapController? _mapController;
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _sub = RideService.watchRide(widget.ride.rideId).listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _ride = RideModel.fromFirestore(snap));
      }
    });
  }

  Future<void> _arrived() async {
    await RideService.saathiArrived(widget.ride.rideId);
  }

  Future<void> _startRide() async {
    final otp = _otpController.text.trim();
    if (otp != _ride?.otp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong OTP!'), backgroundColor: AppColors.error),
      );
      return;
    }
    await RideService.startRide(widget.ride.rideId);
  }

  Future<void> _completeRide() async {
    await RideService.completeRide(widget.ride.rideId);
    widget.onComplete();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this ride?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await RideService.cancelRide(widget.ride.rideId, 'Cancelled by saathi');
      widget.onComplete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _otpController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ride = _ride ?? widget.ride;
    final isAccepted = ride.status == RideModel.accepted;
    final isArriving = ride.status == RideModel.arriving;
    final isStarted = ride.status == RideModel.started;

    return Scaffold(
      body: Stack(
        children: [
          if (ride.pickupLat != 0)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(ride.pickupLat, ride.pickupLng),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: LatLng(ride.pickupLat, ride.pickupLng),
                  infoWindow: InfoWindow(title: '📍 ${ride.pickupVillage}'),
                ),
                Marker(
                  markerId: const MarkerId('dest'),
                  position: LatLng(ride.destinationLat, ride.destinationLng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                  infoWindow: InfoWindow(title: '🏁 ${ride.destinationVillage}'),
                ),
              },
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ride.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${ride.pickupVillage} → ${ride.destinationVillage}',
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('₹${ride.fare.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isAccepted) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _arrived,
                        child: const Text('I Have Arrived / પહોંચ્યો',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (isArriving) ...[
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'Enter OTP from Customer',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        counterText: '',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _startRide,
                        child: const Text('Start Ride / ચાલુ',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (isStarted) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _completeRide,
                        child: const Text('Complete Ride / પૂર્ણ',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cancelRide,
                    child: const Text('Cancel Ride',
                        style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 16,
            child: SosButton(lat: ride.pickupLat, lng: ride.pickupLng),
          ),
        ],
      ),
    );
  }
}
