import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable full-screen, fully-interactive OpenStreetMap view used once a
/// ride's status becomes `started` — shared by the Customer ride-tracking
/// screen and the Saathi active-ride screen.
///
/// Always pass a floating [bottomCard] (it is stacked over the map, it does
/// NOT resize/push the map).
class FullscreenRideMap extends StatefulWidget {
  /// Live position of the Saathi (driver). Updates should be passed down
  /// from the parent's Firestore / GPS stream.
  final LatLng saathiLatLng;

  /// The other point of interest: customer pickup (customer's view of the
  /// map) or destination (Saathi's view of the map).
  final LatLng otherMarkerLatLng;

  /// Label under/near the Saathi marker — e.g. "Saathi" or the driver name.
  final String saathiLabel;

  /// Label for the other marker — e.g. "Your pickup" or "Destination".
  final String otherLabel;

  /// Floating card shown at the bottom, over the map.
  final Widget bottomCard;

  /// Title shown in the transparent app bar.
  final String title;

  /// Called when the back arrow is tapped. If null, pops the route.
  final VoidCallback? onBack;

  /// Icon used for the "other" marker — e.g. a person icon for the
  /// customer's pickup point (Saathi view) or a flag for the destination
  /// (Saathi's own view).
  final IconData otherMarkerIcon;

  /// Color of the "other" marker.
  final Color otherMarkerColor;

  const FullscreenRideMap({
    super.key,
    required this.saathiLatLng,
    required this.otherMarkerLatLng,
    required this.bottomCard,
    this.saathiLabel = 'Saathi',
    this.otherLabel = '',
    this.title = 'Ride in progress',
    this.onBack,
    this.otherMarkerIcon = Icons.location_pin,
    this.otherMarkerColor = Colors.blue,
  });

  @override
  State<FullscreenRideMap> createState() => _FullscreenRideMapState();
}

class _FullscreenRideMapState extends State<FullscreenRideMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant FullscreenRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saathiLatLng != widget.saathiLatLng) {
      try {
        _mapController.move(widget.saathiLatLng, _mapController.camera.zoom);
      } catch (_) {
        // MapController not attached yet — ignore, initialCenter covers it.
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // ── Full-screen, fully interactive map ──
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.saathiLatLng,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gaamride.app',
                  maxZoom: 19,
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: [widget.saathiLatLng, widget.otherMarkerLatLng],
                    color: Colors.green.withAlpha(160),
                    strokeWidth: 3,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: widget.saathiLatLng,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.electric_scooter,
                          color: Colors.white, size: 26),
                    ),
                  ),
                  Marker(
                    point: widget.otherMarkerLatLng,
                    width: 44,
                    height: 44,
                    child: Icon(widget.otherMarkerIcon,
                        color: widget.otherMarkerColor, size: 44),
                  ),
                ]),
              ],
            ),
          ),

          // OSM attribution (required by tile usage policy)
          Positioned(
            bottom: 168,
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

          // ── Floating bottom card (does NOT push the map) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: widget.bottomCard,
          ),
        ],
      ),
    );
  }
}
