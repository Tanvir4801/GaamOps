import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../constants/app_colors.dart';
import '../../models/village_model.dart';
import '../../models/haul_vehicle_model.dart';
import '../../services/auth_service.dart';
import '../../services/village_service.dart';
import '../../services/haul_service.dart';
import '../../widgets/village_selector_sheet.dart';
import '../../widgets/haul_vehicle_card.dart';
import 'haul_confirm_screen.dart';

class GaamHaulHomeScreen extends StatefulWidget {
  const GaamHaulHomeScreen({super.key});

  @override
  State<GaamHaulHomeScreen> createState() => _GaamHaulHomeScreenState();
}

class _GaamHaulHomeScreenState extends State<GaamHaulHomeScreen> {
  List<VillageModel> _villages = [];
  VillageModel? _pickupVillage;
  String _selectedVehicleType = '';
  String _selectedDuration = '';
  List<HaulVehicleModel> _vehicles = [];
  Position? _myPosition;
  bool _loading = false;
  bool _searching = false;
  final _loadCtrl = TextEditingController();

  static const _vehicleOptions = [
    {'id': 'mini_tempo', 'emoji': '🚛', 'nameGu': 'મિની ટેમ્પો', 'nameEn': 'Mini Tempo', 'cap': 'up to 500 kg'},
    {'id': 'pickup', 'emoji': '🛻', 'nameGu': 'પિકઅપ ટ્રક', 'nameEn': 'Pickup Truck', 'cap': 'up to 1000 kg'},
    {'id': 'tractor', 'emoji': '🚜', 'nameGu': 'ટ્રેક્ટર', 'nameEn': 'Tractor', 'cap': 'Farm use'},
    {'id': 'truck_407', 'emoji': '🚚', 'nameGu': '407 ટ્રક', 'nameEn': '407 Truck', 'cap': 'up to 3000 kg'},
  ];

  static const _durationOptions = [
    {'id': '1h', 'labelGu': '1 કલાક', 'labelEn': '1 hour'},
    {'id': '2h', 'labelGu': '2 કલાક', 'labelEn': '2 hours'},
    {'id': 'half_day', 'labelGu': 'અર્ધો દિવ', 'labelEn': 'Half day'},
    {'id': 'full_day', 'labelGu': 'આખો દિવ', 'labelEn': 'Full day'},
  ];

  // Estimated owner earnings per vehicle type & duration
  static double _ownerEarnings(String vehicleId, String durationId) {
    final base = {
      'mini_tempo': 600.0, 'pickup': 800.0,
      'tractor': 700.0, 'truck_407': 1200.0,
    }[vehicleId] ?? 600.0;
    final mult = {
      '1h': 0.25, '2h': 0.5, 'half_day': 0.5, 'full_day': 1.0,
    }[durationId] ?? 0.25;
    return base * mult;
  }

