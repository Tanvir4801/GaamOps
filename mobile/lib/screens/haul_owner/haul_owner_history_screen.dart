import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_booking_model.dart';
import '../../services/haul_service.dart';

class HaulOwnerHistoryScreen extends StatefulWidget {
  const HaulOwnerHistoryScreen({super.key});

  @override
  State<HaulOwnerHistoryScreen> createState() => _HaulOwnerHistoryScreenState();
}

class _HaulOwnerHistoryScreenState extends State<HaulOwnerHistoryScreen> {
  List<HaulBookingModel> _bookings = [];
  bool _loading = true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_uid == null) return;
    try {
      final docs = await HaulService.getOwnerHistory(_uid!);
      if (mounted) {
        setState(() {
          _bookings = docs
              .map((d) => HaulBookingModel.fromFirestore(d))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Job History',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : _bookings.isEmpty
              ? const Center(
                  child: Text('No completed jobs yet',
                      style: TextStyle(color: AppColors.textGrey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  itemBuilder: (_, i) {
                    final b = _bookings[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(8), blurRadius: 8)
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(b.vehicleEmoji,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.vehicleTypeLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  Text(b.customerName,
                                      style: const TextStyle(
                                          color: AppColors.textGrey,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: b.status == HaulBookingModel.completed
                                    ? AppColors.bgOrange
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                b.status == HaulBookingModel.completed
                                    ? '✓ Done'
                                    : b.status,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        b.status == HaulBookingModel.completed
                                            ? AppColors.primaryOrange
                                            : Colors.red),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${b.durationLabel} · ${b.pickupVillage}',
                                  style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12)),
                              Text('₹${b.ownerEarnings.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.primaryOrange)),
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
