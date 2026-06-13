import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../../services/haul_service.dart';
import '../../widgets/sos_button.dart';
import 'haul_complete_screen.dart';

class HaulTrackingScreen extends StatefulWidget {
  final String bookingId;

  const HaulTrackingScreen({super.key, required this.bookingId});

  @override
  State<HaulTrackingScreen> createState() => _HaulTrackingScreenState();
}

class _HaulTrackingScreenState extends State<HaulTrackingScreen> {
  StreamSubscription? _sub;
  HaulBookingModel? _booking;

  @override
  void initState() {
    super.initState();
    _sub = HaulService.watchBooking(widget.bookingId).listen((snap) {
      if (snap.exists && mounted) {
        final booking = HaulBookingModel.fromFirestore(snap);
        setState(() => _booking = booking);
        if (booking.status == HaulBookingModel.completed) {
          _sub?.cancel();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => HaulCompleteScreen(booking: booking)),
            (route) => route.isFirst,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _statusText {
    switch (_booking?.status) {
      case HaulBookingModel.searching: return '🔍 ઓનર શોધી રહ્યા છીએ...';
      case HaulBookingModel.accepted: return '✅ Owner coming to you';
      case HaulBookingModel.started: return '🚛 Haul in progress';
      default: return 'Booking Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('GaamHaul Tracking'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.local_shipping, size: 60, color: AppColors.primaryOrange),
                      const SizedBox(height: 12),
                      Text(
                        _statusText,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (_booking?.status == HaulBookingModel.searching)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LinearProgressIndicator(
                            color: AppColors.primaryOrange,
                            backgroundColor: AppColors.bgOrange,
                          ),
                        ),
                      if (_booking?.ownerName.isNotEmpty == true) ...[
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.person, color: AppColors.primaryOrange),
                            const SizedBox(width: 8),
                            Text(_booking!.ownerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: SosButton(lat: _booking?.pickupLat, lng: _booking?.pickupLng),
          ),
        ],
      ),
    );
  }
}
