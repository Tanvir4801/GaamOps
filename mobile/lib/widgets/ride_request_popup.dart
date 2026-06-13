import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/ride_model.dart';
import 'gujarati_text.dart';

class RideRequestPopup extends StatefulWidget {
  final RideModel ride;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const RideRequestPopup({
    super.key,
    required this.ride,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<RideRequestPopup> createState() => _RideRequestPopupState();
}

class _RideRequestPopupState extends State<RideRequestPopup> {
  late int _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  widget.ride.customerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _seconds <= 10 ? AppColors.error : AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_seconds',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.lightGreen),
                const SizedBox(width: 6),
                Text(widget.ride.pickupVillage,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.primaryOrange),
                const SizedBox(width: 6),
                Text(widget.ride.destinationVillage,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(
                  '₹${widget.ride.fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Skip',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen),
                    child: const GujaratiText(
                      gujarati: 'સ્વીકાર',
                      english: 'Accept',
                      gujaratiSize: 14,
                      englishSize: 10,
                      color: Colors.white,
                      alignment: CrossAxisAlignment.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
