import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable full-screen, fully-interactive OpenStreetMap view used once a
/// ride's status becomes `started` — shared by the Customer ride-tracking
/// screen and the Saathi active-ride screen.
///
/// Features:
/// • 100% screen map — bottom card floats over, never squishes the map
/// • Auto-follow pauses the moment user drags; re-center FAB restores it
/// • Zoom +/− controls + "follow driver" re-center button
/// • Animated saathi marker with pulse ring
/// • Gradient scrim so back button is always readable
class FullscreenRideMap extends StatefulWidget {
  final LatLng saathiLatLng;
  final LatLng otherMarkerLatLng;
  final String saathiLabel;
  final String otherLabel;
  final Widget bottomCard;
  final String title;
  final VoidCallback? onBack;
  final IconData otherMarkerIcon;
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

class _FullscreenRideMapState extends State<FullscreenRideMap>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  /// When true, the map auto-pans to the saathi on every GPS update.
  /// Becomes false when the user manually drags the map.
  bool _autoFollow = true;

  // Pulse animation for the saathi dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 0.6, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void didUpdateWidget(covariant FullscreenRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-pan to saathi position only when user hasn't manually moved the map
    if (_autoFollow &&
        oldWidget.saathiLatLng != widget.saathiLatLng) {
      try {
        _mapController.move(
            widget.saathiLatLng, _mapController.camera.zoom);
      } catch (_) {
        // MapController not yet attached — ignore; initialCenter covers first frame
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    setState(() => _autoFollow = true);
    try {
      _mapController.move(widget.saathiLatLng, 15.5);
    } catch (_) {}
  }

  void _zoom(double delta) {
    try {
      final z =
          (_mapController.camera.zoom + delta).clamp(10.0, 19.0);
      _mapController.move(_mapController.camera.center, z);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ───────────────────────────────────────────────────────────────
        // FULL-SCREEN MAP — fills every pixel; bottom card floats OVER it
        // ───────────────────────────────────────────────────────────────
        SizedBox.expand(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.saathiLatLng,
              initialZoom: 15.5,
              maxZoom: 19.0,
              minZoom: 10.0,
              // All gestures enabled: pan, pinch-zoom, double-tap-zoom
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              // Pause auto-follow the moment user starts dragging.
              // We check `source` (not class type) for flutter_map v6 compat.
              onMapEvent: (MapEvent event) {
                if (!mounted || !_autoFollow) return;
                final src = event.source;
                // Whitelist non-user sources — everything else is a user gesture
                if (src == MapEventSource.mapController ||
                    src == MapEventSource.nonRotatedSizeChange ||
                    src == MapEventSource.initialization) return;
                setState(() => _autoFollow = false);
              },
            ),
            children: [
              // OSM tile layer
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gaamride.app',
                maxZoom: 19,
              ),

              // Polyline: saathi → other point
              PolylineLayer(polylines: [
                Polyline(
                  points: [
                    widget.saathiLatLng,
                    widget.otherMarkerLatLng
                  ],
                  color: const Color(0xFF00B4D8).withAlpha(180),
                  strokeWidth: 4.0,
                ),
              ]),

              // Markers
              MarkerLayer(markers: [
                // ── Other point (pickup / destination) ──
                Marker(
                  point: widget.otherMarkerLatLng,
                  width: 52,
                  height: 68,
                  alignment: Alignment.bottomCenter,
                  child: _OtherMarker(
                    icon: widget.otherMarkerIcon,
                    color: widget.otherMarkerColor,
                    label: widget.otherLabel,
                  ),
                ),

                // ── Saathi — animated pulse dot ──
                Marker(
                  point: widget.saathiLatLng,
                  width: 64,
                  height: 64,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => _SaathiDot(pulse: _pulseAnim.value),
                  ),
                ),
              ]),
            ],
          ),
        ),

        // ────────────────────────────────────────────────────────────
        // TOP GRADIENT SCRIM — ensures back button / title are readable
        // ────────────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topPad + 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(180),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Back button + title ──
        Positioned(
          top: topPad + 4,
          left: 0,
          right: 0,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed:
                  widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            // "Map moved" pill — visible only when auto-follow is paused
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _autoFollow
                  ? const SizedBox.shrink()
                  : Container(
                      key: const ValueKey('moved'),
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(220),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '📍 Map moved',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ]),
        ),

        // ────────────────────────────────────────────────────────────
        // RIGHT-SIDE FLOATING CONTROLS (above bottom card)
        // ────────────────────────────────────────────────────────────
        Positioned(
          right: 12,
          bottom: 210,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Re-center / follow-driver button (only when paused)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _autoFollow
                    ? const SizedBox(height: 0)
                    : Column(
                        key: const ValueKey('recenter'),
                        children: [
                          _FloatBtn(
                            icon: Icons.my_location,
                            color: const Color(0xFF00B4D8),
                            tooltip: 'Follow driver',
                            onTap: _recenter,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
              ),
              _FloatBtn(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onTap: () => _zoom(1)),
              const SizedBox(height: 6),
              _FloatBtn(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onTap: () => _zoom(-1)),
            ],
          ),
        ),

        // OSM attribution (required by tile usage policy)
        Positioned(
          bottom: 200,
          right: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(190),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('© OpenStreetMap',
                style: TextStyle(fontSize: 9, color: Colors.black54)),
          ),
        ),

        // ────────────────────────────────────────────────────────────
        // BOTTOM CARD — floats OVER the map, never squishes it
        // ────────────────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: widget.bottomCard,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// Saathi animated marker
// ─────────────────────────────────────────
class _SaathiDot extends StatelessWidget {
  final double pulse;
  const _SaathiDot({required this.pulse});

  @override
  Widget build(BuildContext context) {
    const outerSize = 64.0;
    const innerSize = 40.0;
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(alignment: Alignment.center, children: [
        // Pulse ring
        Container(
          width: outerSize * pulse,
          height: outerSize * pulse,
          decoration: BoxDecoration(
            color: const Color(0xFF00B4D8).withAlpha((60 * pulse).round()),
            shape: BoxShape.circle,
          ),
        ),
        // Inner vehicle dot
        Container(
          width: innerSize,
          height: innerSize,
          decoration: BoxDecoration(
            color: const Color(0xFF00B4D8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00B4D8).withAlpha(120),
                  blurRadius: 12,
                  spreadRadius: 2)
            ],
          ),
          child: const Icon(Icons.electric_scooter,
              color: Colors.white, size: 22),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// Other marker (pickup / destination)
// ─────────────────────────────────────────
class _OtherMarker extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _OtherMarker(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: color.withAlpha(80), blurRadius: 6)
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 2),
        Icon(icon, color: color, size: 38),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Floating map control button
// ─────────────────────────────────────────
class _FloatBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;
  const _FloatBtn(
      {required this.icon,
      required this.onTap,
      this.color,
      this.tooltip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 10,
                  spreadRadius: 1)
            ],
          ),
          child: Icon(icon,
              size: 20, color: color ?? Colors.grey.shade700),
        ),
      ),
    );
  }
}
