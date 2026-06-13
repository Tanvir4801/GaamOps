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
import '../../widgets/saathi_card.dart';
import '../../widgets/loading_overlay.dart';
import 'ride_request_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  List<VillageModel> _villages = [];
  VillageModel? _pickupVillage;
  VillageModel? _destinationVillage;
  List<SaathiModel> _availableSaathis = [];
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
    final results = await Future.wait([
      VillageService.getVillages(),
      SettingsService.getSettings(),
      _loadUserName(),
      _loadLocation(),
    ]);

    final villages = results[0] as List<VillageModel>;
    final settings = results[1] as dynamic;

    if (mounted) {
      setState(() {
        _villages = villages;
        _settings = settings.toMap();
        _loading = false;
      });
    }

    if (_myPosition != null && villages.isNotEmpty) {
      final nearest = VillageService.nearest(_myPosition!.latitude, _myPosition!.longitude, villages);
      setState(() => _pickupVillage = nearest);
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
    setState(() => _loading = true);
    final docs = await SaathiService.getAvailableSaathis();
    final saathis = docs.map((d) => SaathiModel.fromFirestore(d)).toList();

    if (mounted) {
      setState(() {
        _availableSaathis = saathis;
        _loading = false;
      });
    }
  }

  double _distanceTo(SaathiModel saathi) {
    if (_pickupVillage == null) return 0;
    if (saathi.position == null) return 0;
    final geoPoint = saathi.position!['geopoint'];
    if (geoPoint == null) return 0;
    return Geolocator.distanceBetween(
      _pickupVillage!.lat, _pickupVillage!.lng,
      geoPoint.latitude as double, geoPoint.longitude as double,
    );
  }

  double _estimatedFare() {
    if (_pickupVillage == null || _destinationVillage == null) return 0;
    final dist = VillageService.distanceBetween(_pickupVillage!, _destinationVillage!);
    return FareCalculator.calculate(distanceMeters: dist, settings: _settings);
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
          fare: _estimatedFare(),
        ),
      ),
    );
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    _VillagePickerRow(
                      label: '📍 Pickup',
                      village: _pickupVillage,
                      color: AppColors.primaryGreen,
                      onTap: () async {
                        final v = await VillageSelectorSheet.show(
                          context,
                          villages: _villages,
                          excludeVillageId: _destinationVillage?.id,
                        );
                        if (v != null) setState(() => _pickupVillage = v);
                      },
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    _VillagePickerRow(
                      label: '🏁 Destination',
                      village: _destinationVillage,
                      color: AppColors.primaryOrange,
                      onTap: () async {
                        final v = await VillageSelectorSheet.show(
                          context,
                          villages: _villages,
                          excludeVillageId: _pickupVillage?.id,
                        );
                        if (v != null) setState(() => _destinationVillage = v);
                      },
                    ),
                    if (_pickupVillage != null && _destinationVillage != null) ...[
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppStrings.estimatedFare,
                            style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                          ),
                          Text(
                            '₹${_estimatedFare().toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: const Text(
                    AppStrings.findSaathi,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  onPressed: _searchSaathis,
                ),
              ),
              if (_availableSaathis.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '${_availableSaathis.length} Saathi Available',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                ...sortedSaathis.map(
                  (s) => SaathiCard(
                    saathi: s,
                    distanceMeters: _distanceTo(s),
                    isPreferred: s == sortedSaathis.first,
                    onBook: () => _bookSaathi(s),
                  ),
                ),
              ] else if (!_loading && _availableSaathis.isEmpty && _pickupVillage != null) ...[
                const SizedBox(height: 30),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 60, color: AppColors.textLight),
                      SizedBox(height: 12),
                      Text('No Saathi available right now',
                          style: TextStyle(color: AppColors.textGrey)),
                      Text('Try again in a few minutes',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VillagePickerRow extends StatelessWidget {
  final String label;
  final VillageModel? village;
  final Color color;
  final VoidCallback onTap;

  const _VillagePickerRow({
    required this.label,
    required this.village,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                village != null
                    ? '${village!.nameGu} · ${village!.name}'
                    : 'Select village...',
                style: TextStyle(
                  fontWeight: village != null ? FontWeight.bold : FontWeight.normal,
                  color: village != null ? AppColors.textDark : AppColors.textLight,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: color),
          ],
        ),
      ),
    );
  }
}
