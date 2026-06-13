import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../utils/date_formatter.dart';

class SaathiHistoryScreen extends StatefulWidget {
  const SaathiHistoryScreen({super.key});

  @override
  State<SaathiHistoryScreen> createState() => _SaathiHistoryScreenState();
}

class _SaathiHistoryScreenState extends State<SaathiHistoryScreen> {
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
    final docs = await RideService.getSaathiHistory(uid);
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
        title: const Text('My Rides',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _rides.isEmpty
              ? const Center(
                  child: Text('No rides yet', style: TextStyle(color: AppColors.textGrey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _rides[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${r.pickupVillage} → ${r.destinationVillage}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormatter.format(r.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textGrey),
                                ),
                                Text(r.customerName,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textGrey)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${r.fare.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryGreen,
                                      fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: r.status == RideModel.completed
                                      ? AppColors.bgGreen
                                      : AppColors.bgOrange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: r.status == RideModel.completed
                                        ? AppColors.primaryGreen
                                        : AppColors.primaryOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
