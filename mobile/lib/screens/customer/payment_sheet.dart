import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/fare_breakdown.dart';

enum PaymentMethod { cash, upi }

class PaymentSheet extends StatefulWidget {
  final FareBreakdown breakdown;
  final Function(PaymentMethod method) onConfirm;

  const PaymentSheet({
    super.key,
    required this.breakdown,
    required this.onConfirm,
  });

  static Future<PaymentMethod?> show(
    BuildContext context,
    FareBreakdown breakdown,
    Function(PaymentMethod) onConfirm,
  ) {
    return showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(breakdown: breakdown, onConfirm: onConfirm),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet>
    with SingleTickerProviderStateMixin {
  PaymentMethod _selected = PaymentMethod.cash;
  bool _upiLaunched = false;
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _launchUpi() async {
    final amount = widget.breakdown.totalFare.toStringAsFixed(2);
    final upiId = widget.breakdown.gaamRideUpi;
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': 'GaamRide',
        'am': amount,
        'tn': 'GaamRide Fare Payment',
        'cu': 'INR',
        'mode': '02',
      },
    );
    final uriStr = 'upi://pay?pa=$upiId&pn=GaamRide&am=$amount&tn=GaamRide+Fare&cu=INR';
    try {
      final canLaunch = await canLaunchUrl(Uri.parse(uriStr));
      if (canLaunch) {
        await launchUrl(Uri.parse(uriStr));
        setState(() => _upiLaunched = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No UPI app found. Please install GPay, PhonePe, or Paytm'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _upiLaunched = true);
    }
  }

  void _copyUpiId() {
    Clipboard.setData(ClipboardData(text: widget.breakdown.gaamRideUpi));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI ID copied!'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.breakdown.totalFare;
    final upiId = widget.breakdown.gaamRideUpi;
    final pad = MediaQuery.of(context).padding.bottom;

    return SlideTransition(
      position: _slide,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 8, 20, pad + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text(
              'Choose Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MethodTile(
                    icon: '💵',
                    label: 'Cash',
                    subtitle: 'Pay Saathi directly',
                    selected: _selected == PaymentMethod.cash,
                    onTap: () => setState(() {
                      _selected = PaymentMethod.cash;
                      _upiLaunched = false;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MethodTile(
                    icon: '📱',
                    label: 'UPI',
                    subtitle: 'GPay, PhonePe, Paytm',
                    selected: _selected == PaymentMethod.upi,
                    onTap: () => setState(() => _selected = PaymentMethod.upi),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selected == PaymentMethod.cash
                  ? _CashInfo(key: const ValueKey('cash'))
                  : _UpiInfo(
                      key: const ValueKey('upi'),
                      upiId: upiId,
                      amount: amount,
                      launched: _upiLaunched,
                      onLaunch: _launchUpi,
                      onCopy: _copyUpiId,
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                onPressed: () {
                  Navigator.pop(context, _selected);
                  widget.onConfirm(_selected);
                },
                child: Text(
                  _selected == PaymentMethod.cash
                      ? 'Confirm · Pay Cash to Saathi'
                      : _upiLaunched
                          ? 'Payment Done · Confirm Ride'
                          : 'Confirm Ride',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.bgGreen : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : Colors.grey[200]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.textDark)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textGrey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CashInfo extends StatelessWidget {
  const _CashInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withAlpha(40)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pay the exact fare amount to your Saathi at the end of your ride. No change required.',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpiInfo extends StatelessWidget {
  final String upiId;
  final double amount;
  final bool launched;
  final VoidCallback onLaunch;
  final VoidCallback onCopy;

  const _UpiInfo({
    super.key,
    required this.upiId,
    required this.amount,
    required this.launched,
    required this.onLaunch,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withAlpha(40)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: Colors.purple, size: 18),
              SizedBox(width: 8),
              Text('Pay via UPI',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.purple)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.withAlpha(30)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('UPI ID',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textGrey)),
                      Text(upiId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Colors.purple)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onCopy,
                  child: const Icon(Icons.copy_rounded,
                      color: Colors.purple, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _AppButton(
                  label: 'GPay',
                  emoji: '🟢',
                  onTap: onLaunch,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AppButton(
                  label: 'PhonePe',
                  emoji: '🟣',
                  onTap: onLaunch,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AppButton(
                  label: 'Paytm',
                  emoji: '🔵',
                  onTap: onLaunch,
                ),
              ),
            ],
          ),
          if (launched) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 16),
                  SizedBox(width: 8),
                  Text('Payment done? Tap Confirm below',
                      style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppButton extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback onTap;

  const _AppButton({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withAlpha(30)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGrey)),
          ],
        ),
      ),
    );
  }
}
