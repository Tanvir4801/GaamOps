import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/radar_searching_widget.dart';
import 'ride_complete_screen.dart';
import 'emergency_contacts_screen.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  StreamSubscription? _sub;
  RideModel? _ride;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _sub = RideService.watchRide(widget.rideId).listen((snap) {
      if (snap.exists && mounted) {
        final ride = RideModel.fromFirestore(snap);
        setState(() {
          _ride = ride;
          _updateMarkers(ride);
        });
        if (ride.status == RideModel.completed) {
          _sub?.cancel();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => RideCompleteScreen(ride: ride)),
            (route) => route.isFirst,
          );
        }
      }
    });
  }

  void _updateMarkers(RideModel ride) {
    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(ride.pickupLat, ride.pickupLng),
        infoWindow: InfoWindow(title: 'Pickup: ${ride.pickupVillage}'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(ride.destinationLat, ride.destinationLng),
        infoWindow: InfoWindow(title: 'Destination: ${ride.destinationVillage}'),
      ),
      if (ride.saathiLat != 0)
        Marker(
          markerId: const MarkerId('saathi'),
          position: LatLng(ride.saathiLat, ride.saathiLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: '🛵 ${ride.saathiName}'),
        ),
    };
  }

  String get _statusText {
    switch (_ride?.status) {
      case RideModel.searching:
        return '🔍 ' + AppStrings.searchingRide;
      case RideModel.accepted:
        return '🛵 ' + AppStrings.saathiOnWay;
      case RideModel.arriving:
        return '📍 ' + AppStrings.saathiArrived;
      case RideModel.started:
        return '🚀 ' + AppStrings.rideStarted;
      default:
        return 'Ride Active';
    }
  }

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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Cancel Ride · સવારી રદ કરો',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 4),
              const Text('Please tell us why you\'re cancelling',
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
                            ? AppColors.bgGreen
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedReason == r
                              ? AppColors.primaryGreen
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == r
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selectedReason == r
                                ? AppColors.primaryGreen
                                : AppColors.textGrey,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(r,
                              style: TextStyle(
                                  fontWeight: selectedReason == r
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: selectedReason == r
                                      ? AppColors.primaryGreen
                                      : AppColors.textDark)),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 12),
              Row(
                children: [
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
                          ? () => Navigator.pop(ctx, true)
                          : null,
                      child: const Text('Cancel Ride',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
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

  void _callSaathi() async {
    if (_ride?.saathiPhone == null) return;
    final uri = Uri(scheme: 'tel', path: _ride!.saathiPhone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _showSOS() async {
    final contacts = await EmergencyContactsScreen.getContacts();

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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emergency, color: AppColors.sosRed, size: 20),
                SizedBox(width: 8),
                Text('SOS — Call for Help',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            ...contacts.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.person, color: AppColors.sosRed, size: 20),
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
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching =
        _ride?.status == RideModel.searching || _ride == null;
    final saathiName = _ride?.saathiName ?? '—';
    final vehicleType = _ride?.vehicleType ?? '—';

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _ride == null,
        child: Stack(
          children: [
            if (_ride != null && _ride!.pickupLat != 0)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_ride!.pickupLat, _ride!.pickupLng),
                  zoom: 14,
                ),
                markers: _markers,
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              )
            else
              Container(color: AppColors.bgGreen),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    4, MediaQuery.of(context).padding.top + 4, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    BackButton(
                      color: Colors.white,
                      onPressed: isSearching ? _cancelRide : null,
                    ),
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showSOS,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.sosRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'SOS 🆘',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isSearching) ...[
                      const SizedBox(height: 8),
                      const RadarSearchingWidget(),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _cancelRide,
                        icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                        label: const Text('Cancel Ride',
                            style: TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.bgGreen,
                            child: Text(
                              saathiName.isNotEmpty
                                  ? saathiName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  saathiName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$vehicleType · ${_statusText.replaceAll(RegExp(r'[^\x00-\x7F]+'), '').trim()}',
                                  style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _callSaathi,
                            icon: const Icon(Icons.call,
                                color: AppColors.primaryGreen),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.bgGreen,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                      if (_ride?.status == RideModel.arriving) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgGreen,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.primaryGreen),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'સાથીને આ OTP આપો',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w500),
                              ),
                              const Text(
                                'Give this OTP to Saathi',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textGrey),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _ride?.otp ?? '—',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                  letterSpacing: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
