import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../services/emergency_contact_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/radar_searching_widget.dart';
import 'ride_complete_screen.dart';

// Mahuva Taluka bounds
const _swBound = LatLng(20.78, 73.19);
const _neBound = LatLng(20.92, 73.32);
const _mahuvaCenter = LatLng(20.8394, 73.2637);

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _rideSub;
  RideModel? _ride;
  final MapController _mapController = MapController();

  // Saathi animated position
  LatLng? _saathiPosition;
  LatLng? _saathiPrevPosition;
  Timer? _animTimer;

  // Status pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(_pulseCtrl);

    _rideSub = RideService.watchRide(widget.rideId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final ride = RideModel.fromFirestore(snap);
      final newSaathiLat = ride.saathiLat;
      final newSaathiLng = ride.saathiLng;

      setState(() => _ride = ride);

      // Animate saathi marker to new position
      if (newSaathiLat != 0 && newSaathiLng != 0) {
        final newPos = LatLng(newSaathiLat, newSaathiLng);
        final prevPos = _saathiPosition ?? newPos;
        _animateSaathiTo(prevPos, newPos);
      }

      // Navigate to complete screen
      if (ride.status == RideModel.completed) {
        _rideSub?.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => RideCompleteScreen(ride: ride)),
            (route) => route.isFirst,
          );
        }
      }
    });
  }

  /// Smooth 30-step linear interpolation animation for the Saathi marker
  void _animateSaathiTo(LatLng from, LatLng to) {
    _animTimer?.cancel();
    const totalSteps = 30;
    int step = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      step++;
      if (!mounted) { t.cancel(); return; }
      if (step >= totalSteps) {
        t.cancel();
        setState(() { _saathiPosition = to; _saathiPrevPosition = to; });
        return;
      }
      final progress = step / totalSteps;
      final lat = from.latitude + (to.latitude - from.latitude) * progress;
      final lng = from.longitude + (to.longitude - from.longitude) * progress;
      setState(() => _saathiPosition = LatLng(lat, lng));
    });
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _animTimer?.cancel();
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ───────── Computed helpers ─────────

  LatLng get _pickupLatLng => _ride != null
      ? LatLng(_ride!.pickupLat, _ride!.pickupLng)
      : _mahuvaCenter;

  LatLng get _destinationLatLng => _ride != null
      ? LatLng(_ride!.destinationLat, _ride!.destinationLng)
      : _mahuvaCenter;

  bool get _isSearching =>
      _ride == null || _ride!.status == RideModel.searching;

  bool get _hasValidPickup =>
      _ride != null && _ride!.pickupLat != 0 && _ride!.pickupLng != 0;

  String get _statusText {
    switch (_ride?.status) {
      case RideModel.searching:
        return '🔍 ${AppStrings.searchingRide}';
      case RideModel.accepted:
        return '🛵 ${AppStrings.saathiOnWay}';
      case RideModel.arriving:
        return '📍 ${AppStrings.saathiArrived}';
      case RideModel.started:
        return '🚀 ${AppStrings.rideStarted}';
      default:
        return 'Ride Active';
    }
  }

  Color get _statusColor {
    switch (_ride?.status) {
      case RideModel.searching: return Colors.orange;
      case RideModel.accepted: return AppColors.primaryGreen;
      case RideModel.arriving: return Colors.blue;
      case RideModel.started: return AppColors.primaryGreen;
      default: return AppColors.primaryGreen;
    }
  }

  int get _etaMinutes {
    if (_saathiPosition == null) return 0;
    final pickup = _pickupLatLng;
    final dist = const Distance().as(
      LengthUnit.Kilometer,
      _saathiPosition!,
      pickup,
    );
    return (dist / 25 * 60).round().clamp(1, 60);
  }

  // ───────── Map layers ─────────

  List<Marker> get _markers {
    final markers = <Marker>[];

    // Customer / pickup marker — blue pin
    if (_hasValidPickup) {
      markers.add(Marker(
        point: _pickupLatLng,
        width: 48,
        height: 48,
        child: _CustomerMarker(),
      ));
    }

    // Destination marker — orange flag
    if (_ride != null &&
        _ride!.destinationLat != 0 &&
        _ride!.destinationLng != 0) {
      markers.add(Marker(
        point: _destinationLatLng,
        width: 48,
        height: 64,
        alignment: Alignment.bottomCenter,
        child: const _DestinationMarker(),
      ));
    }

    // Saathi marker — animated green bike
    if (_saathiPosition != null) {
      markers.add(Marker(
        point: _saathiPosition!,
        width: 52,
        height: 52,
        child: _SaathiMarker(
          saathiName: _ride?.saathiName ?? 'Saathi',
        ),
      ));
    }

    return markers;
  }

  List<Polyline> get _polylines {
    if (_saathiPosition == null || !_hasValidPickup) return [];
    return [
      Polyline(
        points: [_saathiPosition!, _pickupLatLng],
        color: AppColors.primaryGreen,
        strokeWidth: 3,
      ),
      if (_ride?.status == RideModel.started)
        Polyline(
          points: [_pickupLatLng, _destinationLatLng],
          color: AppColors.primaryGreen.withAlpha(120),
          strokeWidth: 2,
        ),
    ];
  }

  // ───────── Actions ─────────

  Future<void> _cancelRide() async {
    String? selectedReason;
    const reasons = [
      'Waiting too long',
      'Found another ride',
      'Saathi not responding',
      'Change of plans',
      'Wrong village selected',
      'Other',
    ];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Cancel Ride · સવારી રદ કરો',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 4),
              const Text("Please tell us why you're cancelling",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),
              ...reasons.map((r) => GestureDetector(
                    onTap: () => setModalState(() => selectedReason = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedReason == r
                            ? AppColors.bgGreen : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReason == r
                              ? AppColors.primaryGreen : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          selectedReason == r
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selectedReason == r
                              ? AppColors.primaryGreen : AppColors.textGrey,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(r,
                            style: TextStyle(
                                fontWeight: selectedReason == r
                                    ? FontWeight.bold : FontWeight.normal,
                                color: selectedReason == r
                                    ? AppColors.primaryGreen
                                    : AppColors.textDark)),
                      ]),
                    ),
                  )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep Ride',
                        style: TextStyle(color: AppColors.textDark)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: selectedReason != null
                        ? () => Navigator.pop(ctx, true) : null,
                    child: const Text('Cancel Ride',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await RideService.cancelRide(
          widget.rideId, selectedReason ?? 'Cancelled by customer');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _callSaathi() async {
    final phone = _ride?.saathiPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _showSOS() async {
    final contacts = await EmergencyContactService.getContacts();
    if (!mounted) return;

    if (contacts.isEmpty) {
      final uri = Uri(scheme: 'tel', path: '112');
      if (await canLaunchUrl(uri)) launchUrl(uri);
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.emergency, color: AppColors.sosRed, size: 20),
              SizedBox(width: 8),
              Text('SOS — Call for Help',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            ...contacts.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red[50], shape: BoxShape.circle),
                    child: const Icon(Icons.person,
                        color: AppColors.sosRed, size: 20),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(c.phone,
                      style: const TextStyle(color: AppColors.textGrey)),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sosRed,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    icon: const Icon(Icons.call, size: 14, color: Colors.white),
                    label: const Text('Call',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final uri = Uri(scheme: 'tel', path: c.phone);
                      if (await canLaunchUrl(uri)) launchUrl(uri);
                    },
                  ),
                )),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange[50], shape: BoxShape.circle),
                child: const Icon(Icons.local_police,
                    color: Colors.orange, size: 20),
              ),
              title: const Text('Emergency Services (112)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Police, Fire, Ambulance'),
              trailing: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.call, size: 14, color: Colors.white),
                label: const Text('Call 112',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri(scheme: 'tel', path: '112');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── Build ─────────

  @override
  Widget build(BuildContext context) {
    final saathiName = _ride?.saathiName ?? '—';
    final vehicleType = _ride?.vehicleType ?? '—';
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _ride == null,
        child: Stack(children: [
          // ── OpenStreetMap ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _hasValidPickup ? _pickupLatLng : _mahuvaCenter,
              initialZoom: 14,
              minZoom: 11,
              maxZoom: 17,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(_swBound, _neBound),
              ),
            ),
            children: [
              // OSM tile layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gaamride.app',
                maxZoom: 19,
              ),

              // Polyline: saathi → pickup (and pickup → destination when started)
              PolylineLayer(polylines: _polylines),

              // Markers: customer (blue), destination (orange), saathi (green)
              MarkerLayer(markers: _markers),
            ],
          ),

          // ── OSM attribution (required by OSM tile usage policy) ──
          Positioned(
            bottom: 180,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('© OpenStreetMap',
                  style: TextStyle(fontSize: 9, color: Colors.black54)),
            ),
          ),

          // ── Top overlay: status + SOS ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(4, topPad + 4, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(children: [
                // Back / cancel button
                BackButton(
                  color: Colors.white,
                  onPressed: _isSearching ? _cancelRide : null,
                ),

                // Status chip
                Expanded(
                  child: FadeTransition(
                    opacity: _pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor.withAlpha(220),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // SOS button
                GestureDetector(
                  onTap: _showSOS,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.sosRed,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppColors.sosRed.withAlpha(100),
                            blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                    child: const Text('SOS 🆘',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ),

          // ── Zoom controls (map-lock region awareness) ──
          Positioned(
            right: 12, bottom: 200,
            child: Column(children: [
              _mapBtn(Icons.add, () =>
                  _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom + 1).clamp(11, 17))),
              const SizedBox(height: 4),
              _mapBtn(Icons.remove, () =>
                  _mapController.move(
                      _mapController.camera.center,
                      (_mapController.camera.zoom - 1).clamp(11, 17))),
              const SizedBox(height: 4),
              _mapBtn(Icons.my_location, () {
                if (_hasValidPickup) {
                  _mapController.move(_pickupLatLng, 14);
                }
              }),
            ]),
          ),

          // ── Bottom info card ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomCard(
              ride: _ride,
              isSearching: _isSearching,
              statusText: _statusText,
              etaMinutes: _etaMinutes,
              hasSaathi: _saathiPosition != null,
              onCancel: _cancelRide,
              onCall: _callSaathi,
              bottomPad: bottomPad,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 6)],
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Marker widgets
// ─────────────────────────────────────────

