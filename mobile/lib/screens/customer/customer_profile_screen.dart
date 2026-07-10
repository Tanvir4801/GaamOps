import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';
import '../welcome_screen.dart';
import 'ride_history_screen.dart';
import 'favourite_routes_screen.dart';
import 'emergency_contacts_screen.dart';
import 'gaam_wallet_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'edit_profile_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  int _totalRides = 0;
  double _totalSpent = 0;
  double _walletBalance = 0;
  bool _notificationsOn = true;
  bool _statsLoaded = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _headerCtrl, curve: Curves.easeOut));
    _loadPrefs();
    _loadStats();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() =>
            _notificationsOn = prefs.getBool('notifications_on') ?? true);
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    if (_uid.isEmpty) return;
    try {
      // Ride stats (no orderBy to avoid index requirement)
      final snap = await FirebaseFirestore.instance
          .collection('rides')
          .where('customerId', isEqualTo: _uid)
          .get();
      final rides = snap.docs.map((d) => d.data()).toList();
      final completed = rides.where((r) =>
          (r['status'] as String? ?? '').toLowerCase() == 'completed');

      // Wallet balance
      final walletDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('wallet')
          .doc('balance')
          .get();
      final balance = walletDoc.exists
          ? (walletDoc.data()?['balance'] ?? 0).toDouble()
          : 0.0;

      if (mounted) {
        setState(() {
          _totalRides = completed.length;
          _totalSpent =
              completed.fold(0.0, (s, r) => s + ((r['fare'] ?? 0).toDouble()));
          _walletBalance = balance;
          _statsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  Future<void> _toggleNotifications(bool val) async {
    setState(() => _notificationsOn = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_on', val);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('You will need to sign in again to book rides.'),
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
            child: const Text('Logout',
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

  Future<void> _regenerateRideCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Regenerate Ride Code?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'A new 4-digit code will be generated.\n'
            'Your old code will stop working immediately.\n\n'
            'Make sure you share the new code before booking your next ride.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate New Code',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || _uid.isEmpty) return;

    try {
      final newCode = await generateUniqueRideCode();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .update({
        'rideCode': newCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('New Ride Code: $newCode ✅'),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to regenerate code. Try again.'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _copyReferral(String name) {
    final safe = name.toUpperCase().replaceAll(' ', '');
    final code =
        'GAAM${safe.length >= 4 ? safe.substring(0, 4) : safe}';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied! 📋'),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return _errorWidget('Not signed in', 'Please sign in again to view your profile.');
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
              elevation: 0.5,
            ),
            body: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryGreen),
            ),
          );
        }

        // Error or no document
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data == null ||
            !snapshot.data!.exists) {
          return _errorWidget(
            'Profile not found',
            'Could not load your profile.\nPlease try again.',
          );
        }

        final user = UserModel.fromFirestore(snapshot.data!);

        // Start header animation once on first load
        if (!_headerCtrl.isAnimating && _headerCtrl.value == 0) {
          _headerCtrl.forward();
        }

        return _buildProfile(context, user);
      },
    );
  }

  Widget _buildProfile(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 20),
                tooltip: 'Edit Profile',
                onPressed: () => Navigator.push(
                  context,
                  _slide(EditProfileScreen(user: user)),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _headerFade,
                    child: SlideTransition(
                      position: _headerSlide,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          // Avatar
                          Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(40),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2.5),
                                ),
                                child: Center(
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    _slide(EditProfileScreen(user: user)),
                                  ),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit,
                                        color: AppColors.primaryGreen,
                                        size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(user.name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text(
                            '+91 ${user.phone.replaceAll('+91', '')}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('📍 ${user.village}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                // ── STATS ROW ──────────────────────────────────
                _StatsRow(
                  totalRides: _totalRides,
                  totalSpent: _totalSpent,
                  walletBalance: _walletBalance,
                  loaded: _statsLoaded,
                ),
                const SizedBox(height: 14),

                // ── RIDE CODE CARD ──────────────────────────────
                _RideCodeCard(
                  rideCode: user.rideCode,
                  onRegenerate: _regenerateRideCode,
                ),
                const SizedBox(height: 14),

                // ── ACCOUNT SECTION ────────────────────────────
                _Section(
                  title: 'MY ACCOUNT',
                  cardBg: cardBg,
                  children: [
                    _MenuItem(
                      icon: Icons.history_rounded,
                      label: 'Ride History',
                      onTap: () => Navigator.push(
                          context, _slide(const RideHistoryScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'GaamCash Wallet',
                      trailing: _walletBalance > 0
                          ? Text(
                              '₹${_walletBalance.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            )
                          : null,
                      onTap: () => Navigator.push(
                          context, _slide(const GaamWalletScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.star_rounded,
                      label: 'Favourite Routes',
                      onTap: () => Navigator.push(
                          context, _slide(const FavouriteRoutesScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.emergency_outlined,
                      label: 'Emergency Contacts',
                      onTap: () => Navigator.push(
                          context,
                          _slide(const EmergencyContactsScreen())),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── REFERRAL CARD ──────────────────────────────
                _ReferralCard(user: user, onCopy: () => _copyReferral(user.name)),

                const SizedBox(height: 12),

                // ── PREFERENCES SECTION ────────────────────────
                _Section(
                  title: 'PREFERENCES',
                  cardBg: cardBg,
                  children: [
                    // Dark Mode
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (_, mode, __) => _ToggleTile(
                        icon: mode == ThemeMode.dark
                            ? Icons.dark_mode
                            : Icons.light_mode_outlined,
                        label: 'Dark Mode',
                        subtitle: mode == ThemeMode.dark ? 'On' : 'Off',
                        value: mode == ThemeMode.dark,
                        onChanged: (_) => themeNotifier.toggle(),
                      ),
                    ),
                    // Notifications
                    _ToggleTile(
                      icon: _notificationsOn
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                      label: 'Ride Notifications',
                      subtitle: _notificationsOn
                          ? 'Get alerts for ride updates'
                          : 'Notifications paused',
                      value: _notificationsOn,
                      onChanged: _toggleNotifications,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── SUPPORT SECTION ────────────────────────────
                _Section(
                  title: 'SUPPORT',
                  cardBg: cardBg,
                  children: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () => Navigator.push(
                          context, _slide(const HelpScreen())),
                    ),
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'About GaamRide',
                      onTap: () => Navigator.push(
                          context, _slide(const AboutScreen())),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── LOGOUT ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text('Logout / Log Out',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _logout,
                  ),
                ),

                const SizedBox(height: 14),
                const Text('GaamRide v1.0.0 · Mahuva Taluka, Gujarat',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textGrey)),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget(String title, String msg) => Scaffold(
        appBar: AppBar(title: const Text('Profile'), elevation: 0.5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          ),
        ),
      );

  PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      );
}

// ── STATS ROW ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int totalRides;
  final double totalSpent;
  final double walletBalance;
  final bool loaded;

  const _StatsRow({
    required this.totalRides,
    required this.totalSpent,
    required this.walletBalance,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Row(children: [
      _chip(cardBg, '🛵', '$totalRides', 'Rides', loaded),
      const SizedBox(width: 8),
      _chip(cardBg, '💰', '₹${totalSpent.toStringAsFixed(0)}', 'Spent', loaded),
      const SizedBox(width: 8),
      _chip(cardBg, '💳', '₹${walletBalance.toStringAsFixed(0)}', 'GaamCash', loaded),
    ]);
  }

  Widget _chip(Color bg, String emoji, String val, String label, bool loaded) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6)],
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          loaded
              ? Text(val,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)
              : Container(
                  height: 14,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textGrey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── SECTION WRAPPER ───────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color cardBg;

  const _Section(
      {required this.title,
      required this.children,
      required this.cardBg});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.textGrey),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8)
          ],
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

// ── MENU ITEM ─────────────────────────────────────────────────────
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.trailing});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? (isDark
                  ? Colors.white.withAlpha(10)
                  : AppColors.bgGreen)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : AppColors.bgGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon,
                  color: AppColors.primaryGreen, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(widget.label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            if (widget.trailing != null) ...[
              widget.trailing!,
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right,
                color: AppColors.textGrey, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── TOGGLE TILE ───────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(15)
                : AppColors.bgGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textGrey)),
          ]),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primaryGreen,
        ),
      ]),
    );
  }
}

