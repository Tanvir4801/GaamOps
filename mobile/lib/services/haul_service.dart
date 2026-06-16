import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/haul_booking_model.dart';
import '../models/haul_vehicle_model.dart';
import '../utils/fare_calculator.dart';

class HaulService {
  static final _db       = FirebaseFirestore.instance;
  static final _bookings = _db.collection('haul_bookings');
  static final _vehicles = _db.collection('haul_vehicles');

  // ── Booking lifecycle ──────────────────────────────────────

  static Future<String> createBooking({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String vehicleOwnerId,
    required String ownerName,
    required String ownerPhone,
    required String vehicleType,
    required String vehicleNumber,
    required String duration,
    required double durationHours,
    required String loadDescription,
    required String pickupVillage,
    required double pickupLat,
    required double pickupLng,
    required double ratePerHour,
  }) async {
    final ref = _bookings.doc();
    final ownerEarnings =
        FareCalculator.ownerEarnings(ratePerHour.toInt(), duration);
    await ref.set({
      'bookingId':      ref.id,
      'customerId':     customerId,
      'customerName':   customerName,
      'customerPhone':  customerPhone,
      'vehicleOwnerId': vehicleOwnerId,
      'ownerName':      ownerName,
      'ownerPhone':     ownerPhone,
      'vehicleType':    vehicleType,
      'vehicleNumber':  vehicleNumber,
      'duration':       duration,
      'durationHours':  durationHours,
      'ratePerHour':    ratePerHour,
      'loadDescription': loadDescription,
      'pickupVillage':  pickupVillage,
      'pickupLat':      pickupLat,
      'pickupLng':      pickupLng,
      'status':         HaulBookingModel.searching,
      'appCommission':  75,
      'ownerEarnings':  ownerEarnings,
      'ownerLat':       0.0,
      'ownerLng':       0.0,
      'cancelReason':   '',
      'createdAt':      FieldValue.serverTimestamp(),
      'acceptedAt':     null,
      'startedAt':      null,
      'completedAt':    null,
    });
    return ref.id;
  }

  static Future<void> acceptBooking({
    required String bookingId,
    required String ownerId,
  }) async {
    await _bookings.doc(bookingId).update({
      'status':     HaulBookingModel.accepted,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> startBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status':    HaulBookingModel.started,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status':      HaulBookingModel.completed,
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
      'status':       HaulBookingModel.cancelled,
      'cancelReason': reason,
    });
  }

  // ── Location ───────────────────────────────────────────────

  static Future<void> updateOwnerLocation({
    required String bookingId,
    required double lat,
    required double lng,
  }) async {
    await _bookings.doc(bookingId).update({'ownerLat': lat, 'ownerLng': lng});
  }

  // ── Streams ────────────────────────────────────────────────

  static Stream<DocumentSnapshot> watchBooking(String bookingId) =>
      _bookings.doc(bookingId).snapshots();

  static Stream<QuerySnapshot> watchIncomingBookings(String ownerId) =>
      _bookings
          .where('vehicleOwnerId', isEqualTo: ownerId)
          .where('status', isEqualTo: HaulBookingModel.searching)
          .limit(5)
          .snapshots();

  static Stream<DocumentSnapshot> watchOwnerVehicle(String ownerId) =>
      _vehicles.doc(ownerId).snapshots();

  // ── Owner vehicle management ───────────────────────────────

  static Future<void> updateVehicleAvailability(
      String ownerId, bool isAvailable) async {
    await _vehicles.doc(ownerId).update({'isAvailable': isAvailable});
  }

  static Future<HaulVehicleModel?> getOwnerVehicle(String ownerId) async {
    final doc = await _vehicles.doc(ownerId).get();
    if (!doc.exists) return null;
    return HaulVehicleModel.fromFirestore(doc);
  }

  // ── Earnings / history ─────────────────────────────────────

  static Future<Map<String, dynamic>> getOwnerEarningsToday(
      String ownerId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end   = start.add(const Duration(days: 1));
    final snap  = await _bookings
        .where('vehicleOwnerId', isEqualTo: ownerId)
        .where('status', isEqualTo: HaulBookingModel.completed)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('completedAt', isLessThan: Timestamp.fromDate(end))
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      total += (d['ownerEarnings'] ?? 0).toDouble();
    }
    return {'today': total, 'count': snap.docs.length};
  }

  // ── Vehicles & customer history ────────────────────────────

  static Future<List<DocumentSnapshot>> getAvailableVehicles({
    String? vehicleType,
  }) async {
    Query query = _vehicles.where('isAvailable', isEqualTo: true);
    if (vehicleType != null && vehicleType.isNotEmpty) {
      query = query.where('vehicleType', isEqualTo: vehicleType);
    }
    final snap = await query.get();
    return snap.docs;
  }

  static Future<List<QueryDocumentSnapshot>> getCustomerHistory(
      String customerId) async {
    final snap = await _bookings
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    return snap.docs;
  }

  static Future<List<QueryDocumentSnapshot>> getOwnerHistory(
      String ownerId) async {
    final snap = await _bookings
        .where('vehicleOwnerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    return snap.docs;
  }
}