  bool get _canSearch =>
      _pickupVillage != null &&
      _selectedVehicleType.isNotEmpty &&
      _selectedDuration.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final villages = await VillageService.getVillages();
    try {
      _myPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium));
    } catch (_) {}
    if (mounted) {
      setState(() {
        _villages = villages;
        _loading = false;
      });
      if (_myPosition != null && villages.isNotEmpty) {
        final nearest = VillageService.nearest(
            _myPosition!.latitude, _myPosition!.longitude, villages);
        setState(() => _pickupVillage = nearest);
      }
    }
  }

  Future<void> _detectLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium));
      if (mounted) {
        setState(() => _myPosition = pos);
        if (_villages.isNotEmpty) {
          final nearest = VillageService.nearest(
              pos.latitude, pos.longitude, _villages);
          setState(() => _pickupVillage = nearest);
        }
      }
    } catch (_) {}
  }

  Future<void> _searchVehicles() async {
    if (!_canSearch) return;
    setState(() { _searching = true; _vehicles = []; });
    try {
      final docs = await HaulService.getAvailableVehicles();
      final vehicles = docs.map((d) => HaulVehicleModel.fromFirestore(d)).toList();
      if (mounted) setState(() { _vehicles = vehicles; _searching = false; });
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  double _distanceTo(HaulVehicleModel vehicle) {
    if (_pickupVillage == null || vehicle.position == null) return 0;
    final geoPoint = vehicle.position!['geopoint'];
    if (geoPoint == null) return 0;
    return Geolocator.distanceBetween(
      _pickupVillage!.lat, _pickupVillage!.lng,
      geoPoint.latitude as double, geoPoint.longitude as double,
    );
  }

  void _confirmVehicle(HaulVehicleModel vehicle) async {
    if (_pickupVillage == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await AuthService.getUser(uid);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => HaulConfirmScreen(
        vehicle: vehicle,
        pickupVillage: _pickupVillage!,
        duration: _selectedDuration,
        loadDescription: _loadCtrl.text.trim(),
        customerName: user?.name ?? '',
        customerPhone: user?.phone ?? '',
        customerId: uid,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<HaulVehicleModel>.from(_vehicles)
      ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          elevation: 0,
          title: Row(children: [
            const Text('GaamHaul',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(width: 6),
            const Text('🚛', style: TextStyle(fontSize: 18)),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.orange.shade700),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.primaryOrange),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'ખેતી, shifting કે logistics માટે વાહન ભાડે કરો. '
                      'App booking fee: ₹75',
                      style: TextStyle(fontSize: 13,
                          color: Colors.orange.shade800),
                    )),
                  ]),
                ),

                const SizedBox(height: 16),

                // Auto-detected pickup
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8),
                    ],
                  ),
                  child: InkWell(
                    onTap: () async {
                      final v = await VillageSelectorSheet.show(context,
                          villages: _villages);
                      if (v != null) setState(() => _pickupVillage = v);
                    },
                    child: Row(children: [
                      const Icon(Icons.my_location, color: AppColors.primaryOrange),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pickup / ઉઠાવ સ્થાન',
                              style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                          Text(
                            _pickupVillage != null
                                ? '${_pickupVillage!.nameGu} · ${_pickupVillage!.name}'
                                : 'સ્થાન શોધી રહ્યા છે...',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold,
                                color: _pickupVillage != null
                                    ? AppColors.textDark : AppColors.textLight),
                          ),
                        ],
                      )),
                      GestureDetector(
                        onTap: _detectLocation,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.refresh,
                              color: AppColors.primaryOrange, size: 18),
                        ),
                      ),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),

                // Vehicle type heading
                const Text('વાહન પ્રકાર / Vehicle Type',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Vehicle grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: _vehicleOptions.map((v) {
                    final selected = _selectedVehicleType == v['id'];
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selectedVehicleType = v['id']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.orange.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryOrange : Colors.grey.shade200,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(children: [
                              Text(v['emoji']!,
                                  style: const TextStyle(fontSize: 20)),
                              const Spacer(),
                              if (selected)
                                const Icon(Icons.check_circle,
                                    color: AppColors.primaryOrange, size: 16),
                            ]),
                            const SizedBox(height: 4),
                            Text(v['nameGu']!,
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold,
                                    color: selected
                                        ? AppColors.primaryOrange
                                        : AppColors.textDark)),
                            Text(v['cap']!,
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Duration selector
                const Text('સમય / Duration',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(children: _durationOptions.map((d) {
                  final selected = _selectedDuration == d['id'];
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _selectedDuration = d['id']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryOrange : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryOrange : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(children: [
                          Text(d['labelGu']!,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: selected
                                      ? Colors.white : AppColors.textDark)),
                          Text(d['labelEn']!,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: selected
                                      ? Colors.white70 : AppColors.textGrey)),
                        ]),
                      ),
                    ),
                  ));
                }).toList()),

                const SizedBox(height: 16),

                // Load description
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6),
                    ],
                  ),
                  child: TextField(
                    controller: _loadCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.inventory_2_outlined,
                          color: AppColors.textGrey),
                      hintText: 'શું લઈ જવાનું? (વૈકલ્પિક)\n'
                          'e.g. શાકભાજી, ખાતર, સામાન...',
                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Cost preview
                if (_selectedVehicleType.isNotEmpty && _selectedDuration.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFF5722)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('App Booking Fee',
                              style: TextStyle(fontSize: 11, color: Colors.white70)),
                          const Text('₹75',
                              style: TextStyle(fontSize: 24,
                                  fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const Spacer(),
                      Container(width: 1, height: 40, color: Colors.white30),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Owner gets directly',
                              style: TextStyle(fontSize: 11, color: Colors.white70)),
                          Text(
                            '₹${_ownerEarnings(_selectedVehicleType, _selectedDuration).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 20,
                                fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ]),
                  ),

                const SizedBox(height: 16),

                // Search button
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSearch
                          ? AppColors.primaryOrange : Colors.grey.shade300,
                      elevation: _canSearch ? 4 : 0,
                      shadowColor: AppColors.primaryOrange.withAlpha(100),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _canSearch && !_searching ? _searchVehicles : null,
                    child: _searching
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, color: Colors.white),
                              SizedBox(width: 8),
                              Text('વાહન શોધો / Search Vehicles',
                                  style: TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Results
                if (_vehicles.isNotEmpty) ...[
                  Row(children: [
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.primaryOrange,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${_vehicles.length} વાહન મળ્યા',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  ...sorted.map((v) => HaulVehicleCard(
                    vehicle: v,
                    distanceMeters: _distanceTo(v),
                    onBook: () => _confirmVehicle(v),
                  )),
                ] else if (!_searching && _vehicles.isEmpty && _canSearch) ...[
                  Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Icon(Icons.local_shipping_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('કોઈ વાહન ઉપલબ્ધ નથી',
                          style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                      const Text('No vehicles available right now',
                          style: TextStyle(color: AppColors.textLight)),
                    ]),
                  )),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    super.dispose();
  }
}
