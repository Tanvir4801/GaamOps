import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/fare_breakdown.dart';
import '../../models/ride_model.dart';

// Returned from PaymentChoiceSheet.show()
// Matches RideModel.paymentCash or RideModel.paymentUpiDirect
typedef PaymentMethodString = String;

class PaymentChoiceSheet extends StatefulWidget {
  final FareBreakdown breakdown;
  final void Function(String method) onConfirm;

  const PaymentChoiceSheet({
    super.key,
    required this.breakdown,
    required this.onConfirm,
  });

  static Future<String?> show(
    BuildContext context,
    FareBreakdown breakdown,
    void Function(String) onConfirm,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentChoiceSheet(breakdown: breakdown, onConfirm: onConfirm),
    );
  }

  @override
  State<PaymentChoiceSheet> createState() => _PaymentChoiceSheetState();
}

class _PaymentChoiceSheetState extends State<PaymentChoiceSheet>
    with SingleTickerProviderStateMixin {
  String? _selected;
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selected == null) return;
    widget.onConfirm(_selected!);
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.breakdown.totalFare;
    final pad = MediaQuery.of(context).padding.bottom;

    return SlideTransition(
      position: _slide,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, pad + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),

            const Text(
              'How will you pay?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Let your saathi know so they\'re prepared',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Cash card
            _PayCard(
              selected: _selected == RideModel.paymentCash,
              onTap: () => setState(() => _selected = RideModel.paymentCash),
              icon: Icons.payments_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconColor: const Color(0xFF16A34A),
              title: 'Cash',
              subtitle: 'Pay ₹${fare.toStringAsFixed(0)} directly to saathi after ride',
              badgeLabel: 'Most common',
              badgeColor: const Color(0xFF16A34A),
            ),

            const SizedBox(height: 12),

            // UPI card
            _PayCard(
              selected: _selected == RideModel.paymentUpiDirect,
              onTap: () => setState(() => _selected = RideModel.paymentUpiDirect),
              icon: Icons.qr_code_2_rounded,
              iconBg: const Color(0xFFDBEAFE),
              iconColor: const Color(0xFF1D4ED8),
              title: 'Online / UPI',
              subtitle: 'Scan saathi\'s QR with GPay, PhonePe, or Paytm',
              badgeLabel: 'No cash needed',
              badgeColor: const Color(0xFF1D4ED8),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selected == null
                      ? Colors.grey[300]
                      : const Color(0xFFf97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: _selected == null ? 0 : 3,
                ),
                onPressed: _selected == null ? null : _confirm,
                child: Text(
                  _selected == null
                      ? 'Select a payment method'
                      : 'Confirm booking',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;

  const _PayCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFf97316) : Colors.grey.shade200,
            width: selected ? 2 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(selected ? 10 : 5),
                blurRadius: selected ? 10 : 4),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: badgeColor.withAlpha(60), width: 1),
                        ),
                        child: Text(badgeLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected
                        ? const Color(0xFFf97316)
                        : Colors.grey.shade300,
                    width: 2),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 11, height: 11,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFf97316)),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
