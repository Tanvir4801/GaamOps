// payment_screen.dart — legacy Razorpay screen removed.
// Payment is now confirmed by the saathi (cash or UPI direct).
// Customer sees RideSummaryScreen once saathi confirms.
// This file is kept as a stub to avoid breaking any lingering references.

import 'package:flutter/material.dart';
import '../../models/ride_model.dart';

/// Stub — never shown in the new payment flow.
/// Navigation: ride_tracking_screen → RideSummaryScreen (on paymentConfirmedBySaathi).
class PaymentScreen extends StatelessWidget {
  final RideModel ride;
  const PaymentScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
