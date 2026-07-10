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
import '../../widgets/fullscreen_ride_map.dart';
import 'ride_complete_screen.dart';
import 'ride_summary_screen.dart';

// Mahuva Taluka service area
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
  // ─── State ───
  StreamSubscription? _rideSub;
  RideModel? _ride;
  final MapController _mapController = MapController();

  // Saathi position — animated with 30-step interpolation
  LatLng? _saathiPosition;
  Timer? _animTimer;

  // Rapido-style live countdown
  int _etaSeconds = 0;           // counts down every second
  Timer? _countdownTimer;        // ticks every 1 s
  bool _etaInitialised = false;  // prevent resetting on tiny GPS jitter

  // Status pill pulse
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Map auto-follow Saathi
  bool _userMovedMap = false;    // if user drags map, stop auto-follow

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.75, end: 1.0).animate(_pulseCtrl);

    _rideSub = RideService.watchRide(widget.rideId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final ride = RideModel.fromFirestore(snap);
      setState(() => _ride = ride);

      // Saathi position update → animate + recalculate ETA
      if (ride.saathiLat != 0 && ride.saathiLng != 0) {
        final newPos = LatLng(ride.saathiLat, ride.saathiLng);
        final prev = _saathiPosition ?? newPos;
        _animateSaathiTo(prev, newPos);
        _recalculateEta(newPos);

        // Auto-pan to Saathi if user hasn't manually moved the map
        if (!_userMovedMap) {
          _mapController.move(newPos, _mapController.camera.zoom);
        }
      }

      // Payment confirmed — covers new (paymentConfirmedBySaathi) and
      // legacy docs (paymentStatus already 'paid'/'collected').
      final paymentDone = ride.paymentConfirmedBySaathi ||
          ride.paymentStatus == RideModel.paymentPaid ||
          ride.paymentStatus == RideModel.paymentCollected;
      if (ride.status == RideModel.completed && paymentDone) {
        _rideSub?.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => RideSummaryScreen(ride: ride)),
            (r) => r.isFirst,
          );
        }
      }
      // Ride completed but waiting for saathi to confirm → stay on screen
      // (handled by _buildWaitingForPayment in build())
    });
  }

  // ─── Smooth 30-step linear interpolation ───
  void _animateSaathiTo(LatLng from, LatLng to) {
    _animTimer?.cancel();
    const steps = 30;
    int step = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      step++;
      if (!mounted) { t.cancel(); return; }
      if (step >= steps) {
        t.cancel();
        setState(() => _saathiPosition = to);
        return;
      }
      final p = step / steps;
      setState(() => _saathiPosition = LatLng(
        from.latitude + (to.latitude - from.latitude) * p,
        from.longitude + (to.longitude - from.longitude) * p,
      ));
    });
  }

  // ─── Rapido-style live countdown ───
  void _recalculateEta(LatLng saathiPos) {
    final pickup = _pickupLatLng;
    final distKm = const Distance().as(LengthUnit.Kilometer, saathiPos, pickup);
    final seconds = ((distKm / 25) * 3600).round().clamp(10, 3600);

    // Only hard-reset if difference is > 30 s (ignore small GPS jitter)
    if (!_etaInitialised || (seconds - _etaSeconds).abs() > 30) {
      _etaSeconds = seconds;
      _etaInitialised = true;
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_etaSeconds > 0) _etaSeconds--;
      });
    });
  }

  String get _etaText {
    if (_etaSeconds <= 0) return 'Arriving…';
    final m = _etaSeconds ~/ 60;
    final s = _etaSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _animTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─── Computed helpers ───

  LatLng get _pickupLatLng => _ride != null
      ? LatLng(_ride!.pickupLat, _ride!.pickupLng) : _mahuvaCenter;

  LatLng get _destinationLatLng => _ride != null
      ? LatLng(_ride!.destinationLat, _ride!.destinationLng) : _mahuvaCenter;

  bool get _isSearching =>
      _ride == null || _ride!.status == RideModel.searching;

  bool get _hasValidPickup =>
      _ride != null && _ride!.pickupLat != 0 && _ride!.pickupLng != 0;

  bool get _saathiMoving =>
      _saathiPosition != null &&
      (_ride?.status == RideModel.accepted ||
          _ride?.status == RideModel.arriving);

  String get _statusText {
    switch (_ride?.status) {
      case RideModel.searching: return '🔍 ${AppStrings.searchingRide}';
      case RideModel.accepted:  return '🛵 ${AppStrings.saathiOnWay}';
      case RideModel.arriving:  return '📍 ${AppStrings.saathiArrived}';
      case RideModel.started:   return '🚀 ${AppStrings.rideStarted}';
      default: return 'Ride Active';
    }
  }

  Color get _statusColor {
    switch (_ride?.status) {
      case RideModel.searching: return Colors.orange;
      case RideModel.accepted:  return AppColors.primaryGreen;
      case RideModel.arriving:  return Colors.blue;
      case RideModel.started:   return AppColors.primaryGreen;
      default: return AppColors.primaryGreen;
    }
  }

  // ─── Map layers ───

  List<Marker> get _markers {
    final list = <Marker>[];

    // Customer / pickup — blue
    if (_hasValidPickup) {
      list.add(Marker(
        point: _pickupLatLng,
        width: 48, height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(color: Colors.blue.withAlpha(130), blurRadius: 10,
                  spreadRadius: 2)
            ],
          ),
          child: const Icon(Icons.person_pin_circle,
              color: Colors.white, size: 26),
        ),
      ));
    }

    // Destination — orange flag
    if (_ride != null && _ride!.destinationLat != 0) {
      list.add(Marker(
        point: _destinationLatLng,
        width: 48, height: 64,
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: AppColors.primaryOrange.withAlpha(100),
                    blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
          ),
          Container(width: 2, height: 10, color: AppColors.primaryOrange),
        ]),
      ));
    }

    // Saathi — animated green bike
    if (_saathiPosition != null) {
      list.add(Marker(
        point: _saathiPosition!,
        width: 64, height: 70,
        child: _SaathiDot(name: _ride?.saathiName ?? ''),
      ));
    }

    return list;
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
          color: AppColors.primaryGreen.withAlpha(100),
          strokeWidth: 2,
        ),
    ];
  }

  // ─── Actions ───

  Future<void> _cancelRide() async {
    String? reason;
    const reasons = [
      'Waiting too long',
      'Found another ride',
      'Saathi not responding',
      'Change of plans',
      'Wrong village selected',
      'Other',
    ];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Cancel Ride · સવારી રદ કરો',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 4),
              const Text("Please tell us why you're cancelling",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              const SizedBox(height: 16),
              ...reasons.map((r) => GestureDetector(
                onTap: () => set(() => reason = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: reason == r ? AppColors.bgGreen : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: reason == r
                        ? AppColors.primaryGreen : Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    Icon(
                      reason == r ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: reason == r
                          ? AppColors.primaryGreen : AppColors.textGrey,
                      size: 18),
                    const SizedBox(width: 10),
                    Text(r, style: TextStyle(
                        fontWeight: reason == r
                            ? FontWeight.bold : FontWeight.normal,
                        color: reason == r
                            ? AppColors.primaryGreen : AppColors.textDark)),
                  ]),
                ),
              )),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep Ride',
                      style: TextStyle(color: AppColors.textDark)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: reason != null
                      ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Cancel Ride',
                      style: TextStyle(color: Colors.white)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );

    if (ok == true && mounted) {
      await RideService.cancelRide(
          widget.rideId, reason ?? 'Cancelled by customer');
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
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.emergency, color: AppColors.sosRed, size: 20),
              SizedBox(width: 8),
              Text('SOS — Call for Help',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    // ── Ride completed, waiting for saathi to confirm payment ──
    // Also handles legacy docs: if status==completed but paymentStatus is
    // already 'paid'/'collected', skip the waiting screen entirely.
    if (_ride != null && _ride!.status == RideModel.completed) {
      final paymentDone = _ride!.paymentConfirmedBySaathi ||
          _ride!.paymentStatus == RideModel.paymentPaid ||
          _ride!.paymentStatus == RideModel.paymentCollected;
      if (!paymentDone) return _buildWaitingForPayment(context);
      // paymentDone==true but stream hasn't fired navigate yet — fallthrough
      // to preStarted (blank) momentarily; the listener will navigate away.
    }
    // ── After ride starts: dedicated full-screen, fully-interactive map ──
    if (_ride != null && _ride!.status == RideModel.started) {
      return _buildFullscreenStarted(context);
    }
    return _buildPreStarted(context);
  }

  // ─── Waiting for saathi to confirm payment ───
  Widget _buildWaitingForPayment(BuildContext context) {
    final ride = _ride!;
    final isCash = ride.paymentMethod == RideModel.paymentCash;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, topPad + 32, 24, bottomPad + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing money icon
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: isCash
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFDBEAFE),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: (isCash
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF1D4ED8))
                          .withAlpha(40),
                      blurRadius: 20,
                      spreadRadius: 4),
                ],
              ),
              child: Icon(
                isCash ? Icons.payments_rounded : Icons.qr_code_2_rounded,
                size: 44,
                color: isCash
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF1D4ED8),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Ride complete!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            Text(
              isCash
                  ? 'Waiting for ${ride.saathiName.isNotEmpty ? ride.saathiName : 'saathi'} to confirm cash receipt…'
                  : 'Waiting for ${ride.saathiName.isNotEmpty ? ride.saathiName : 'saathi'} to confirm UPI payment…',
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Fare
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(8), blurRadius: 12),
                ],
              ),
              child: Text(
                '₹${ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                    letterSpacing: -1),
              ),
            ),

            const SizedBox(height: 12),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen)),
              const SizedBox(width: 8),
              Text(
                '${ride.pickupVillage} → ${ride.destinationVillage}',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textGrey),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Full-screen map once the ride has started ───
  Widget _buildFullscreenStarted(BuildContext context) {
    final ride = _ride!;
    final saathiPos = _saathiPosition ?? _pickupLatLng;
    return FullscreenRideMap(
      saathiLatLng: saathiPos,
      otherMarkerLatLng: _pickupLatLng,
      saathiLabel: ride.saathiName,
      otherLabel: 'Your pickup',
      title: 'Ride in progress',
      otherMarkerIcon: Icons.person_pin_circle,
      otherMarkerColor: Colors.blue.shade600,
      bottomCard: _StartedBottomCard(
        saathiName: ride.saathiName,
        vehicleType: ride.vehicleType,
        rideCode: ride.customerRideCode,
        onSOS: _showSOS,
      ),
    );
  }

  // ─── Existing UI, unchanged: searching / accepted / arriving / otp ───
  Widget _buildPreStarted(BuildContext context) {
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
              onMapEvent: (ev) {
                // Disable auto-follow when user manually pans/zooms
                // MapEventSource.mapController = programmatic; everything else = user gesture
                if (ev is MapEventMove &&
                    ev.source != MapEventSource.mapController) {
                  _userMovedMap = true;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gaamride.app',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),

          // OSM attribution (required)
          Positioned(
            bottom: 190, right: 8,
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

          // ── Top: status + SOS ──
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
                BackButton(
                  color: Colors.white,
                  onPressed: _isSearching ? _cancelRide : null,
                ),
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
                      child: Text(_statusText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // SOS
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

          // ── Re-center + Re-follow button (shows when user moved map) ──
          if (_userMovedMap && _saathiPosition != null)
            Positioned(
              top: topPad + 70, right: 16,
              child: GestureDetector(
                onTap: () {
                  setState(() => _userMovedMap = false);
                  _mapController.move(_saathiPosition!, 15);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(30),
                          blurRadius: 6)
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.my_location,
                        size: 14, color: AppColors.primaryGreen),
                    SizedBox(width: 4),
                    Text('Follow Saathi',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen)),
                  ]),
                ),
              ),
            ),

          // ── Zoom controls ──
          Positioned(
            right: 12, bottom: 210,
            child: Column(children: [
              _mapBtn(Icons.add, () => _mapController.move(
                  _mapController.camera.center,
                  (_mapController.camera.zoom + 1).clamp(11, 17))),
              const SizedBox(height: 4),
              _mapBtn(Icons.remove, () => _mapController.move(
                  _mapController.camera.center,
                  (_mapController.camera.zoom - 1).clamp(11, 17))),
            ]),
          ),

          // ── Bottom info card ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomCard(
              ride: _ride,
              isSearching: _isSearching,
              hasSaathi: _saathiPosition != null,
              etaText: _etaText,
              etaSeconds: _etaSeconds,
              saathiMoving: _saathiMoving,
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
          boxShadow: [BoxShadow(
              color: Colors.black.withAlpha(30), blurRadius: 6)],
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Saathi marker — pulsing green bike dot
// ─────────────────────────────────────────

