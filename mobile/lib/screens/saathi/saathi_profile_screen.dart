import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/saathi_model.dart';
import '../../services/auth_service.dart';
import '../../services/saathi_service.dart';
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
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  StreamSubscription? _saathiSub;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
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
        if (wasNull) _fadeCtrl.forward();
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white)),
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

  String get _vehicleEmoji {
    switch (_saathi?.vehicleType.toLowerCase()) {
      case 'auto': return '🛺';
      case 'cycle': return '🚲';
      case 'ev': return '⚡';
      default: return '🛵';
    }
  }

  String _joinedDate() {
    final ts = _saathi?.createdAt;
    if (ts == null) return 'Recently';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[ts.month - 1]} ${ts.year}';
  }

  @override
  void dispose() {
    _saathiSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgGreen,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }
    if (_loadError || _saathi == null) {
      return Scaffold(
        backgroundColor: AppColors.bgGreen,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined,
                size: 56, color: AppColors.textLight),
            const SizedBox(height: 12),
            const Text('Profile not found',
                style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen),
              onPressed: () {
                setState(() { _loading = true; _loadError = false; });
                _load();
              },
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        )),
      );
    }

    final s = _saathi!;

    return Scaffold(
      backgroundColor: AppColors.bgGreen,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(slivers: [
          // ─── Green Header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                tooltip: 'Sign Out',
                onPressed: _logout,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF388E3C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Avatar
                      Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.8), width: 3),
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: s.profilePhoto.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(s.profilePhoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _initials(s)),
                                )
                              : _initials(s),
                        ),
                        if (s.isVerified)
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.verified,
                                color: Colors.white, size: 14),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          if (s.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                color: Colors.lightBlue, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_vehicleEmoji  ${s.vehicleType}  ·  ${s.village}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${s.phone}  ·  Joined ${_joinedDate()}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              child: Column(children: [
                // ─── Stats Row ──────────────────────────────────────────────
                Row(children: [
                  _statCard('${s.totalRides}', 'Total Rides',
                      Icons.directions_bike_outlined, AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  _statCard('${s.rating.toStringAsFixed(1)} ★', 'Rating',
                      Icons.star_outline, AppColors.warning),
                  const SizedBox(width: 10),
                  _statCard(
                      s.isOnline ? 'Online' : 'Offline',
                      'Status',
                      s.isOnline ? Icons.wifi_outlined : Icons.wifi_off_outlined,
                      s.isOnline ? AppColors.success : AppColors.textGrey),
                ]),

                const SizedBox(height: 16),

                // ─── Vehicle Info ────────────────────────────────────────────
                _sectionCard(
                  title: 'Vehicle',
                  icon: Icons.electric_rickshaw_outlined,
                  children: [
                    _infoRow('$_vehicleEmoji', 'Type', s.vehicleType),
                    _infoRow('🔢', 'Number',
                        s.vehicleNumber.isNotEmpty ? s.vehicleNumber : '—'),
                    if (s.vehicleColor.isNotEmpty)
                      _infoRow('🎨', 'Color', s.vehicleColor),
                    _infoRow('📍', 'Village', s.village),
                    _infoRow('🛡', 'Verification',
                        s.isVerified ? 'Verified ✓' : 'Pending'),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── Performance ─────────────────────────────────────────────
                _sectionCard(
                  title: 'Performance',
                  icon: Icons.bar_chart_outlined,
                  children: [
                    _infoRow('🛵', 'Total Rides', '${s.totalRides}'),
                    _infoRow('⭐', 'Rating', '${s.rating.toStringAsFixed(1)} / 5.0'),
                    _infoRow('📅', 'Member Since', _joinedDate()),
                    _infoRow('📞', 'Phone', s.phone),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── Quick Actions ───────────────────────────────────────────
                _sectionCard(
                  title: 'More',
                  icon: Icons.apps_outlined,
                  children: [
                    _actionRow(
                        Icons.history_outlined,
                        'Ride History',
                        AppColors.primaryGreen,
                        () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const SaathiHistoryScreen()))),
                    _actionRow(
                        Icons.account_balance_wallet_outlined,
                        'Earnings',
                        Colors.teal,
                        () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const SaathiEarningsScreen()))),
                    _actionRow(
                        Icons.support_agent_outlined,
                        'Help & Support',
                        Colors.blue,
                        () {}),
                    _actionRow(
                        Icons.share_outlined,
                        'Share GaamRide',
                        Colors.indigo,
                        () {}),
                    _actionRow(
                        Icons.logout,
                        'Sign Out',
                        Colors.red,
                        _logout),
                  ],
                ),

                const SizedBox(height: 28),
                Text('GaamRide v1.0 · Mahuva Taluka',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey.withOpacity(0.7))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _initials(SaathiModel s) {
    return Center(
      child: Text(
        s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
        style: const TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(7), blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark)),
          ]),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        ...children,
      ]),
    );
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 13, color: AppColors.textDark),
              textAlign: TextAlign.end),
        ),
      ]),
    );
  }

  Widget _actionRow(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right,
                color: Colors.grey.shade300, size: 20),
          ]),
        ),
      ),
    );
  }
}