class _CustomerMarker extends StatelessWidget {
  const _CustomerMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.blue.withAlpha(120), blurRadius: 10,
              spreadRadius: 2),
        ],
      ),
      child: const Icon(Icons.person_pin_circle,
          color: Colors.white, size: 26),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.primaryOrange.withAlpha(120),
                  blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
        ),
        // Pin tail
        Container(width: 2, height: 10,
            color: AppColors.primaryOrange),
      ],
    );
  }
}

class _SaathiMarker extends StatefulWidget {
  final String saathiName;
  const _SaathiMarker({required this.saathiName});

  @override
  State<_SaathiMarker> createState() => _SaathiMarkerState();
}

class _SaathiMarkerState extends State<_SaathiMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.9, end: 1.05).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _anim,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Name bubble
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.saathiName.split(' ').first,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        // Green bike icon
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(color: AppColors.primaryGreen.withAlpha(150),
                  blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.electric_rickshaw,
              color: Colors.white, size: 20),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// Bottom card
// ─────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final RideModel? ride;
  final bool isSearching;
  final String statusText;
  final int etaMinutes;
  final bool hasSaathi;
  final VoidCallback onCancel;
  final VoidCallback onCall;
  final double bottomPad;

  const _BottomCard({
    required this.ride,
    required this.isSearching,
    required this.statusText,
    required this.etaMinutes,
    required this.hasSaathi,
    required this.onCancel,
    required this.onCall,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),

        if (isSearching) ...[
          const RadarSearchingWidget(),
          const SizedBox(height: 12),
          const Text('ઓનલાઇન સાથી શોધી રહ્યા છે...',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const Text('Searching for available Saathi nearby',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 16, color: AppColors.error),
            label: const Text('Cancel Ride',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ] else ...[
          // Saathi info row
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.bgGreen,
              child: Text(
                (ride?.saathiName ?? '?').isNotEmpty
                    ? (ride?.saathiName ?? '?')[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride?.saathiName ?? '—',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(ride?.vehicleType ?? '—',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
              ],
            )),

            // ETA chip
            if (hasSaathi && etaMinutes > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Text('~$etaMinutes min',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                          fontSize: 13)),
                  const Text('ETA', style: TextStyle(
                      fontSize: 9, color: AppColors.textGrey)),
                ]),
              ),
              const SizedBox(width: 8),
            ],

            // Call button
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.call, color: AppColors.primaryGreen),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.bgGreen,
                shape: const CircleBorder(),
              ),
            ),
          ]),

          // OTP card (shown when Saathi has arrived)
          if (ride?.status == RideModel.arriving) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGreen),
              ),
              child: Column(children: [
                const Text('સાથીને આ OTP આપો',
                    style: TextStyle(fontSize: 14,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500)),
                const Text('Give this OTP to your Saathi',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 10),
                Text(
                  ride?.otp ?? '—',
                  style: const TextStyle(
                    fontSize: 42, fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen, letterSpacing: 14,
                  ),
                ),
              ]),
            ),
          ],

          // Route summary
          if (ride != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.circle, size: 8,
                          color: AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      Text(ride!.pickupVillage,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: Container(
                          width: 2, height: 14,
                          color: Colors.grey.shade300),
                    ),
                    Row(children: [
                      const Icon(Icons.location_on,
                          size: 10, color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Text(ride!.destinationVillage,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ],
                ),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${ride!.fare.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryGreen)),
                    Text('${ride!.distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textGrey)),
                  ],
                ),
              ]),
            ),
          ],
        ],
      ]),
    );
  }
}
