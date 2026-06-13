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
import '../../widgets/loading_overlay.dart';
import 'haul_confirm_screen.dart';

class GaamHaulHomeScreen extends StatefulWidget {
  const GaamHaulHomeScreen({super.key});

  @override
  State<GaamHaulHomeScreen> createState() => _GaamHaulHomeScreenState();
}

class _GaamHaulHomeScreenState extends State<GaamHaulHomeScreen> {
  List<VillageModel> _villages = [];
  VillageModel? _pickupVillage;
  String _loadDescription = '';
  String _selectedDuration = '1h';
  List<HaulVehicleModel> _vehicles = [];
  Position? _myPosition;
  bool _loading = false;

  final _loadController = TextEditingController();

  final _durations = ['1h', '2h', 'half_day', 'full_day'];
  final _durationLabels = {'1h': '1 Hour', '2h': '2 Hours', 'half_day': 'Half Day (4h)', 'full_day': 'Full Day (8h)'};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final villages = await VillageService.getVillages();
    try {
      _myPosition = await Geolocator.getCurrentPosition();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _villages = villages;
        _loading = false;
      });
      if (_myPosition != null && villages.isNotEmpty) {
        final nearest = VillageService.nearest(_myPosition!.latitude, _myPosition!.longitude, villages);
        setState(() => _pickupVillage = nearest);
      }
    }
  }

  Future<void> _searchVehicles() async {
    setState(() => _loading = true);
    final docs = await HaulService.getAvailableVehicles();
    final vehicles = docs.map((d) => HaulVehicleModel.fromFirestore(d)).toList();
    if (mounted) setState(() { _vehicles = vehicles; _loading = false; });
  }

  double _distanceTo(HaulVehicleModel vehicle) {
    if (_pickupVillage == null) return 0;
    if (vehicle.position == null) return 0;
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HaulConfirmScreen(
          vehicle: vehicle,
          pickupVillage: _pickupVillage!,
          duration: _selectedDuration,
          loadDescription: _loadController.text.trim(),
          customerName: user?.name ?? '',
          customerPhone: user?.phone ?? '',
          customerId: uid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<HaulVehicleModel>.from(_vehicles)
      ..sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));

    return LoadingOverlay(
      isLoading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text('GaamHaul 🚛',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rent a vehicle for shifting & logistics',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () async {
                        final v = await VillageSelectorSheet.show(context, villages: _villages);
                        if (v != null) setState(() => _pickupVillage = v);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pickupVillage != null
                                  ? '${_pickupVillage!.nameGu} · ${_pickupVillage!.name}'
                                  : 'Select pickup village',
                              style: TextStyle(
                                color: _pickupVillage != null ? AppColors.textDark : AppColors.textLight,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: _loadController,
                      decoration: const InputDecoration(
                        hintText: 'What are you moving? (Optional)',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.inventory_2_outlined, color: AppColors.primaryOrange),
                        hintStyle: TextStyle(color: AppColors.textLight),
                      ),
                      onChanged: (v) => _loadDescription = v,
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: AppColors.primaryOrange, size: 20),
                        const SizedBox(width: 10),
                        const Text('Duration: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _selectedDuration,
                          underline: const SizedBox(),
                          items: _durations.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(_durationLabels[d]!),
                          )).toList(),
                          onChanged: (v) => setState(() => _selectedDuration = v!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: const Text('Search Vehicles',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: _searchVehicles,
                ),
              ),
              if (_vehicles.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('${_vehicles.length} Vehicles Available',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                ...sorted.map((v) => HaulVehicleCard(
                  vehicle: v,
                  distanceMeters: _distanceTo(v),
                  onBook: () => _confirmVehicle(v),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadController.dispose();
    super.dispose();
  }
}
