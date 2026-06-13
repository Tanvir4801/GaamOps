import 'package:cloud_firestore/cloud_firestore.dart';

class HaulVehicleModel {
  final String uid;
  final String ownerName;
  final String phone;
  final String village;
  final String vehicleType;
  final String capacity;
  final double ratePerHour;
  final String vehicleNumber;
  final bool isAvailable;
  final Map<String, dynamic>? position;
  final DateTime? lastSeen;
  final int totalBookings;
  final String fcmToken;
  final DateTime? createdAt;

  static const miniTempo = 'mini_tempo';
  static const pickup = 'pickup';
  static const tractor = 'tractor';
  static const truck407 = 'truck_407';

  const HaulVehicleModel({
    required this.uid,
    required this.ownerName,
    required this.phone,
    required this.village,
    required this.vehicleType,
    required this.capacity,
    required this.ratePerHour,
    required this.vehicleNumber,
    this.isAvailable = false,
    this.position,
    this.lastSeen,
    this.totalBookings = 0,
    this.fcmToken = '',
    this.createdAt,
  });

  factory HaulVehicleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return HaulVehicleModel(
      uid: d['uid'] ?? doc.id,
      ownerName: d['ownerName'] ?? '',
      phone: d['phone'] ?? '',
      village: d['village'] ?? '',
      vehicleType: d['vehicleType'] ?? '',
      capacity: d['capacity'] ?? '',
      ratePerHour: (d['ratePerHour'] ?? 0).toDouble(),
      vehicleNumber: d['vehicleNumber'] ?? '',
      isAvailable: d['isAvailable'] ?? false,
      position: d['position'] as Map<String, dynamic>?,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      totalBookings: (d['totalBookings'] ?? 0).toInt(),
      fcmToken: d['fcmToken'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get vehicleTypeLabel {
    switch (vehicleType) {
      case miniTempo: return 'Mini Tempo';
      case pickup: return 'Pickup';
      case tractor: return 'Tractor';
      case truck407: return '407 Truck';
      default: return vehicleType;
    }
  }
}
