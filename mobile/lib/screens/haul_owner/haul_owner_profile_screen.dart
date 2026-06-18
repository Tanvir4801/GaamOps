import 'dart:async';
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

class _HaulOwnerProfileScreenState extends State<HaulOwnerProfileScreen>
    with SingleTickerProviderStateMixin {
  HaulVehicleModel? _vehicle;
  bool _loading = true;
  StreamSubscription? _vehicleSub;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _load();
  }

  void _load() {
    if (_uid == null) return;
    _vehicleSub = HaulService.watchOwnerVehicle(_uid!).listen((snap) {
      if (!mounted) return;
      if (snap.exists) {
        final wasNull = _vehicle == null;
        setState(() {
          _vehicle = HaulVehicleModel.fromFirestore(snap);
          _loading = false;
        });
        if (wasNull) _fadeCtrl.forward();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _vehicleSub?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _maskAccount(String acc) {
    if (acc.length <= 4) return acc;
    return '${'*' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }

  String _joinedDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgBrown,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryBrown),
        ),
      );
    }

    final v = _vehicle;
    if (v == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBrown,
        appBar: AppBar(
          backgroundColor: AppColors.primaryBrown,
          foregroundColor: Colors.white,
          title: const Text('Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 56, color: AppColors.textLight),
              const SizedBox(height: 12),
              const Text('Profile not found',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBrown),
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBrown,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(slivers: [
          // ─── Premium Brown Header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.primaryBrown,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                tooltip: 'Sign Out',
                onPressed: _signOut,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3E2723),
                      Color(0xFF5D4037),
                      Color(0xFF8D6E63),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Avatar
                      Stack(alignment: Alignment.bottomRight, children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.8),
                                width: 3),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.1)
                              ],
                            ),
                          ),
                          child: v.profilePhotoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    v.profilePhotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _avatarInitial(v),
                                  ),
                                )
                              : _avatarInitial(v),
                        ),
                        if (v.isVerified)
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.verified,
                                color: Colors.white, size: 14),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      // Name + verified badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(v.ownerName,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2)),
                          if (v.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                color: Colors.lightBlue, size: 18),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Vehicle type + village
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${v.vehicleTypeEmoji}  ${v.vehicleTypeLabel}  ·  ${v.village}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_greeting  ·  Joined ${_joinedDate(v.createdAt)}',
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
                // ─── Stats Row ───────────────────────────────────────────────
                Row(children: [
                  _statCard('${v.totalBookings}', 'Total Jobs',
                      Icons.work_outline, AppColors.primaryBrown),
                  const SizedBox(width: 10),
                  _statCard('${v.rating.toStringAsFixed(1)} ★', 'Rating',
                      Icons.star_outline, AppColors.warning),
                  const SizedBox(width: 10),
                  _statCard(
                      v.isAvailable ? 'Online' : 'Offline',
                      'Status',
                      v.isAvailable
                          ? Icons.wifi_outlined
                          : Icons.wifi_off_outlined,
                      v.isAvailable ? AppColors.success : AppColors.textGrey),
                ]),

                const SizedBox(height: 16),

                // ─── Vehicle Information ──────────────────────────────────────
                _sectionCard(
                  title: 'Vehicle Information',
                  icon: Icons.local_shipping_outlined,
                  children: [
                    if (v.vehiclePhotoUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            v.vehiclePhotoUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    _infoRow('${v.vehicleTypeEmoji}', 'Vehicle Type',
                        v.vehicleTypeLabel),
                    if (v.vehicleBrand.isNotEmpty)
                      _infoRow('🏭', 'Brand', v.vehicleBrand),
                    if (v.vehicleModel.isNotEmpty)
                      _infoRow('🚗', 'Model', v.vehicleModel),
                    _infoRow('🔢', 'Reg. Number',
                        v.vehicleNumber.isNotEmpty ? v.vehicleNumber : '—'),
                    _infoRow('⚖️', 'Capacity',
                        v.capacity.isNotEmpty ? v.capacity : '—'),
                    _infoRow('💰', 'Rate',
                        '₹${v.ratePerHour.toStringAsFixed(0)}/hr'),
                    _infoRow('📍', 'Village', v.village),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── Documents Status ─────────────────────────────────────────
                _sectionCard(
                  title: 'Documents',
                  icon: Icons.folder_open_outlined,
                  children: [
                    _docStatusRow('Driving License (Front)', v.dlFrontUrl),
                    _docStatusRow('Driving License (Back)', v.dlBackUrl),
                    _docStatusRow('RC Book', v.rcUrl),
                    _docStatusRow('Vehicle Photo', v.vehiclePhotoUrl),
                    _docStatusRow('Insurance', v.insuranceUrl),
                    _docStatusRow('PUC Certificate', v.pucUrl),
                  ],
                ),

                // ─── Financial Info ───────────────────────────────────────────
                if (v.upiId.isNotEmpty ||
                    v.bankAccount.isNotEmpty ||
                    v.ifsc.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: 'Financial Information',
                    icon: Icons.account_balance_outlined,
                    children: [
                      if (v.upiId.isNotEmpty)
                        _infoRow('💳', 'UPI ID', v.upiId),
                      if (v.bankAccount.isNotEmpty)
                        _infoRow('🏦', 'Bank Account',
                            _maskAccount(v.bankAccount)),
                      if (v.ifsc.isNotEmpty)
                        _infoRow('🔑', 'IFSC', v.ifsc),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // ─── Performance ──────────────────────────────────────────────
                _sectionCard(
                  title: 'Performance',
                  icon: Icons.bar_chart_outlined,
                  children: [
                    _infoRow('📦', 'Total Bookings', '${v.totalBookings}'),
                    _infoRow('⭐', 'Rating',
                        '${v.rating.toStringAsFixed(1)} / 5.0'),
                    _infoRow(
                        '🛡',
                        'Verification',
                        v.isVerified
                            ? 'Verified ✓'
                            : 'Pending Review'),
                    _infoRow('📅', 'Member Since', _joinedDate(v.createdAt)),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── Quick Actions ────────────────────────────────────────────
                _sectionCard(
                  title: 'More',
                  icon: Icons.apps_outlined,
                  children: [
                    _actionRow(
                        Icons.support_agent_outlined,
                        'Support Center',
                        AppColors.primaryBrown,
                        () {}),
                    _actionRow(
                        Icons.share_outlined,
                        'Share GaamHaul',
                        Colors.blue,
                        () {}),
                    _actionRow(
                        Icons.logout,
                        'Sign Out',
                        Colors.red,
                        _signOut),
                  ],
                ),

                const SizedBox(height: 28),
                Text('GaamHaul v1.0 · Mahuva Taluka',
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

  Widget _avatarInitial(HaulVehicleModel v) {
    return Center(
      child: Text(
        v.ownerName.isNotEmpty ? v.ownerName[0].toUpperCase() : 'V',
        style: const TextStyle(
            fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textGrey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _sectionCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(7),
              blurRadius: 12,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.bgBrown,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: AppColors.primaryBrown, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark)),
          ]),
        ),
        Divider(
            height: 1, color: Colors.grey.shade100),
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
            style: const TextStyle(
                color: AppColors.textGrey, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textDark),
              textAlign: TextAlign.end),
        ),
      ]),
    );
  }

  Widget _docStatusRow(String label, String url) {
    final hasDoc = url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(
          hasDoc ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: hasDoc ? AppColors.success : AppColors.textLight,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: hasDoc
                      ? AppColors.textDark
                      : AppColors.textGrey)),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hasDoc
                ? const Color(0xFFE8F5E9)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            hasDoc ? 'Uploaded' : 'Missing',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: hasDoc
                    ? AppColors.success
                    : AppColors.textGrey),
          ),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right,
                color: Colors.grey.shade300, size: 20),
          ]),
        ),
      ),
    );
  }
}
