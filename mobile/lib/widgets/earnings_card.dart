import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EarningsCard extends StatelessWidget {
  final String label;
  final double amount;
  final int? rides;
  final Color color;

  const EarningsCard({
    super.key,
    required this.label,
    required this.amount,
    this.rides,
    this.color = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (rides != null)
            Text(
              '$rides rides',
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
            ),
        ],
      ),
    );
  }
}
