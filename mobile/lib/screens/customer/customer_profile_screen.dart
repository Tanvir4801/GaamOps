import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../welcome_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  UserModel? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await AuthService.getUser(uid);
    if (mounted) setState(() { _user = user; _loading = false; });
  }

  Future<void> _logout() async {
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
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _user == null
              ? const Center(child: Text('Unable to load profile'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.bgGreen,
                        child: Text(
                          _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(_user!.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('+91 ${_user!.phone}',
                          style: const TextStyle(color: AppColors.textGrey)),
                      const SizedBox(height: 6),
                      Text(_user!.village,
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 28),
                      _InfoTile(icon: Icons.person, label: 'Name', value: _user!.name),
                      _InfoTile(icon: Icons.phone, label: 'Phone', value: '+91 ${_user!.phone}'),
                      _InfoTile(icon: Icons.location_city, label: 'Village', value: _user!.village),
                      _InfoTile(icon: Icons.badge, label: 'Role', value: _user!.role.toUpperCase()),
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

  const _InfoTile({required this.icon, required this.label, required this.value});

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
