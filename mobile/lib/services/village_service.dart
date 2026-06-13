import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/village_model.dart';

class VillageService {
  static List<VillageModel>? _cached;

  static Future<List<VillageModel>> getVillages() async {
    if (_cached != null) return _cached!;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('villages')
          .where('isActive', isEqualTo: true)
          .get();
      if (snap.docs.isNotEmpty) {
        _cached = snap.docs.map((d) => VillageModel.fromFirestore(d)).toList();
        return _cached!;
      }
    } catch (_) {}
    _cached = VillageModel.fallbackVillages;
    return VillageModel.fallbackVillages;
  }

  static void clearCache() => _cached = null;

  static VillageModel nearest(double lat, double lng, List<VillageModel> villages) {
    VillageModel nearest = villages.first;
    double minDist = double.infinity;
    for (final v in villages) {
      final d = Geolocator.distanceBetween(lat, lng, v.lat, v.lng);
      if (d < minDist) {
        minDist = d;
        nearest = v;
      }
    }
    return nearest;
  }

  static double distanceBetween(VillageModel a, VillageModel b) {
    return Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);
  }
}
