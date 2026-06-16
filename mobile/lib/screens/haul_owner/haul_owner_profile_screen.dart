import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/haul_vehicle_model.dart';
import '../../services/haul_service.dart';
import '../../services/auth_service.dart';
import '../welcome_screen.dart';

class HaulOwnerProfileScreen extends StatefulWidget {
  const HaulOwnerProfileScreen({super.key});

  @override
  State<HaulOwnerProfileScreen> createState() => _HaulOwnerProfileScreenState();
}

class _HaulOwnerProfileScreenState extends State<HaulOwnerProfileScreen> {
  HaulVehicleModel? _vehicle;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_uid == null) return;
    final v = await HaulService.getOwnerVehicle(_uid!);
    if (mounted) setState(() => _vehicle = v);
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _vehicle;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: v == null
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.bgOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(v.vehicleEmoji ?? '🚛',
                        style: const TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(v.ownerName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text(v.phone,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 24),
                _infoCard([
                  _row(Icons.agriculture, 'Vehicle Type', v.vehicleTypeLabel),
                  _row(Icons.pin, 'Vehicle Number', v.vehicleNumber),
                  _row(Icons.location_on_outlined, 'Village', v.village),
                  _row(Icons.currency_rupee, 'Rate per Hour',
                      '₹${v.ratePerHour.toStringAsFixed(0)}'),
                  _row(Icons.local_shipping_outlined, 'Capacity', v.capacity),
                  _row(Icons.book_outlined, 'Total Jobs',
                      '${v.totalBookings}'),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out',
                        style: TextStyle(color: Colors.red)),
                    onPressed: _signOut,
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)
          ],
        ),
        child: Column(children: children),
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primaryOrange),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textGrey, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}

extension on HaulVehicleModel {
  String? get vehicleEmoji {
    switch (vehicleType.toLowerCase()) {
      case 'tractor':    return '🚜';
      case 'pickup':     return '🛻';
      case 'truck_407':  return '🚚';
      default:           return '🚛';
    }
  }
}
