import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../services/ride_service.dart';
import '../../widgets/earnings_card.dart';

class SaathiEarningsScreen extends StatefulWidget {
  const SaathiEarningsScreen({super.key});

  @override
  State<SaathiEarningsScreen> createState() => _SaathiEarningsScreenState();
}

class _SaathiEarningsScreenState extends State<SaathiEarningsScreen> {
  Map<String, dynamic> _earnings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final earnings = await RideService.getSaathiEarnings(uid);
    if (mounted) {
      setState(() {
        _earnings = earnings;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Earnings',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: EarningsCard(
                          label: "Today",
                          amount: (_earnings['today'] ?? 0).toDouble(),
                          rides: (_earnings['todayRides'] ?? 0).toInt(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EarningsCard(
                          label: 'This Week',
                          amount: (_earnings['week'] ?? 0).toDouble(),
                          color: AppColors.lightGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  EarningsCard(
                    label: 'This Month',
                    amount: (_earnings['month'] ?? 0).toDouble(),
                    rides: (_earnings['totalRides'] ?? 0).toInt(),
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Info',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const _PayRow('App Commission', '0% (no cut for now)'),
                        const _PayRow('You Keep', '100% of fare'),
                        const _PayRow('Payment Mode', 'Cash from customer'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;

  const _PayRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
