import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MigrationService {
  static Future<void> runMigrations() async {
    if (!kDebugMode) return;

    await _fixVillageCoordinates();
    await _createAppSettings();
    await _mergeOldSaathiCollection();
    await _migrateBookingCollection();

    debugPrint('✅ GaamRide migrations complete');
  }

  static Future<void> _fixVillageCoordinates() async {
    final correctVillages = [
      {'id': 'anaval',     'name': 'Anaval',     'nameGu': 'આણવલ',    'lat': 20.8394, 'lng': 73.2637, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'kos',        'name': 'Kos',        'nameGu': 'કૉસ',     'lat': 20.8480, 'lng': 73.2350, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'tarkani',    'name': 'Tarkani',    'nameGu': 'તારકણી',  'lat': 20.8550, 'lng': 73.2580, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'angaldhara', 'name': 'Angaldhara', 'nameGu': 'અંગળધરા', 'lat': 20.8180, 'lng': 73.2280, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'dholikuva',  'name': 'Dholikuva',  'nameGu': 'ઢોળીકૂવા', 'lat': 20.8650, 'lng': 73.2800, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'lakhavadi',  'name': 'Lakhavadi',  'nameGu': 'લખાવડી',  'lat': 20.8050, 'lng': 73.2150, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'unai',       'name': 'Unai',       'nameGu': 'ઉનાઈ',    'lat': 20.8550, 'lng': 73.2100, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'doldha',     'name': 'Doldha',     'nameGu': 'ડોળધા',   'lat': 20.7950, 'lng': 73.2600, 'isActive': true, 'taluka': 'Mahuva'},
      {'id': 'kamboya',    'name': 'Kamboya',    'nameGu': 'કાંબોયા', 'lat': 20.8750, 'lng': 73.2200, 'isActive': true, 'taluka': 'Mahuva'},
    ];
    final batch = FirebaseFirestore.instance.batch();
    for (final v in correctVillages) {
      final ref = FirebaseFirestore.instance.collection('villages').doc(v['id'] as String);
      batch.set(ref, v, SetOptions(merge: true));
    }
    await batch.commit();
    debugPrint('✅ Villages fixed');
  }

  static Future<void> _createAppSettings() async {
    final ref = FirebaseFirestore.instance.collection('app_settings').doc('config');
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set({
      'rideFareBase': 20,
      'rideFarePerKm': 8,
      'rideFareMinimum': 25,
      'rideFareMaximum': 200,
      'haulCommission': 75,
      'serviceZoneSW': {'lat': 20.780, 'lng': 73.190},
      'serviceZoneNE': {'lat': 20.920, 'lng': 73.320},
      'maintenanceMode': false,
      'appVersion': '1.0.0',
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ App settings created');
  }

  static Future<void> _mergeOldSaathiCollection() async {
    final oldDocs = await FirebaseFirestore.instance.collection('saathi').get();
    if (oldDocs.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in oldDocs.docs) {
      final data = doc.data();
      final phone = data['phone'] as String? ?? doc.id;
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (usersQuery.docs.isNotEmpty) {
        final uid = usersQuery.docs.first.id;
        final newRef = FirebaseFirestore.instance.collection('saathis').doc(uid);
        batch.set(newRef, {
          ...data,
          'uid': uid,
          'isAvailable': data['isAvailable'] ?? false,
          'isOnline': data['isOnline'] ?? false,
          'rating': ((data['rating'] ?? 5) as num).toDouble(),
          'totalRides': data['totalRides'] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
    debugPrint('✅ Old saathi merged into saathis');
  }

  static Future<void> _migrateBookingCollection() async {
    final oldBookings = await FirebaseFirestore.instance.collection('bookings').get();
    if (oldBookings.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in oldBookings.docs) {
      final data = doc.data();
      final type = data['type'] as String? ?? 'ride';
      if (type == 'ride') {
        final ref = FirebaseFirestore.instance.collection('rides').doc(doc.id);
        batch.set(ref, {
          'rideId': doc.id,
          'customerId': data['userId'] ?? data['customerId'] ?? '',
          'customerName': data['customerName'] ?? '',
          'customerPhone': data['customerPhone'] ?? '',
          'saathiId': data['assignedDriverId'] ?? '',
          'saathiName': data['saathiName'] ?? '',
          'saathiPhone': data['saathiPhone'] ?? '',
          'pickupVillage': data['pickupVillage'] ?? '',
          'pickupLat': data['pickupLat'] ?? 0.0,
          'pickupLng': data['pickupLng'] ?? 0.0,
          'destinationVillage': data['destinationVillage'] ?? '',
          'destinationLat': data['destinationLat'] ?? 0.0,
          'destinationLng': data['destinationLng'] ?? 0.0,
          'status': data['status'] ?? 'cancelled',
          'fare': data['fare'] ?? 0,
          'distance': data['distance'] ?? 0,
          'otp': data['otp'] ?? '',
          'saathiLat': 0.0,
          'saathiLng': 0.0,
          'cancelReason': data['cancelReason'] ?? '',
          'rating': data['rating'] ?? 0,
          'createdAt': data['createdAt'],
          'migratedFrom': 'bookings',
        }, SetOptions(merge: true));
      } else if (type == 'haul') {
        final ref = FirebaseFirestore.instance.collection('haul_bookings').doc(doc.id);
        batch.set(ref, {
          'bookingId': doc.id,
          'customerId': data['userId'] ?? '',
          'customerName': data['customerName'] ?? '',
          'customerPhone': data['customerPhone'] ?? '',
          'vehicleOwnerId': data['assignedDriverId'] ?? '',
          'vehicleType': data['vehicleType'] ?? '',
          'duration': data['duration'] ?? '1h',
          'durationHours': data['durationHours'] ?? 1,
          'loadDescription': data['loadDescription'] ?? '',
          'pickupVillage': data['pickupVillage'] ?? '',
          'pickupLat': data['pickupLat'] ?? 0.0,
          'pickupLng': data['pickupLng'] ?? 0.0,
          'status': data['status'] ?? 'cancelled',
          'appCommission': 75,
          'ownerEarnings': data['ownerEarnings'] ?? 0,
          'ownerLat': 0.0,
          'ownerLng': 0.0,
          'cancelReason': data['cancelReason'] ?? '',
          'createdAt': data['createdAt'],
          'migratedFrom': 'bookings',
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
    debugPrint('✅ Old bookings migrated');
  }
}