class _SaathiDot extends StatefulWidget {
  final String name;
  const _SaathiDot({required this.name});

  @override
  State<_SaathiDot> createState() => _SaathiDotState();
}

class _SaathiDotState extends State<_SaathiDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.93, end: 1.07).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 6, end: 16).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.name.split(' ').first;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ScaleTransition(
        scale: _scale,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Name bubble — first name only, ellipsis if long
          Container(
            constraints: const BoxConstraints(maxWidth: 60),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          // Green bike icon with animated glow
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryGreen.withAlpha(160),
                    blurRadius: _glow.value,
                    spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.electric_rickshaw,
                color: Colors.white, size: 18),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Bottom info card — shown once ride status == started
// ─────────────────────────────────────────

class _StartedBottomCard extends StatelessWidget {
  final String saathiName;
  final String vehicleType;
  final String rideCode;
  final VoidCallback onSOS;

  const _StartedBottomCard({
    required this.saathiName,
    required this.vehicleType,
    required this.rideCode,
    required this.onSOS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Row 1 — Saathi name + vehicle
        Row(children: [
          Expanded(
            child: Text('$saathiName · $vehicleType',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis),
          ),
          // Row 2 — status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Ride started 🟢',
                style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        // Row 3 — Ride Code reference
        Row(children: [
          const Text('Ride Code: ',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          Text(rideCode,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 4)),
          const Spacer(),
          // Row 4 — SOS button
          GestureDetector(
            onTap: onSOS,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.sosRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('SOS 🆘',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// Bottom info card
// ─────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final RideModel? ride;
  final bool isSearching;
  final bool hasSaathi;
  final bool saathiMoving;
  final String etaText;
  final int etaSeconds;
  final VoidCallback onCancel;
  final VoidCallback onCall;
  final double bottomPad;

  const _BottomCard({
    required this.ride,
    required this.isSearching,
    required this.hasSaathi,
    required this.saathiMoving,
    required this.etaText,
    required this.etaSeconds,
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
          // ── Searching state ──
          const RadarSearchingWidget(),
          const SizedBox(height: 12),
          const Text('ઓનલાઇન સાથી શોધી રહ્યા છે…',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
          const Text('Searching for an available Saathi nearby',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 16, color: AppColors.error),
            label: const Text('Cancel Ride',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ] else ...[
          // ── Rapido-style countdown hero ──
          if (saathiMoving) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGreen, Color(0xFF1B5E20)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saathi arriving in',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      // Live countdown digits
                      Text(
                        etaText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: -0.5),
                      ),
                    ],
                  ),
                  const Column(children: [
                    Icon(Icons.electric_rickshaw,
                        color: Colors.white, size: 36),
                    Text('Live', style: TextStyle(
                        color: Colors.white70, fontSize: 10)),
                  ]),
                ],
              ),
            ),
          ],

          // ── Saathi info row ──
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.bgGreen,
              child: Text(
                (ride?.saathiName ?? '?').isNotEmpty
                    ? (ride?.saathiName ?? '?')[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ride?.saathiName ?? '—',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Row(children: [
                  const Icon(Icons.electric_rickshaw,
                      size: 13, color: AppColors.textGrey),
                  const SizedBox(width: 4),
                  Text(ride?.vehicleType ?? '—',
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 12)),
                ]),
              ],
            )),

            // Call button
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.call, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
              ),
            ),
          ]),

          // ── OTP card (arriving status) ──
          if (ride?.status == RideModel.arriving) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgGreen,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGreen),
              ),
              child: Column(children: [
                const Text('સાથીને Ride Code આપો',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w500)),
                const Text('Share your Ride Code with Saathi',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 10),
                Text(ride?.customerRideCode ?? '—',
                    style: const TextStyle(
                      fontSize: 42, fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      letterSpacing: 14,
                    )),
              ]),
            ),
          ],

          // ── Route + fare strip ──
          if (ride != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          width: 2, height: 12,
                          color: Colors.grey.shade300),
                    ),
                    Row(children: [
                      const Icon(Icons.location_on, size: 10,
                          color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Text(ride!.destinationVillage,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${ride!.fare.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryGreen)),
                    Text('${ride!.distance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textGrey)),
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
