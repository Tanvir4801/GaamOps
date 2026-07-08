import 'package:cloud_firestore/cloud_firestore.dart';

class SaathiModel {
  final String uid;
  final String name;
  final String phone;
  final String village;
  final String vehicleType;
  final String vehicleNumber;
  final bool isAvailable;
  final bool isOnline;
  final bool isBlocked;
  final Map<String, dynamic>? position;
  final DateTime? lastSeen;
  final double rating;
  final int totalRides;
  final String fcmToken;
  final String upiId;
  final String upiName;
  final double totalEarnings;
  final DateTime? createdAt;

  const SaathiModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.village,
    required this.vehicleType,
    required this.vehicleNumber,
    this.isAvailable = false,
    this.isOnline = false,
    this.isBlocked = false,
    this.position,
    this.lastSeen,
    this.rating = 5.0,
    this.totalRides = 0,
    this.fcmToken = '',
    this.upiId = '',
    this.upiName = '',
    this.totalEarnings = 0.0,
    this.createdAt,
  });

  factory SaathiModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SaathiModel(
      uid: d['uid'] ?? doc.id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      village: d['village'] ?? '',
      vehicleType: d['vehicleType'] ?? '',
      vehicleNumber: d['vehicleNumber'] ?? '',
      isAvailable: d['isAvailable'] ?? false,
      isOnline: d['isOnline'] ?? false,
      isBlocked: d['isBlocked'] ?? false,
      position: d['position'] as Map<String, dynamic>?,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      rating: (d['rating'] ?? 5.0).toDouble(),
      totalRides: (d['totalRides'] ?? 0).toInt(),
      fcmToken: d['fcmToken'] ?? '',
      upiId: d['upiId'] as String? ?? '',
      upiName: d['upiName'] as String? ?? '',
      totalEarnings: (d['totalEarnings'] ?? 0.0).toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get ratingStars {
    final full = rating.floor();
    return '⭐' * full;
  }
}
