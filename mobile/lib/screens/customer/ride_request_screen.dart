import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/village_model.dart';
import '../../models/saathi_model.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../../services/village_service.dart';
import 'ride_tracking_screen.dart';

class RideRequestScreen extends StatefulWidget {
  final VillageModel pickupVillage;
  final VillageModel destinationVillage;
  final SaathiModel saathi;
  final double fare;

  const RideRequestScreen({
    super.key,
    required this.pickupVillage,
    required this.destinationVillage,
    required this.saathi,
    required this.fare,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await AuthService.getUser(uid);

    final dist = VillageService.distanceBetween(
      widget.pickupVillage,
      widget.destinationVillage,
    );

    final rideId = await RideService.createRide(
      customerId: uid,
      customerName: user?.name ?? '',
      customerPhone: user?.phone ?? '',
      pickupVillage: widget.pickupVillage.name,
      pickupLat: widget.pickupVillage.lat,
      pickupLng: widget.pickupVillage.lng,
      destinationVillage: widget.destinationVillage.name,
      destinationLat: widget.destinationVillage.lat,
      destinationLng: widget.destinationVillage.lng,
      fare: widget.fare,
      distance: dist / 1000,
    );

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => RideTrackingScreen(rideId: rideId)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Confirm Ride', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(
              icon: Icons.electric_rickshaw,
              title: widget.saathi.name,
              subtitle: '${widget.saathi.vehicleType} · ${widget.saathi.vehicleNumber}',
              trailing: '⭐ ${widget.saathi.rating.toStringAsFixed(1)}',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.location_on,
              title: 'Route',
              subtitle:
                  '${widget.pickupVillage.nameGu} → ${widget.destinationVillage.nameGu}',
              trailing: null,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Fare',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '₹${widget.fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _loading ? null : _confirm,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirm & Book',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) Text(trailing!),
        ],
      ),
    );
  }
}
