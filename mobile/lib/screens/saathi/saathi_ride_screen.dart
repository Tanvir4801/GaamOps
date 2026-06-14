import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../services/saathi_location_service.dart';

// Mahuva Taluka bounds
const _swBound = LatLng(20.78, 73.19);
const _neBound = LatLng(20.92, 73.32);
const _mahuvaCenter = LatLng(20.8394, 73.2637);

class SaathiRideScreen extends StatefulWidget {
  final RideModel ride;
  final VoidCallback onComplete;

  const SaathiRideScreen({
    super.key,
    required this.ride,
    required this.onComplete,
  });

  @override
  State<SaathiRideScreen> createState() => _SaathiRideScreenState();
}

class _SaathiRideScreenState extends State<SaathiRideScreen> {
  StreamSubscription? _rideSub;
  StreamSubscription<Position>? _gpsSub;
  RideModel? _ride;
  final MapController _mapController = MapController();
  final TextEditingController _otpController = TextEditingController();

  LatLng? _myPosition;   // Saathi's own live GPS position
  bool _isLoading = false;
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;

    // Listen to ride doc for status changes
    _rideSub = RideService.watchRide(widget.ride.rideId).listen((snap) {
      if (snap.exists && mounted) {
        setState(() => _ride = RideModel.fromFirestore(snap));
      }
    });

