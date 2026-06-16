import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/village_model.dart';
import '../../services/auth_service.dart';
import '../../services/village_service.dart';
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
    {
  List<VillageModel> _villages = [];
  VillageModel? _pickupVillage;
  VillageModel? _destinationVillage;
  List<FavouriteRoute> _favouriteRoutes = [];
  Position? _myPosition;
  bool _loading = false;
  String _userName = '';
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
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
  desiredAccuracy: LocationAccuracy.medium,
);
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

  void _bookRide() {
    if (_pickupVillage == null || _destinationVillage == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RideRequestScreen(
        pickupVillage: _pickupVillage!,
        destinationVillage: _destinationVillage!,
      ),
    ));
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

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

                  // Book Ride button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                        shadowColor: AppColors.primaryGreen.withAlpha(80),
                      ),
                      icon: const Icon(Icons.electric_rickshaw,
                          color: Colors.white, size: 22),
                      label: Text(
                        _destinationVillage == null
                            ? 'ગામ પસંદ કરો / Select Destination'
                            : 'Ride Book કરો / Book Ride Now',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      onPressed: (_pickupVillage != null &&
                              _destinationVillage != null)
                          ? _bookRide
                          : null,
                    ),
                  ),

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

}
