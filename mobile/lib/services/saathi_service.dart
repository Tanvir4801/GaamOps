import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class SaathiService {
  static final _saathis = FirebaseFirestore.instance.collection('saathis');

  static Future<void> goOnline(String uid) async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final geoPoint = GeoFirePoint(GeoPoint(pos.latitude, pos.longitude));
    await _saathis.doc(uid).update({
      'isAvailable': true,
      'isOnline': true,
      'position': geoPoint.data,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> goOffline(String uid) async {
    await _saathis.doc(uid).update({
      'isAvailable': false,
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateLocation(String uid, double lat, double lng) async {
    final geoPoint = GeoFirePoint(GeoPoint(lat, lng));
    await _saathis.doc(uid).update({
      'position': geoPoint.data,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Future<DocumentSnapshot> getSaathi(String uid) {
    return _saathis.doc(uid).get();
  }

  static Stream<DocumentSnapshot> watchSaathi(String uid) {
    return _saathis.doc(uid).snapshots();
  }

  static Future<List<DocumentSnapshot>> getAvailableSaathis() async {
    final snap = await _saathis
        .where('isAvailable', isEqualTo: true)
        .where('isOnline', isEqualTo: true)
        .where('isBlocked', isEqualTo: false)
        .get();
    return snap.docs;
  }

  static Future<void> updateFcmToken(String uid, String token) async {
    await _saathis.doc(uid).update({'fcmToken': token});
  }
}
