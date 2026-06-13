import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/haul_booking_model.dart';
import '../utils/fare_calculator.dart';

class HaulService {
  static final _db = FirebaseFirestore.instance;
  static final _bookings = _db.collection('haul_bookings');
  static final _vehicles = _db.collection('haul_vehicles');

  static Future<String> createBooking({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String vehicleOwnerId,
    required String ownerName,
    required String ownerPhone,
    required String vehicleType,
    required String duration,
    required double durationHours,
    required String loadDescription,
    required String pickupVillage,
    required double pickupLat,
    required double pickupLng,
    required double ratePerHour,
  }) async {
    final ref = _bookings.doc();
    final ownerEarnings = FareCalculator.ownerEarnings(ratePerHour.toInt(), duration);
    await ref.set({
      'bookingId': ref.id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'vehicleOwnerId': vehicleOwnerId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'vehicleType': vehicleType,
      'duration': duration,
      'durationHours': durationHours,
      'loadDescription': loadDescription,
      'pickupVillage': pickupVillage,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'status': HaulBookingModel.searching,
      'appCommission': 75,
      'ownerEarnings': ownerEarnings,
      'ownerLat': 0.0,
      'ownerLng': 0.0,
      'cancelReason': '',
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': null,
      'completedAt': null,
    });
    return ref.id;
  }

  static Future<void> acceptBooking({
    required String bookingId,
    required String ownerId,
  }) async {
    await _bookings.doc(bookingId).update({
      'status': HaulBookingModel.accepted,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> startBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({'status': HaulBookingModel.started});
  }

  static Future<void> completeBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': HaulBookingModel.completed,
      'completedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _bookings.doc(bookingId).get();
    final ownerId = (snap.data() as Map)['vehicleOwnerId'] as String?;
    if (ownerId != null && ownerId.isNotEmpty) {
      await _vehicles.doc(ownerId).update({
        'totalBookings': FieldValue.increment(1),
      });
    }
  }

  static Future<void> cancelBooking(String bookingId, String reason) async {
    await _bookings.doc(bookingId).update({
      'status': HaulBookingModel.cancelled,
      'cancelReason': reason,
    });
  }

  static Future<void> updateOwnerLocation({
    required String bookingId,
    required double lat,
    required double lng,
  }) async {
    await _bookings.doc(bookingId).update({'ownerLat': lat, 'ownerLng': lng});
  }

  static Stream<DocumentSnapshot> watchBooking(String bookingId) {
    return _bookings.doc(bookingId).snapshots();
  }

  static Stream<QuerySnapshot> watchIncomingBookings() {
    return _bookings
        .where('status', isEqualTo: HaulBookingModel.searching)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  static Future<List<DocumentSnapshot>> getAvailableVehicles() async {
    final snap = await _vehicles
        .where('isAvailable', isEqualTo: true)
        .get();
    return snap.docs;
  }

  static Future<List<QueryDocumentSnapshot>> getCustomerHistory(String customerId) async {
    final snap = await _bookings
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs;
  }
}
