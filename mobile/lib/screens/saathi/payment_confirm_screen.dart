import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import 'ride_complete_screen.dart';
import 'upi_qr_screen.dart';
import 'upi_setup_screen.dart';

/// Shown to saathi after completing a ride.
/// Saathi either confirms cash receipt or shows UPI QR for the customer.
class PaymentConfirmScreen extends StatefulWidget {
  final String rideId;
  final double fare;
  final String customerName;
  final String paymentMethod; // RideModel.paymentCash or paymentUpiDirect

  const PaymentConfirmScreen({
    super.key,
    required this.rideId,
    required this.fare,
    required this.customerName,
    required this.paymentMethod,
  });

  @override
  State<PaymentConfirmScreen> createState() => _PaymentConfirmScreenState();
}

class _PaymentConfirmScreenState extends State<PaymentConfirmScreen> {
  bool _isConfirming = false;
  bool _switchedToCash = false;
  String? _upiId;
  String? _upiName;
  bool _upiLoading = true;

  bool get _showCash =>
      widget.paymentMethod == RideModel.paymentCash || _switchedToCash;

  @override
  void initState() {
    super.initState();
    _loadSaathiUpi();
  }

  Future<void> _loadSaathiUpi() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _upiLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('saathis')
          .doc(uid)
          .get();
      if (mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _upiId = data['upiId'] as String? ?? '';
          _upiName = (data['upiName'] as String? ?? data['name'] as String?) ?? '';
          _upiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _upiLoading = false);
    }
  }

  Future<void> _confirmPayment() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await RideService.confirmPayment(
        rideId: widget.rideId,
        saathiId: uid,
        fare: widget.fare,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SaathiRideCompleteScreen(
            fare: widget.fare,
            customerName: widget.customerName,
            paymentMethod: _showCash ? RideModel.paymentCash : RideModel.paymentUpiDirect,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false, // prevent accidental back before confirming
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _upiLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryGreen))
              : _showCash
                  ? _buildCash(context, bottomPad)
                  : _buildUpi(context, bottomPad),
        ),
      ),
    );
  }

  Widget _buildCash(BuildContext context, double bottomPad) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, bottomPad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF16A34A).withAlpha(40),
                      blurRadius: 18,
                      spreadRadius: 3),
                ],
              ),
              child: const Icon(Icons.payments_rounded,
                  size: 44, color: Color(0xFF16A34A)),
            ),

            const SizedBox(height: 20),
            const Text('Collect payment',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),

            // Fare
            Text(
              '₹${widget.fare.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryOrange,
                  letterSpacing: -1),
            ),

            Text(
              '${widget.customerName} will pay you cash',
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textGrey),
            ),

            const SizedBox(height: 24),

            // Instruction card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF16A34A).withAlpha(60)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ask ${widget.customerName} for ₹${widget.fare.toStringAsFixed(0)} in cash before they leave',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 4,
                  shadowColor: const Color(0xFF16A34A).withAlpha(80),
                ),
                icon: _isConfirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: const Text('Cash received ✓',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                onPressed: _isConfirming ? null : _confirmPayment,
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              'Don\'t tap until you have the cash in hand',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpi(BuildContext context, double bottomPad) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 28, 20, bottomPad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Show your QR code',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(
              'Ask ${widget.customerName} to scan and pay ₹${widget.fare.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // QR widget
            UpiQrScreen(
              upiId: _upiId ?? '',
              upiName: _upiName ?? '',
              fare: widget.fare,
            ),

            if ((_upiId ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Color(0xFF1D4ED8), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customer will pay directly to your UPI account',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                    shadowColor: const Color(0xFF1D4ED8).withAlpha(80),
                  ),
                  icon: _isConfirming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.check_circle_rounded, size: 22),
                  label: const Text('Payment received ✓',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  onPressed: _isConfirming ? null : _confirmPayment,
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () => setState(() => _switchedToCash = true),
                child: const Text(
                  'Customer wants to pay cash instead',
                  style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              // Setup UPI prompt
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Set up UPI',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UpiSetupScreen(
                              saathiName: _upiName ?? ''))).then((_) => _loadSaathiUpi()),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _switchedToCash = true),
                child: const Text(
                  'Accept cash instead',
                  style: TextStyle(
                      color: AppColors.textGrey, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
