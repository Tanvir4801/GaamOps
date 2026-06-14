import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';

class RideService {
  static final _rides = FirebaseFirestore.instance.collection('rides');

  static Future<String> createRide({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String pickupVillage,
    required double pickupLat,
    required double pickupLng,
    required String destinationVillage,
    required double destinationLat,
    required double destinationLng,
    required double fare,
    required double distance,
    String paymentMethod = RideModel.paymentCash,
    double baseFare = 0,
    double distanceCharge = 0,
    double surgeMultiplier = 1.0,
    double lateNightFee = 0,
    double gstAmount = 0,
    double platformFee = 0,
    double promoDiscount = 0,
  }) async {
    final ref = _rides.doc();
    final otp = (1000 + Random().nextInt(9000)).toString();
    await ref.set({
      'rideId': ref.id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'saathiId': '',
      'saathiName': '',
      'saathiPhone': '',
      'pickupVillage': pickupVillage,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destinationVillage': destinationVillage,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'status': RideModel.searching,
      'fare': fare,
      'distance': distance,
      'otp': otp,
      'saathiLat': 0.0,
      'saathiLng': 0.0,
      'cancelReason': '',
      'rating': 0,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentMethod == RideModel.paymentUpi
          ? RideModel.paymentPaid
          : RideModel.paymentPending,
      'baseFare': baseFare,
      'distanceCharge': distanceCharge,
      'surgeMultiplier': surgeMultiplier,
      'lateNightFee': lateNightFee,
      'gstAmount': gstAmount,
      'platformFee': platformFee,
      'promoDiscount': promoDiscount,
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': null,
      'startedAt': null,
      'completedAt': null,
    });
    return ref.id;
  }

  static Future<void> acceptRide({
    required String rideId,
    required String saathiId,
    required String saathiName,
    required String saathiPhone,
  }) async {
    await _rides.doc(rideId).update({
      'saathiId': saathiId,
      'saathiName': saathiName,
      'saathiPhone': saathiPhone,
      'status': RideModel.accepted,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> saathiArrived(String rideId) async {
    await _rides.doc(rideId).update({'status': RideModel.arriving});
  }

  static Future<void> startRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideModel.started,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideModel.completed,
      'completedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _rides.doc(rideId).get();
    final saathiId = (snap.data() as Map)['saathiId'] as String?;
    if (saathiId != null && saathiId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('saathis')
          .doc(saathiId)
          .update({'totalRides': FieldValue.increment(1)});
    }
  }

  static Future<void> cancelRide(String rideId, String reason) async {
    await _rides.doc(rideId).update({
      'status': RideModel.cancelled,
      'cancelReason': reason,
    });
  }

  static Future<void> updateSaathiLocation({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    await _rides.doc(rideId).update({'saathiLat': lat, 'saathiLng': lng});
  }

  static Future<void> rateRide({
    required String rideId,
    required String saathiId,
    required int rating,
    required int totalRides,
    required double currentRating,
  }) async {
    await _rides.doc(rideId).update({'rating': rating});
    final newAvg = ((currentRating * totalRides) + rating) / (totalRides + 1);
    await FirebaseFirestore.instance
        .collection('saathis')
        .doc(saathiId)
        .update({'rating': newAvg});
  }

  static Future<void> submitRating({
    required String rideId,
    required String saathiId,
    required double rating,
    List<String> tags = const [],
  }) async {
    await _rides.doc(rideId).update({'rating': rating, 'ratingTags': tags});
    final saathiDoc = await FirebaseFirestore.instance
        .collection('saathis')
        .doc(saathiId)
        .get();
    if (saathiDoc.exists) {
      final data = saathiDoc.data()!;
      final currentRating = (data['rating'] ?? 5.0).toDouble();
      final totalRides = (data['totalRides'] ?? 1).toInt();
      final newAvg = ((currentRating * totalRides) + rating) / (totalRides + 1);
      await FirebaseFirestore.instance
          .collection('saathis')
          .doc(saathiId)
          .update({'rating': newAvg});
    }
  }

  static Stream<DocumentSnapshot> watchRide(String rideId) {
    return _rides.doc(rideId).snapshots();
  }

  static Stream<QuerySnapshot> watchIncomingRides() {
    return _rides
        .where('status', isEqualTo: RideModel.searching)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  static Future<List<QueryDocumentSnapshot>> getCustomerHistory(String customerId) async {
    final snap = await _rides
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    return snap.docs;
  }

  static Future<List<QueryDocumentSnapshot>> getSaathiHistory(String saathiId) async {
    final snap = await _rides
        .where('saathiId', isEqualTo: saathiId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    return snap.docs;
  }

  static Future<Map<String, dynamic>> getSaathiEarnings(String saathiId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 6));

    final snap = await _rides
        .where('saathiId', isEqualTo: saathiId)
        .where('status', isEqualTo: RideModel.completed)
        .get();

    double todayEarnings = 0;
    double weekEarnings = 0;
    double monthEarnings = 0;
    int todayRides = 0;

    // 7-day daily breakdown: index 0 = 6 days ago, index 6 = today
    final List<double> dailyEarnings = List.filled(7, 0.0);
    final List<int> dailyRides = List.filled(7, 0);

    // Collect recent rides for the trips list (sorted by completedAt desc)
    final allRides = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((d) => d['completedAt'] != null)
        .toList()
      ..sort((a, b) {
        final aT = (a['completedAt'] as Timestamp).toDate();
        final bT = (b['completedAt'] as Timestamp).toDate();
        return bT.compareTo(aT);
      });

    for (final data in allRides) {
      final fare = (data['fare'] ?? 0).toDouble();
      final completedAt = (data['completedAt'] as Timestamp).toDate();

      if (completedAt.isAfter(monthStart)) monthEarnings += fare;
      if (completedAt.isAfter(weekStart)) weekEarnings += fare;
      if (completedAt.isAfter(todayStart)) {
        todayEarnings += fare;
        todayRides++;
      }

      // Daily breakdown for last 7 days
      if (completedAt.isAfter(sevenDaysAgo.subtract(const Duration(seconds: 1)))) {
        final completedDay = DateTime(completedAt.year, completedAt.month, completedAt.day);
        final daysDiff = todayStart.difference(completedDay).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
          dailyEarnings[6 - daysDiff] += fare;
          dailyRides[6 - daysDiff]++;
        }
      }
    }

    return {
      'today': todayEarnings,
      'week': weekEarnings,
      'month': monthEarnings,
      'todayRides': todayRides,
      'totalRides': snap.docs.length,
      'dailyEarnings': dailyEarnings,
      'dailyRides': dailyRides,
      'recentRides': allRides.take(5).toList(),
    };
  }
}
