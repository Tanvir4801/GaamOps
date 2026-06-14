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

    final villages = await VillageService.getVillages();
    final appSettings = await SettingsService.getSettings();
    final favRoutes = await FavouriteRoutesScreen.loadRoutes();

    if (mounted) {
      setState(() {
        _villages = villages;
        _settings = appSettings.toMap();
        _favouriteRoutes = favRoutes;
        _loading = false;
      });
    }

    // Run independently — they update state themselves
    _loadUserName();
    _loadLocation().then((_) {
      if (_myPosition != null && villages.isNotEmpty && mounted) {
        final nearest = VillageService.nearest(
            _myPosition!.latitude, _myPosition!.longitude, villages);
        setState(() => _pickupVillage = nearest);
      }
    });
  }

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await AuthService.getUser(uid);
    if (mounted) setState(() => _userName = user?.name ?? '');
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      if (mounted) setState(() => _myPosition = pos);
    } catch (_) {}
  }

  Future<void> _detectLocation() async {
    await _loadLocation();
    if (_myPosition != null && _villages.isNotEmpty) {
      final nearest = VillageService.nearest(
          _myPosition!.latitude, _myPosition!.longitude, _villages);
      if (mounted) setState(() => _pickupVillage = nearest);
    }
  }

  Future<void> _searchSaathis() async {
    if (_pickupVillage == null || _destinationVillage == null) return;
    setState(() { _searching = true; });
    final docs = await SaathiService.getAvailableSaathis();
    final saathis = docs.map((d) => SaathiModel.fromFirestore(d)).toList();
    if (mounted) {
      setState(() {
        _availableSaathis = saathis;
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

  double get _estimatedFare {
    if (_pickupVillage == null || _destinationVillage == null) return 0;
    final dist = VillageService.distanceBetween(_pickupVillage!, _destinationVillage!);
    return FareCalculator.calculate(distanceMeters: dist, settings: _settings);
  }

  double get _distanceKm {
    if (_pickupVillage == null || _destinationVillage == null) return 0;
    return VillageService.distanceBetween(_pickupVillage!, _destinationVillage!) / 1000;
  }

  void _bookSaathi(SaathiModel saathi) {
    if (_pickupVillage == null || _destinationVillage == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RideRequestScreen(
        pickupVillage: _pickupVillage!,
        destinationVillage: _destinationVillage!,
        saathi: saathi,
      ),
    ));
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Greeting app bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _userName.isNotEmpty
                                ? 'kem cho, $_userName 👋' : 'GaamRide 👋',
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const Text(AppStrings.serviceArea,
                              style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      )),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined,
                            color: Colors.white),
                        onPressed: () {},
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(children: [
                      // Pickup row
                      GestureDetector(
                        onTap: () async {
                          final v = await VillageSelectorSheet.show(context,
                              villages: _villages,
                              excludeVillageId: _destinationVillage?.id);
                          if (v != null) setState(() => _pickupVillage = v);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(
                                  color: AppColors.bgGreen,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.my_location,
                                  color: AppColors.primaryGreen, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('તમારું સ્થાન / Your Location',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.textGrey)),
                                Text(
                                  _pickupVillage != null
                                      ? '${_pickupVillage!.nameGu} · ${_pickupVillage!.name}'
                                      : 'સ્થાન શોધી રહ્યા છે...',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: _pickupVillage != null
                                          ? AppColors.primaryGreen
                                          : AppColors.textLight),
                                ),
                              ],
                            )),
                            if (_loading)
                              const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen),
                              )
                            else
                              GestureDetector(
                                onTap: _detectLocation,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                      color: AppColors.bgGreen,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.refresh,
                                      color: AppColors.primaryGreen, size: 18),
                                ),
                              ),
                          ]),
                        ),
                      ),

                      // Dotted divider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Row(
                          children: List.generate(40, (i) => Expanded(
                            child: Container(
                              height: 1,
                              color: i % 2 == 0
                                  ? Colors.grey.shade200 : Colors.transparent,
                            ),
                          )),
                        ),
                      ),

                      // Destination row
                      GestureDetector(
                        onTap: () async {
                          final v = await VillageSelectorSheet.show(context,
                              villages: _villages,
                              excludeVillageId: _pickupVillage?.id,
                              currentVillageName: _pickupVillage?.name);
                          if (v != null) setState(() => _destinationVillage = v);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Container(
                              width: 40, height: 40,
                              decoration: const BoxDecoration(
                                  color: AppColors.bgOrange,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.location_on,
                                  color: AppColors.primaryOrange, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ક્યાં જવું છે? / Where to go?',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.textGrey)),
                                Text(
                                  _destinationVillage != null
                                      ? '${_destinationVillage!.nameGu} · ${_destinationVillage!.name}'
                                      : 'ગામ પસંદ કરો...',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: _destinationVillage != null
                                          ? AppColors.textDark
                                          : Colors.grey.shade400),
                                ),
                              ],
                            )),
                            const Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textGrey),
                          ]),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 12),

                  // Favourite route chips
                  if (_favouriteRoutes.isNotEmpty) ...[
                    _buildFavouriteChips(),
                    const SizedBox(height: 12),
                  ],

                  // Fare estimate
                  if (_destinationVillage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        const Icon(Icons.currency_rupee,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('અંદાજિત ભાડું',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                            Text('₹${_estimatedFare.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                        const Spacer(),
                        Container(width: 1, height: 36, color: Colors.white30),
                        const SizedBox(width: 16),
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('અંતર',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                            Text('${_distanceKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Find Saathi button
                  ScaleTransition(
                    scale: _searching ? _pulse : const AlwaysStoppedAnimation(1.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                          shadowColor: AppColors.primaryGreen.withAlpha(80),
                        ),
                        icon: _searching
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.search, color: Colors.white),
                        label: Text(
                          _searching
                              ? 'શોધી રહ્યા છીએ... / Searching...'
                              : AppStrings.findSaathi,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        onPressed: (_pickupVillage != null &&
                                _destinationVillage != null &&
                                !_searching)
                            ? _searchSaathis
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Results
                  if (_availableSaathis.isNotEmpty) ...[
                    Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_availableSaathis.length} સાથી ઉપલબ્ધ',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${_availableSaathis.length} Saathi Available nearby',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
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
                  ] else if (!_loading && !_searching &&
                      _availableSaathis.isEmpty &&
                      _destinationVillage != null) ...[
                    const SizedBox(height: 20),
                    _buildEmptyState(),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavouriteChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          const Text('Quick Routes · ઝડપી માર્ગ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.textGrey)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FavouriteRoutesScreen())),
            child: const Text('Manage',
                style: TextStyle(fontSize: 11, color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _favouriteRoutes.map((r) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    final pickup = _villages
                        .where((v) => v.name == r.pickupVillage).firstOrNull;
                    final dest = _villages
                        .where((v) => v.name == r.destinationVillage).firstOrNull;
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
                            color: Colors.black.withAlpha(8),
                            blurRadius: 4)
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppColors.primaryGreen),
                      const SizedBox(width: 4),
                      Text('${r.pickupVillage} → ${r.destinationVillage}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(children: [
          Icon(Icons.directions_bike_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('કોઈ સાથી ઉપલબ્ધ નથી',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500,
                  color: AppColors.textGrey)),
          const Text('No Saathi available right now',
              style: TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 8),
          const Text('થોડીવાર રાહ જુઓ અને ફરી પ્રયાસ કરો',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center),
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
        ]),
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

  int get _etaMinutes =>
      (distanceMeters / 1000 / 25 * 60).round().clamp(1, 60);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPreferred
            ? Border.all(color: AppColors.primaryGreen, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.bgGreen,
              child: Text(
                saathi.name.isNotEmpty ? saathi.name[0].toUpperCase() : 'S',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(saathi.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (isPreferred) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Nearest',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
                Text('${saathi.vehicleType} · ${saathi.vehicleNumber}',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
              ],
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text(saathi.rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              Text('~$_etaMinutes min',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textGrey)),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.near_me_outlined,
                size: 14, color: AppColors.textGrey),
            const SizedBox(width: 4),
            Text(_distanceText,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textGrey)),
            const Spacer(),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: onBook,
                child: const Text('Book',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
