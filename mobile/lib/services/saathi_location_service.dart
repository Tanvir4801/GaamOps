import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'ride_service.dart';

/// Broadcasts Saathi's live GPS position to Firestore every time the device
/// moves ≥ 3 m, AND forces a push every 4 s even if stationary.
/// Start when ride is accepted; stop on complete/cancel.
class SaathiLocationService {
  static StreamSubscription<Position>? _positionSub;
  static Timer? _heartbeat;
  static Position? _lastKnownPosition;
  static bool _isTracking = false;

  static bool get isTracking => _isTracking;

  /// Request permissions and start broadcasting to [rideId].
  static Future<bool> startTracking(String rideId) async {
    await stopTracking();

    // Permission check
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }

    // Is location service enabled?
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    _isTracking = true;

    // 1. Stream: push every time device moves ≥ 3 m (very responsive)
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // metres — same aggressiveness as Rapido/Ola
        timeLimit: Duration(seconds: 10),
      ),
    ).listen(
      (pos) {
        _lastKnownPosition = pos;
        _push(rideId, pos);
      },
      onError: (_) {},
      cancelOnError: false,
    );

    // 2. Heartbeat: force-push every 4 s even if stationary
    //    (keeps the ETA countdown accurate on the customer side)
    _heartbeat = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        _lastKnownPosition = pos;
        _push(rideId, pos);
      } catch (_) {
        // If fresh position fails, reuse last known
        if (_lastKnownPosition != null) {
          _push(rideId, _lastKnownPosition!);
        }
      }
    });

    return true;
  }

  static Future<void> stopTracking() async {
    _isTracking = false;
    await _positionSub?.cancel();
    _positionSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _lastKnownPosition = null;
  }

  static void _push(String rideId, Position pos) {
    // Fire-and-forget — don't await so we never block the GPS stream
    RideService.updateSaathiLocation(
      rideId: rideId,
      lat: pos.latitude,
      lng: pos.longitude,
    );
  }

  /// One-shot: get current position (for initial placement).
  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
