import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/saathi_model.dart';
import '../../services/auth_service.dart';
import '../../services/saathi_service.dart';
import '../../widgets/rating_widget.dart';
import '../welcome_screen.dart';

class SaathiProfileScreen extends StatefulWidget {
  const SaathiProfileScreen({super.key});

  @override
  State<SaathiProfileScreen> createState() => _SaathiProfileScreenState();
}

class _SaathiProfileScreenState extends State<SaathiProfileScreen> {
  SaathiModel? _saathi;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await SaathiService.getSaathi(uid);
    if (snap.exists && mounted) {
      setState(() {
        _saathi = SaathiModel.fromFirestore(snap);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await SaathiService.goOffline(uid);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Saathi Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _saathi == null
              ? const Center(child: Text('Profile not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.bgGreen,
                        child: Text(
                          _saathi!.name.isNotEmpty ? _saathi!.name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_saathi!.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('+91 ${_saathi!.phone}',
                          style: const TextStyle(color: AppColors.textGrey)),
                      const SizedBox(height: 6),
                      StarRating(rating: _saathi!.rating, size: 20),
                      const SizedBox(height: 4),
                      Text('${_saathi!.totalRides} rides completed',
                          style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                      const SizedBox(height: 20),
                      _InfoTile(Icons.electric_rickshaw, 'Vehicle', _saathi!.vehicleType),
                      _InfoTile(Icons.confirmation_number, 'Number', _saathi!.vehicleNumber),
                      _InfoTile(Icons.location_city, 'Village', _saathi!.village),
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 16,
                                color: AppColors.primaryGreen),
                            const SizedBox(width: 12),
                            const Text('Status',
                                style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _saathi!.isOnline ? AppColors.bgGreen : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _saathi!.isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _saathi!.isOnline ? AppColors.primaryGreen : AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
