import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../welcome_screen.dart';
import 'ride_history_screen.dart';
import 'favourite_routes_screen.dart';
import 'emergency_contacts_screen.dart';
import 'gaam_wallet_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  bool _isLoading = true;
  bool _loadError = false;
  bool _historyError = false;
  int _totalRides = 0;
  double _totalSpent = 0;
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerFade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _isLoading = false; _loadError = true; });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();

      if (!mounted) return;

      if (userDoc.exists) {
        setState(() {
          _user = UserModel.fromFirestore(userDoc);
        });
        _headerCtrl.forward();
      } else {
        setState(() { _loadError = true; });
      }

      // Load history separately — don't block profile if this fails
      try {
        final rideDocs = await FirebaseFirestore.instance
            .collection('rides')
            .where('customerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

        if (!mounted) return;
        setState(() {
          _totalRides = rideDocs.docs.length;
          _totalSpent = rideDocs.docs.fold(0.0,
            (sum, doc) => sum + ((doc.data()['fare'] ?? 0).toDouble()));
        });
      } catch (historyError) {
        debugPrint('History load error: $historyError');
        if (mounted) setState(() { _historyError = true; });
      }

    } catch (e) {
      debugPrint('Profile load error: $e');
      if (!mounted) return;
      setState(() { _loadError = true; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('You will need to sign in again to book rides.'),
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

  void _copyReferral() {
    final name = _user?.name ?? 'USER';
    final safe = name.toUpperCase().replaceAll(' ', '');
    final code = 'GAAM${safe.length >= 4 ? safe.substring(0, 4) : safe}';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied!'),
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

  Widget _loadingScreen() => Scaffold(
    appBar: AppBar(
      title: const Text('પ્રોફાઇલ / Profile'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0.5,
    ),
    body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
  );

  Widget _errorScreen() => Scaffold(
    appBar: AppBar(
      title: const Text('પ્રોફાઇલ / Profile'),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0.5,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('પ્રોફાઇલ લોડ ન થઈ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Could not load profile. Please retry.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('ફરી પ્રયાસ / Retry',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() { _isLoading = true; _loadError = false; });
                _load();
              },
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _loadingScreen();
    if (_loadError || _user == null) return _errorScreen();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
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
                          const SizedBox(height: 16),
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _user!.name.isNotEmpty
                                    ? _user!.name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_user!.name, style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                          Text('+91 ${_user!.phone}',
                              style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('📍 ${_user!.village}',
                                style: const TextStyle(fontSize: 13, color: Colors.white)),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats row
                  Row(children: [
                    _statCard('કુલ સવારી', '$_totalRides', '🛵'),
                    const SizedBox(width: 10),
                    _statCard('ખર્ચ', '₹${_totalSpent.toStringAsFixed(0)}', '💰'),
                    const SizedBox(width: 10),
                    _statCard('ગામ', _user!.village, '🏘️'),
                  ]),

                  if (_historyError) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(child: Text(
                          'Ride history requires Firestore index. Stats may not be accurate.',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Account section
                  _menuSection('Account', [
                    _menuItem(Icons.history, 'Ride History', () =>
                        Navigator.push(context, _slide(const RideHistoryScreen()))),
                    _menuItem(Icons.account_balance_wallet_outlined,
                        'GaamCash Wallet', () =>
                            Navigator.push(context, _slide(const GaamWalletScreen()))),
                    _menuItem(Icons.star_rounded, 'Favourite Routes', () =>
                        Navigator.push(context, _slide(const FavouriteRoutesScreen()))),
                    _menuItem(Icons.emergency_outlined, 'Emergency Contacts', () =>
                        Navigator.push(context, _slide(const EmergencyContactsScreen()))),
                  ]),

                  const SizedBox(height: 12),

                  // Referral card
                  _buildReferral(),

                  const SizedBox(height: 12),

                  _menuSection('Support', [
                    _menuItem(Icons.help_outline, 'Help & Support', () {}),
                    _menuItem(Icons.info_outline, 'About GaamRide', () {}),
                  ]),

                  const SizedBox(height: 16),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(13), blurRadius: 8)
          ],
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _menuSection(String title, List<Widget> items) {
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

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return _AnimatedMenuItem(icon: icon, label: label, onTap: onTap);
  }

  Widget _buildReferral() {
    final name = _user?.name ?? 'USER';
    final safe = name.toUpperCase().replaceAll(' ', '');
    final code = 'GAAM${safe.length >= 4 ? safe.substring(0, 4) : safe}';
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
        const Icon(Icons.card_giftcard, color: Colors.amber, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Refer & Earn ₹20',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Text('Share your code. Get ₹20 GaamCash per friend',
              style: TextStyle(fontSize: 11, color: Colors.brown)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _copyReferral,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(code, style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    fontSize: 14,
                    letterSpacing: 2)),
                const SizedBox(width: 8),
                const Icon(Icons.copy, size: 14, color: Colors.amber),
              ]),
            ),
          ),
        ])),
      ]),
    );
  }

  PageRouteBuilder _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 350),
  );
}

class _AnimatedMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedMenuItem> createState() => _AnimatedMenuItemState();
}

class _AnimatedMenuItemState extends State<_AnimatedMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed ? AppColors.bgGreen : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: AppColors.primaryGreen, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(widget.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right, color: AppColors.textGrey, size: 20),
          ]),
        ),
      ),
    );
  }
}
