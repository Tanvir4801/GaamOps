import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../widgets/rating_widget.dart';
import '../customer/customer_main_shell.dart';

class RideCompleteScreen extends StatefulWidget {
  final RideModel ride;

  const RideCompleteScreen({super.key, required this.ride});

  @override
  State<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends State<RideCompleteScreen> {
  int _rating = 0;
  bool _submitted = false;

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    await RideService.rateRide(
      rideId: widget.ride.rideId,
      saathiId: widget.ride.saathiId,
      rating: _rating,
      totalRides: 0,
      currentRating: 5.0,
    );
    setState(() => _submitted = true);
  }

  void _done() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CustomerMainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.bgGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.primaryGreen, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ride Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.ride.pickupVillage} → ${widget.ride.destinationVillage}',
                style: const TextStyle(color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Fare',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '₹${widget.ride.fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (!_submitted) ...[
                Text(
                  'Rate your Saathi · ${widget.ride.saathiName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 14),
                RatingWidget(
                  onRatingChanged: (r) => setState(() => _rating = r),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _rating > 0 ? _submitRating : null,
                  child: const Text('Submit Rating',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                const Icon(Icons.star, color: AppColors.warning, size: 40),
                const Text('Thanks for rating!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: _done,
                child: const Text('Back to Home',
                    style: TextStyle(color: AppColors.primaryGreen)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
