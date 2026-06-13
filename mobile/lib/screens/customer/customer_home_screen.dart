import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/village_model.dart';
import '../../models/saathi_model.dart';
import '../../services/auth_service.dart';
import '../../services/village_service.dart';
import '../../services/saathi_service.dart';
import '../../services/settings_service.dart';
import '../../utils/fare_calculator.dart';
import '../../widgets/village_selector_sheet.dart';
import '../../widgets/loading_overlay.dart';
import 'ride_request_screen.dart';
import 'favourite_routes_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  List<VillageModel> _villages = [];
  VillageModel? _pickupVillage;
  VillageModel? _destinationVillage;
  List<SaathiModel> _availableSaathis = [];
  List<FavouriteRoute> _favouriteRoutes = [];
  Position? _myPosition;
  bool _loading = false;
  bool _searching = false;
  String _userName = '';
  Map<String, dynamic> _settings = {};
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  Future<void> _init() async {
  setState(() => _loading = true);

  final results = await Future.wait([
    VillageService.getVillages(),
    SettingsService.getSettings(),
    _loadUserName(),
    _loadLocation(),
    FavouriteRoutesScreen.loadRoutes(),
  ]);

  final villages = results[0] as List<VillageModel>;
  final settings = results[1] as dynamic;
  final favRoutes = results[4] as List<FavouriteRoute>;

  if (mounted) {
    setState(() {
      _villages = villages;
      _settings = settings.toMap();
      _favouriteRoutes = favRoutes;
      _loading = false;
    });
  }

  if (_myPosition != null && villages.isNotEmpty) {
    final nearest = VillageService.nearest(
      _myPosition!.latitude,
      _myPosition!.longitude,
      villages,
    );

    if (mounted) {
      setState(() => _pickupVillage = nearest);
    }
  }
}
  

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await AuthService.getUser(uid);
    if (mounted) setState(() => _userName = user?.name ?? '');
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _myPosition = pos);
    } catch (_) {}
  }

  Future<void> _searchSaathis() async {
    if (_pickupVillage == null || _destinationVillage == null) return;
    setState(() { _searching = true; _loading = true; });
    final docs = await SaathiService.getAvailableSaathis();
    final saathis = docs.map((d) => SaathiModel.fromFirestore(d)).toList();
    if (mounted) {
      setState(() {
        _availableSaathis = saathis;
        _loading = false;
        _searching = false;
      });
    }
  }

  double _distanceTo(SaathiModel saathi) {
    if (_pickupVillage == null || saathi.position == null) return 0;
    final geoPoint = saathi.position!['geopoint'];
    if (geoPoint == null) return 0;
    return Geolocator.distanceBetween(
      _pickupVillage!.lat, _pickupVillage!.lng,
      geoPoint.latitude as double, geoPoint.longitude as double,
    );
  }

  double _estimatedFare() {
    if (_pickupVillage == null || _destinationVillage == null) return 0;
    final dist =
        VillageService.distanceBetween(_pickupVillage!, _destinationVillage!);
    return FareCalculator.calculate(distanceMeters: dist, settings: _settings);
  }

  double _distanceKm() {
    if (_pickupVillage == null || _destinationVillage == null) return 0;
    return VillageService.distanceBetween(_pickupVillage!, _destinationVillage!) /
        1000;
  }

  void _bookSaathi(SaathiModel saathi) {
    if (_pickupVillage == null || _destinationVillage == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideRequestScreen(
          pickupVillage: _pickupVillage!,
          destinationVillage: _destinationVillage!,
          saathi: saathi,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedSaathis = List<SaathiModel>.from(_availableSaathis)
      ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName.isNotEmpty ? 'kem cho, $_userName 👋' : 'GaamRide',
                style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const Text(AppStrings.serviceArea,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 11)),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationCard(),
              const SizedBox(height: 12),
              if (_favouriteRoutes.isNotEmpty) _buildFavouriteChips(),
              if (_favouriteRoutes.isNotEmpty) const SizedBox(height: 12),
              _buildDestinationCard(),
              if (_pickupVillage != null && _destinationVillage != null) ...[
                const SizedBox(height: 12),
                _buildFareCard(),
              ],
              const SizedBox(height: 14),
              _buildFindButton(),
              if (_availableSaathis.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '${_availableSaathis.length} સાથી ઉપલબ્ધ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_availableSaathis.length} Saathi Available',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textGrey),
                ),
                const SizedBox(height: 10),
                ...sortedSaathis.asMap().entries.map(
                  (e) => _SaathiCard(
                    saathi: e.value,
                    distanceMeters: _distanceTo(e.value),
                    isPreferred: e.key == 0,
                    onBook: () => _bookSaathi(e.value),
                  ),
                ),
              ] else if (!_loading &&
                  _availableSaathis.isEmpty &&
                  _pickupVillage != null) ...[
                const SizedBox(height: 30),
                _buildEmptyState(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavouriteChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryGreen),
            const SizedBox(width: 4),
            const Text(
              'Quick Routes · ઝડપી માર્ગ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FavouriteRoutesScreen()),
              ),
              child: const Text(
                'Manage',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _favouriteRoutes.map((r) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    final pickup = _villages.where(
                        (v) => v.name == r.pickupVillage).firstOrNull;
                    final dest = _villages.where(
                        (v) => v.name == r.destinationVillage).firstOrNull;
                    if (pickup != null && dest != null) {
                      setState(() {
                        _pickupVillage = pickup;
                        _destinationVillage = dest;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryGreen),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: AppColors.primaryGreen),
                        const SizedBox(width: 4),
                        Text(
                          '${r.pickupVillage} → ${r.destinationVillage}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return GestureDetector(
      onTap: () async {
        final v = await VillageSelectorSheet.show(
          context,
          villages: _villages,
          excludeVillageId: _destinationVillage?.id,
        );
        if (v != null) setState(() => _pickupVillage = v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Row(
          children: [
            _PulsingDot(color: AppColors.primaryGreen),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'તમારું સ્થાન / Your Location',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                  Text(
                    _pickupVillage != null
                        ? '${_pickupVillage!.nameGu} · ${_pickupVillage!.name}'
                        : 'સ્થાન શોધી રહ્યા છે...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _pickupVillage != null
                          ? AppColors.primaryGreen
                          : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await _loadLocation();
                if (_myPosition != null && _villages.isNotEmpty) {
                  final nearest = VillageService.nearest(
                      _myPosition!.latitude, _myPosition!.longitude, _villages);
                  if (mounted) setState(() => _pickupVillage = nearest);
                }
              },
              icon: const Icon(Icons.refresh,
                  color: AppColors.primaryGreen, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard() {
    return GestureDetector(
      onTap: () async {
        final v = await VillageSelectorSheet.show(
          context,
          villages: _villages,
          excludeVillageId: _pickupVillage?.id,
          currentVillageName: _pickupVillage?.name,
        );
        if (v != null) setState(() => _destinationVillage = v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: const Border(
            left: BorderSide(color: AppColors.primaryOrange, width: 3),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 8)
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.flag, color: AppColors.primaryOrange, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ક્યાં જવું છે? / Where to go?',
                    style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                  ),
                  Text(
                    _destinationVillage != null
                        ? '${_destinationVillage!.nameGu} · ${_destinationVillage!.name}'
                        : 'ગામ પસંદ કરો...',
                    style: TextStyle(
                      fontWeight: _destinationVillage != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 16,
                      color: _destinationVillage != null
                          ? AppColors.textDark
                          : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.textLight, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFareCard() {
    final fare = _estimatedFare();
    final km = _distanceKm();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('₹',
              style: TextStyle(
                  color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('અંદાજિત ભાડું / Estimated Fare',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  '₹${fare.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white30),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('અંતર / Distance',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(
                '${km.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFindButton() {
    return ScaleTransition(
      scale: _searching ? _pulse : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: const Icon(Icons.search, color: Colors.white),
          label: Text(
            _searching ? 'શોધી રહ્યા છીએ... / Searching...' : AppStrings.findSaathi,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          onPressed: (_pickupVillage != null && _destinationVillage != null)
              ? _searchSaathis
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(Icons.directions_bike_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'કોઈ સાથી ઉપલબ્ધ નથી',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGrey),
            ),
            const Text(
              'No Saathi available right now',
              style: TextStyle(color: AppColors.textLight),
            ),
            const SizedBox(height: 8),
            const Text(
              'થોડીવાર રાહ જુઓ અને ફરી પ્રયાસ કરો',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('ફરી શોધો / Search Again'),
              onPressed: _searchSaathis,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SaathiCard extends StatelessWidget {
  final SaathiModel saathi;
  final double distanceMeters;
  final bool isPreferred;
  final VoidCallback onBook;

  const _SaathiCard({
    required this.saathi,
    required this.distanceMeters,
    required this.isPreferred,
    required this.onBook,
  });

  String get _distanceText {
    if (distanceMeters < 1000) return '${distanceMeters.toStringAsFixed(0)} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  int get _etaMinutes => (distanceMeters / 1000 / 25 * 60).round().clamp(1, 60);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.bgGreen,
              child: Text(
                saathi.name.isNotEmpty ? saathi.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(saathi.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (isPreferred) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '⭐ PREFERRED',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.electric_rickshaw,
                          size: 14, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        '${saathi.vehicleType} · $_distanceText · ~$_etaMinutes min',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: Colors.amber),
                      const SizedBox(width: 3),
                      Text(
                        saathi.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Book',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.call,
                      color: AppColors.primaryGreen, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
