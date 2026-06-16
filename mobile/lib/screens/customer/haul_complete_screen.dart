import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../customer/customer_main_shell.dart';

class HaulCompleteScreen extends StatelessWidget {
  final HaulBookingModel booking;

  const HaulCompleteScreen({super.key, required this.booking});

  String _duration(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes % 60;
      return m > 0
          ? '${d.inHours}h ${m}m'
          : '${d.inHours}h';
    }
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final actualDuration = b.startedAt != null && b.completedAt != null
        ? b.completedAt!.difference(b.startedAt!)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Success icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE65100), Color(0xFFF57C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primaryOrange.withAlpha(80),
                        blurRadius: 20,
                        spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),

              const SizedBox(height: 20),
              const Text('Job Complete! 🎉',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                '${b.vehicleEmoji} ${b.vehicleTypeLabel}',
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textGrey),
              ),

              const SizedBox(height: 28),

              // Receipt card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(10), blurRadius: 12)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rental Summary',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textGrey)),
                    const SizedBox(height: 16),

                    _row('Owner', b.ownerName),
                    _divider(),
                    _row('Vehicle', b.vehicleTypeLabel),
                    if (b.vehicleNumber.isNotEmpty) ...[
                      _divider(),
                      _row('Vehicle No.', b.vehicleNumber),
                    ],
                    _divider(),
                    _row('Location', b.pickupVillage),
                    _divider(),
                    _row('Load', b.loadDescription.isNotEmpty
                        ? b.loadDescription : '—'),
                    _divider(),
                    _row('Booked Duration', b.durationLabel),
                    if (actualDuration != null) ...[
                      _divider(),
                      _row('Actual Duration', _duration(actualDuration)),
                    ],
                    if (b.ratePerHour > 0) ...[
                      _divider(),
                      _row('Rate',
                          '₹${b.ratePerHour.toStringAsFixed(0)} / hour'),
                    ],
                    _divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Paid',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(
                          '₹${b.ownerEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Rate the experience prompt (info only)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Text('⭐⭐⭐⭐⭐',
                      style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hope ${b.ownerName} served you well!',
                      style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CustomerMainShell()),
                    (_) => false,
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textGrey, fontSize: 13)),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  textAlign: TextAlign.end),
            ),
          ],
        ),
      );

  Widget _divider() => const Divider(height: 16, thickness: 0.5);
}

