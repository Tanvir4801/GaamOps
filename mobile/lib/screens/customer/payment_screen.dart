import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/payment_service.dart';
import '../../services/ride_service.dart';
import 'ride_complete_screen.dart';

/// Real payment screen shown once a ride's status becomes `completed`
/// (only if it hasn't been paid yet). Online methods go through a genuine
/// Razorpay checkout — no fake "processing" spinners that do nothing. Cash
/// is honest: no gateway, just an honour-system confirmation.
class PaymentScreen extends StatefulWidget {
  final RideModel ride;

  const PaymentScreen({super.key, required this.ride});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late String _selectedMethod;
  bool _isProcessing = false;

  static const _onlineMethods = {'gpay', 'phonepe', 'paytm', 'upi'};

  @override
  void initState() {
    super.initState();
    // Pre-select whatever the rider chose at booking time; default to cash.
    final preferred = widget.ride.paymentMethod;
    _selectedMethod = preferred.isNotEmpty ? preferred : 'cash';
  }

  @override
  void dispose() {
    PaymentService.dispose();
    super.dispose();
  }

  bool get _isOnline => _onlineMethods.contains(_selectedMethod);

  String get _methodLabel => const {
        'gpay': 'Google Pay',
        'phonepe': 'PhonePe',
        'paytm': 'Paytm',
        'upi': 'UPI',
        'cash': 'Cash',
      }[_selectedMethod]!;

  Future<void> _processPayment() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    if (_selectedMethod == 'cash') {
      await _saveCashPayment();
      return;
    }

    PaymentService.init(
      onSuccess: (paymentId) => _saveOnlinePayment(paymentId),
      onFailure: (error) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _showSnack('Payment failed: $error', AppColors.error);
      },
    );

    PaymentService.openCheckout(
      amountInRupees: widget.ride.fare,
      rideId: widget.ride.rideId,
      customerName: widget.ride.customerName,
      customerPhone: widget.ride.customerPhone,
      method: _selectedMethod,
    );
  }

  Future<void> _saveOnlinePayment(String paymentId) async {
    try {
      await RideService.updatePayment(
        rideId: widget.ride.rideId,
        method: _selectedMethod,
        status: RideModel.paymentPaid,
        paymentId: paymentId,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSuccessAndNavigate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('Could not save payment: $e', AppColors.error);
    }
  }

  Future<void> _saveCashPayment() async {
    try {
      await RideService.updatePayment(
        rideId: widget.ride.rideId,
        method: 'cash',
        status: RideModel.paymentPaid,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSuccessAndNavigate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('Could not save payment: $e', AppColors.error);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccessAndNavigate() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 60),
            const SizedBox(height: 12),
            const Text('Payment done!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('₹${widget.ride.fare.toStringAsFixed(0)} paid via $_methodLabel',
                style: const TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // close dialog
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => RideCompleteScreen(ride: widget.ride),
                  ));
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    // Payment is mandatory once a ride is completed — block back navigation
    // (system gesture/button) so it can't be skipped, leaving the ride
    // stuck in an unpaid state.
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(ride: ride),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: _FareCard(ride: ride),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('ONLINE PAYMENT',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textGrey)),
                  ),
                  _MethodTile(
                    selected: _selectedMethod == 'gpay',
                    onTap: () => setState(() => _selectedMethod = 'gpay'),
                    title: 'Google Pay',
                    subtitle: 'Pay via GPay UPI',
                    badge: 'POPULAR',
                    leading: _brandIcon('G Pay', Colors.white,
                        border: true, textColor: const Color(0xFF4285F4)),
                  ),
                  _MethodTile(
                    selected: _selectedMethod == 'phonepe',
                    onTap: () => setState(() => _selectedMethod = 'phonepe'),
                    title: 'PhonePe',
                    subtitle: 'Pay via PhonePe UPI',
                    leading: _brandIcon('Pe', const Color(0xFF5F259F), textColor: Colors.white),
                  ),
                  _MethodTile(
                    selected: _selectedMethod == 'paytm',
                    onTap: () => setState(() => _selectedMethod = 'paytm'),
                    title: 'Paytm',
                    subtitle: 'Paytm wallet or UPI',
                    leading: _brandIcon('Pay', const Color(0xFF002970), textColor: const Color(0xFF00BAF2)),
                  ),
                  _MethodTile(
                    selected: _selectedMethod == 'upi',
                    onTap: () => setState(() => _selectedMethod = 'upi'),
                    title: 'Any UPI app',
                    subtitle: 'Choose from installed UPI apps',
                    leading: _brandIcon('UPI', Colors.grey.shade200, textColor: AppColors.primaryGreen),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 24),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text('OFFLINE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textGrey)),
                  ),
                  _MethodTile(
                    selected: _selectedMethod == 'cash',
                    onTap: () => setState(() => _selectedMethod = 'cash'),
                    title: 'Cash',
                    subtitle: 'Pay saathi directly after ride',
                    leading: _brandIcon('💵', AppColors.bgGreen, emoji: true),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          _BottomBar(
            isOnline: _isOnline,
            isProcessing: _isProcessing,
            fare: ride.fare,
            methodLabel: _methodLabel,
            onPressed: _processPayment,
          ),
        ],
      ),
      ),
    );
  }

  Widget _brandIcon(String text, Color bg,
      {Color textColor = Colors.black, bool border = false, bool emoji = false}) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: emoji ? 16 : (text.length > 2 ? 10 : 13),
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RideModel ride;
  const _Header({required this.ride});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 36),
      decoration: const BoxDecoration(color: AppColors.primaryOrange),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No back button — payment is mandatory once a ride is completed,
          // so there's nowhere honest to go "back" to. See PopScope above.
          const Icon(Icons.lock_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose payment',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${ride.pickupVillage} → ${ride.destinationVillage} · ${ride.distance.toStringAsFixed(1)}km',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FareCard extends StatelessWidget {
  final RideModel ride;
  const _FareCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total fare',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                Text('₹${ride.fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${ride.distance.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Base ₹${ride.baseFare.toStringAsFixed(0)} + distance',
                  style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget leading;
  final String? badge;

  const _MethodTile({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.leading,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFFF7ED) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryOrange.withOpacity(0.1),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(badge!,
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textGrey)),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected
                          ? AppColors.primaryOrange
                          : Colors.grey.shade400,
                      width: 2),
                  color: Colors.transparent,
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryOrange),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isOnline;
  final bool isProcessing;
  final double fare;
  final String methodLabel;
  final VoidCallback onPressed;

  const _BottomBar({
    required this.isOnline,
    required this.isProcessing,
    required this.fare,
    required this.methodLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isOnline ? AppColors.primaryOrange : AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor:
                    (isOnline ? AppColors.primaryOrange : AppColors.primaryGreen)
                        .withOpacity(0.6),
              ),
              onPressed: isProcessing ? null : onPressed,
              child: isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.4),
                    )
                  : Text(
                      isOnline
                          ? 'Pay ₹${fare.toStringAsFixed(0)} with $methodLabel'
                          : 'Confirm cash payment',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOnline
                ? '🔒 Secured by Razorpay'
                : 'No app charges. Pay directly to saathi.',
            style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
