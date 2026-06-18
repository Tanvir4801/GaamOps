import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/saathi_model.dart';
import '../../services/auth_service.dart';
import '../../services/saathi_service.dart';
import '../../widgets/rating_widget.dart';
import '../welcome_screen.dart';
import 'saathi_history_screen.dart';
import 'saathi_earnings_screen.dart';

class SaathiProfileScreen extends StatefulWidget {
  const SaathiProfileScreen({super.key});

  @override
  State<SaathiProfileScreen> createState() => _SaathiProfileScreenState();
}

class _SaathiProfileScreenState extends State<SaathiProfileScreen>
    with SingleTickerProviderStateMixin {
  SaathiModel? _saathi;
  bool _loading = true;
  bool _loadError = false;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  StreamSubscription? _saathiSub;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _load();
  }

  void _load() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _loading = false; _loadError = true; });
      return;
    }
    _saathiSub?.cancel();
    _saathiSub = SaathiService.watchSaathi(uid).listen((snap) {
      if (!mounted) return;
      if (snap.exists) {
        final wasNull = _saathi == null;
        setState(() {
          _saathi = SaathiModel.fromFirestore(snap);
          _loading = false;
        });
        if (wasNull) _headerCtrl.forward();
      } else {
        setState(() { _loading = false; _loadError = true; });
      }
    }, onError: (_) {
      if (mounted) setState(() { _loading = false; _loadError = true; });
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You will go offline and need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try { await SaathiService.goOffline(uid); } catch (_) {}
      }
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _saathiSub?.cancel();
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }
    if (_loadError || _saathi == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textDark,
          elevation: 0.5,
        ),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Profile not found',
                style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _loading = true; _loadError = false; });
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        )),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFBF360C), Color(0xFFE65100)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withAlpha(50),
                        child: Text(
                          _saathi!.name.isNotEmpty
                              ? _saathi!.name[0].toUpperCase() : 'S',
                          style: const TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_saathi!.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('+91 ${_saathi!.phone}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                      const SizedBox(height: 6),
                      StarRating(rating: _saathi!.rating, size: 18),
                      const SizedBox(height: 4),
                      Text('${_saathi!.totalRides} rides completed',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Stats row
              Row(children: [
                _statChip('🛵', '${_saathi!.totalRides}', 'Total Rides'),
                const SizedBox(width: 10),
                _statChip('⭐', _saathi!.rating.toStringAsFixed(1), 'Rating'),
                const SizedBox(width: 10),
                _statChip('📍', _saathi!.village, 'Village'),
              ]),

              const SizedBox(height: 16),

              // Vehicle info
              _infoSection('Vehicle', [
                _infoRow(Icons.electric_rickshaw, 'Type', _saathi!.vehicleType),
                _infoRow(Icons.confirmation_number, 'Number', _saathi!.vehicleNumber),
                _infoRow(Icons.location_city, 'Village', _saathi!.village),
                _infoRow(
                  _saathi!.isOnline ? Icons.wifi : Icons.wifi_off,
                  'Status',
                  _saathi!.isOnline ? 'Online' : 'Offline',
                  valueColor: _saathi!.isOnline
                      ? AppColors.primaryGreen : AppColors.textGrey,
                ),
              ]),

              const SizedBox(height: 12),

              // Quick actions
              _infoSection('Quick Actions', [
                _actionRow(Icons.history, 'Ride History',
                    AppColors.primaryOrange, () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SaathiHistoryScreen()))),
                _actionRow(Icons.account_balance_wallet_outlined, 'Earnings',
                    AppColors.primaryGreen, () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SaathiEarningsScreen()))),
                _actionRow(Icons.help_outline, 'Help & Support',
                    Colors.blue, () {}),
              ]),

              const SizedBox(height: 16),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _logout,
                ),
              ),

              const SizedBox(height: 12),
              const Text('GaamRide v1.0.0 · Mahuva Taluka',
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _statChip(String emoji, String value, String label) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6)],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
            textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _infoSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textGrey,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ),
        ...items,
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, color: AppColors.primaryOrange, size: 18),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textDark)),
      ]),
    );
  }

  Widget _actionRow(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20),
        ]),
      ),
    );
  }
}
