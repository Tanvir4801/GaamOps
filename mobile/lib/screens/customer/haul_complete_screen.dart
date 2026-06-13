import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../customer/customer_main_shell.dart';

class HaulCompleteScreen extends StatelessWidget {
  final HaulBookingModel booking;

  const HaulCompleteScreen({super.key, required this.booking});

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
                  color: AppColors.bgOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.primaryOrange, size: 48),
              ),
              const SizedBox(height: 20),
              const Text('Haul Complete!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(booking.vehicleTypeLabel,
                  style: const TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Owner Paid',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '₹${booking.ownerEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerMainShell()),
                  (_) => false,
                ),
                child: const Text('Back to Home',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
