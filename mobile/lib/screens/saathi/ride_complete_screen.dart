import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';

/// Saathi's ride complete screen — shown after confirming payment.
class SaathiRideCompleteScreen extends StatefulWidget {
  final double fare;
  final String customerName;
  final String paymentMethod; // RideModel.paymentCash or paymentUpiDirect

  const SaathiRideCompleteScreen({
    super.key,
    required this.fare,
    required this.customerName,
    required this.paymentMethod,
  });

  @override
  State<SaathiRideCompleteScreen> createState() =>
      _SaathiRideCompleteScreenState();
}

class _SaathiRideCompleteScreenState extends State<SaathiRideCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    Timer(const Duration(milliseconds: 150), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isUpi =>
      widget.paymentMethod == RideModel.paymentUpiDirect ||
      widget.paymentMethod == 'upi';

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, bottomPad + 24),
          child: Column(
            children: [
              const Spacer(),

              // Animated check
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF16A34A).withAlpha(60),
                            blurRadius: 24,
                            spreadRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 80, color: Color(0xFF16A34A)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text('Ride complete!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),

              const SizedBox(height: 10),

              Text(
                'You earned',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
              Text(
                '₹${widget.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    letterSpacing: -2),
              ),

              const SizedBox(height: 16),

              // Payment method pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isUpi
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isUpi
                          ? Icons.qr_code_2_rounded
                          : Icons.payments_rounded,
                      size: 16,
                      color: _isUpi
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Paid via: ${_isUpi ? 'UPI' : 'Cash'}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _isUpi
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFF166534)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'From: ${widget.customerName}',
                style: TextStyle(
                    fontSize: 14, color: Colors.grey[500]),
              ),

              const Spacer(),

              // Go online button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                    shadowColor: AppColors.primaryGreen.withAlpha(80),
                  ),
                  icon: const Icon(Icons.electric_rickshaw_rounded, size: 22),
                  label: const Text('Go online for next ride',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