    // Start broadcasting + show own position on map
    _startLocationServices();
  }

  Future<void> _startLocationServices() async {
    final started = await SaathiLocationService.startTracking(widget.ride.rideId);
    if (!mounted) return;
    setState(() => _locationGranted = started);
    if (!started) return;

    // Also maintain a local stream to show Saathi's own dot on the map
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPosition = newPos);
      // Auto-pan map to follow Saathi during accepted phase
      if (_ride?.status == RideModel.accepted) {
        _mapController.move(newPos, _mapController.camera.zoom);
      }
    }, cancelOnError: false);

    // Get initial position immediately
    final init = await SaathiLocationService.getCurrentPosition();
    if (init != null && mounted) {
      setState(() => _myPosition = LatLng(init.latitude, init.longitude));
      _mapController.move(_myPosition!, 15);
    }
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _gpsSub?.cancel();
    _otpController.dispose();
    _mapController.dispose();
    SaathiLocationService.stopTracking();
    super.dispose();
  }

  // ───────── Map ─────────

  LatLng get _pickupLatLng =>
      LatLng(widget.ride.pickupLat, widget.ride.pickupLng);

  LatLng get _destLatLng =>
      LatLng(widget.ride.destinationLat, widget.ride.destinationLng);

  List<Marker> get _mapMarkers {
    final list = <Marker>[];

    // Customer / pickup — blue
    if (widget.ride.pickupLat != 0) {
      list.add(Marker(
        point: _pickupLatLng,
        width: 48, height: 64,
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(widget.ride.pickupVillage,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.blue.withAlpha(120), blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ]),
      ));
    }

    // Destination — orange flag
    if (widget.ride.destinationLat != 0) {
      list.add(Marker(
        point: _destLatLng,
        width: 48, height: 64,
        alignment: Alignment.bottomCenter,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(widget.ride.destinationVillage,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 2),
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
        ]),
      ));
    }

    // My position — green bike (YOU)
    if (_myPosition != null) {
      list.add(Marker(
        point: _myPosition!,
        width: 52, height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: AppColors.primaryGreen.withAlpha(180),
                  blurRadius: 12, spreadRadius: 3),
            ],
          ),
          child: const Icon(Icons.electric_rickshaw,
              color: Colors.white, size: 26),
        ),
      ));
    }

    return list;
  }

  List<Polyline> get _polylines {
    if (_myPosition == null) return [];
    final ride = _ride ?? widget.ride;
    if (ride.status == RideModel.accepted || ride.status == RideModel.arriving) {
      return [
        Polyline(
          points: [_myPosition!, _pickupLatLng],
          color: Colors.blue.shade600,
          strokeWidth: 3,
        ),
      ];
    }
    if (ride.status == RideModel.started) {
      return [
        Polyline(
          points: [_myPosition!, _destLatLng],
          color: AppColors.primaryGreen,
          strokeWidth: 3,
        ),
      ];
    }
    return [];
  }

  // ───────── Actions ─────────

  Future<void> _setLoading(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try { await action(); } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _arrived() =>
      _setLoading(() => RideService.saathiArrived(widget.ride.rideId));

  Future<void> _startRide() async {
    final otp = _otpController.text.trim();
    final correctOtp = (_ride ?? widget.ride).otp;
    if (otp != correctOtp) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Wrong OTP! Ask customer again.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    await _setLoading(() => RideService.startRide(widget.ride.rideId));
  }

  Future<void> _completeRide() async {
    await _setLoading(() async {
      await SaathiLocationService.stopTracking();
      await RideService.completeRide(widget.ride.rideId);
    });
    widget.onComplete();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel ride?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to cancel this ride?\n\nસવારી રદ કરશો?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, keep it'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _setLoading(() async {
        await SaathiLocationService.stopTracking();
        await RideService.cancelRide(widget.ride.rideId, 'Cancelled by saathi');
      });
      widget.onComplete();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _callCustomer() async {
    final phone = (_ride ?? widget.ride).customerPhone;
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _recenterMap() {
    if (_myPosition != null) {
      _mapController.move(_myPosition!, 15);
    } else if (widget.ride.pickupLat != 0) {
      _mapController.move(_pickupLatLng, 14);
    }
  }

  // ───────── Build ─────────

  @override
  Widget build(BuildContext context) {
    final ride = _ride ?? widget.ride;
    final isAccepted = ride.status == RideModel.accepted;
    final isArriving = ride.status == RideModel.arriving;
    final isStarted = ride.status == RideModel.started;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(children: [
        // ── OpenStreetMap ──
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.ride.pickupLat != 0
                ? _pickupLatLng : _mahuvaCenter,
            initialZoom: 14,
            minZoom: 11,
            maxZoom: 17,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(_swBound, _neBound),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gaamride.app',
              maxZoom: 19,
            ),
            PolylineLayer(polylines: _polylines),
            MarkerLayer(markers: _mapMarkers),
          ],
        ),

        // OSM attribution
        Positioned(
          bottom: 230, right: 8,
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

        // ── Top bar ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(8, topPad + 4, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
            child: Row(children: [
              BackButton(color: Colors.white, onPressed: () {}),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(ride.status),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    Text(
                      '${ride.pickupVillage} → ${ride.destinationVillage}',
                      style: TextStyle(
                          color: Colors.white.withAlpha(200), fontSize: 11),
                    ),
                  ],
                ),
              ),
              // GPS status dot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _locationGranted
                      ? AppColors.primaryGreen : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _locationGranted ? Icons.gps_fixed : Icons.gps_off,
                    color: Colors.white, size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _locationGranted ? 'Live' : 'GPS Off',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ]),
          ),
        ),

        // ── Zoom + recentre controls ──
        Positioned(
          right: 12, bottom: 230,
          child: Column(children: [
            _mapBtn(Icons.add, () => _mapController.move(
                _mapController.camera.center,
                (_mapController.camera.zoom + 1).clamp(11, 17))),
            const SizedBox(height: 4),
            _mapBtn(Icons.remove, () => _mapController.move(
                _mapController.camera.center,
                (_mapController.camera.zoom - 1).clamp(11, 17))),
            const SizedBox(height: 4),
            _mapBtn(Icons.my_location, _recenterMap),
          ]),
        ),

        // ── Bottom action card ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
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
              const SizedBox(height: 14),

              // Customer info row
              Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.bgGreen,
                  child: Text(
                    ride.customerName.isNotEmpty
                        ? ride.customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.customerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(ride.customerPhone,
                        style: const TextStyle(
                            color: AppColors.textGrey, fontSize: 12)),
                  ],
                )),
                // Fare
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹${ride.fare.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(width: 8),
                // Call customer button
                IconButton(
                  onPressed: _callCustomer,
                  icon: const Icon(Icons.call, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ]),

              const SizedBox(height: 12),

              // Route row
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
                        const Icon(Icons.circle,
                            size: 8, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(ride.pickupVillage,
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
                        const Icon(Icons.location_on,
                            size: 10, color: AppColors.primaryOrange),
                        const SizedBox(width: 4),
                        Text(ride.destinationVillage,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ],
                  )),
                  Text('${ride.distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          color: AppColors.textGrey, fontSize: 12)),
                ]),
              ),

              const SizedBox(height: 14),

              // Status-specific actions
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryGreen),
                )
              else if (isAccepted) ...[
                _actionButton(
                  label: 'I Have Arrived · પહોંચ્યો',
                  icon: Icons.location_on,
                  color: Colors.blue.shade700,
                  onTap: _arrived,
                ),
              ] else if (isArriving) ...[
                // OTP entry
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 10),
                  decoration: InputDecoration(
                    labelText: 'Customer OTP',
                    counterText: '',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGreen, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Start Ride · ચાલુ',
                  icon: Icons.play_circle,
                  color: AppColors.primaryGreen,
                  onTap: _startRide,
                ),
              ] else if (isStarted) ...[
                _actionButton(
                  label: 'Complete Ride · પૂર્ણ',
                  icon: Icons.check_circle,
                  color: AppColors.primaryGreen,
                  onTap: _completeRide,
                ),
              ],

              const SizedBox(height: 8),
              TextButton(
                onPressed: _cancelRide,
                child: const Text('Cancel Ride · રદ',
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        onPressed: onTap,
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
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 6)
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case RideModel.accepted: return '🛵 Heading to pickup · પિકઅપ પર જઈ રહ્યા છો';
      case RideModel.arriving: return '📍 You have arrived · પહોંચ્યા';
      case RideModel.started: return '🚀 Ride in progress · સવારી ચાલુ';
      default: return 'Ride Active';
    }
  }
}