// ── RIDE CODE CARD ────────────────────────────────────────────────
class _RideCodeCard extends StatelessWidget {
  final String rideCode;
  final VoidCallback onRegenerate;

  const _RideCodeCard({
    required this.rideCode,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCode = rideCode.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2730) : const Color(0xFFE8F5FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00B4D8).withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00B4D8).withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tag_rounded,
                color: Color(0xFF0077B6), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Ride Code',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Share with driver to start each ride',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textGrey)),
            ]),
          ),
          // Regenerate button
          GestureDetector(
            onTap: onRegenerate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00B4D8).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF00B4D8).withAlpha(80)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded,
                    size: 14, color: Color(0xFF0077B6)),
                SizedBox(width: 4),
                Text('New Code',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0077B6))),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Code display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF00B4D8).withAlpha(60)),
          ),
          child: Text(
            hasCode ? rideCode : '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: hasCode ? 46 : 32,
              fontWeight: FontWeight.bold,
              color: hasCode
                  ? const Color(0xFF0077B6)
                  : AppColors.textGrey,
              letterSpacing: hasCode ? 18 : 0,
            ),
          ),
        ),
        if (!hasCode) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRegenerate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00B4D8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Generate My Ride Code',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── REFERRAL CARD ─────────────────────────────────────────────────
class _ReferralCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onCopy;

  const _ReferralCard({required this.user, required this.onCopy});

  String get _code {
    final safe =
        user.name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    return 'GAAM${safe.length >= 4 ? safe.substring(0, 4) : safe.padRight(4, 'X')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(80)),
      ),
      child: Row(children: [
        const Icon(Icons.card_giftcard_outlined,
            color: Colors.amber, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Refer & Earn ₹20',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('Share your code — both of you earn ₹20 GaamCash',
                style:
                    TextStyle(fontSize: 11, color: Colors.brown)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_code,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                          fontSize: 15,
                          letterSpacing: 3)),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_outlined,
                      size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  const Text('Copy',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
