import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../utils/date_formatter.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<RideModel> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final docs = await RideService.getCustomerHistory(uid);
    if (mounted) {
      setState(() {
        _rides = docs.map((d) => RideModel.fromFirestore(d)).toList();
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
        title: const Text('Ride History',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _rides.isEmpty
              ? const Center(child: Text('No rides yet', style: TextStyle(color: AppColors.textGrey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _rides[i];
                    final isCompleted = r.status == RideModel.completed;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isCompleted ? AppColors.bgGreen : AppColors.bgOrange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted ? AppColors.primaryGreen : AppColors.primaryOrange,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '₹${r.fare.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${r.pickupVillage} → ${r.destinationVillage}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormatter.format(r.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
                          ),
                          if (r.saathiName.isNotEmpty)
                            Text(
                              'Saathi: ${r.saathiName}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                            ),
                          if (r.rating > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(
                                r.rating,
                                (_) => const Icon(Icons.star, size: 14, color: AppColors.warning),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
