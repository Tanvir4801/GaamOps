import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import 'rating_screen.dart';

/// Shown to the customer when saathi confirms payment.
/// Replaces the tracking screen — triggered by paymentConfirmedBySaathi == true.
class RideSummaryScreen extends StatefulWidget {
  final RideModel ride;
  const RideSummaryScreen({super.key, required this.ride});

  @override
  State<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends State<RideSummaryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkFade;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _checkCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    Timer(const Duration(milliseconds: 200), () {
      if (mounted) _checkCtrl.forward();
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  String get _payMethodLabel {
    final m = widget.ride.paymentMethod;
    if (m == RideModel.paymentUpiDirect || m == 'upi') return 'UPI';
    return 'Cash';
  }

  IconData get _payMethodIcon {
    final m = widget.ride.paymentMethod;
    if (m == RideModel.paymentUpiDirect || m == 'upi') {
      return Icons.qr_code_2_rounded;
    }
    return Icons.payments_rounded;
  }

  String get _durationText {
    final start = widget.ride.startedAt;
    final end = widget.ride.completedAt;
    if (start == null || end == null) return '—';
    final mins = end.difference(start).inMinutes;
    if (mins < 1) return 'Less than 1 min';
    return '$mins min${mins == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: topPad + 24),

              // ── Animated check ──
              FadeTransition(
                opacity: _checkFade,
                child: ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF16A34A).withAlpha(50),
                            blurRadius: 20,
                            spreadRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 72, color: Color(0xFF16A34A)),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Text('Ride complete!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text(
                'Payment confirmed by ${ride.saathiName.isNotEmpty ? ride.saathiName : 'saathi'}',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textGrey),
              ),

              const SizedBox(height: 28),

              // ── Summary card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Route
                    Row(children: [
                      const Icon(Icons.circle, size: 10,
                          color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(ride.pickupVillage,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14))),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
                      child: Container(width: 2, height: 16, color: Colors.grey[300]),
                    ),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppColors.primaryOrange),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(ride.destinationVillage,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14))),
                    ]),

                    const Divider(height: 28),

                    // Fare
                    _SummaryRow(
                      icon: Icons.currency_rupee_rounded,
                      iconColor: AppColors.primaryOrange,
                      label: 'Fare',
                      value: '₹${ride.fare.toStringAsFixed(0)}',
                      valueStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange),
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      icon: _payMethodIcon,
                      iconColor: const Color(0xFF1D4ED8),
                      label: 'Paid via',
                      value: _payMethodLabel,
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      icon: Icons.straighten_rounded,
                      iconColor: AppColors.textGrey,
                      label: 'Distance',
                      value: '${ride.distance.toStringAsFixed(1)} km',
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      icon: Icons.timer_outlined,
                      iconColor: AppColors.textGrey,
                      label: 'Duration',
                      value: _durationText,
                    ),
                    if (ride.saathiName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SummaryRow(
                        icon: Icons.person_rounded,
                        iconColor: AppColors.primaryGreen,
                        label: 'Saathi',
                        value: ride.saathiName,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Rate button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.star_rounded, size: 20),
                  label: const Text('Rate your saathi',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RatingScreen(
                        rideId: ride.rideId,
                        saathiId: ride.saathiId,
                        saathiName: ride.saathiName,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('Back to home',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textGrey)),
        ),
        Text(value,
            style: valueStyle ??
                const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
      ],
    );
  }
}
