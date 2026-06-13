import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String rideId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String saathiId;
  final String saathiName;
  final String saathiPhone;
  final String pickupVillage;
  final double pickupLat;
  final double pickupLng;
  final String destinationVillage;
  final double destinationLat;
  final double destinationLng;
  final String status;
  final double fare;
  final double distance;
  final String otp;
  final double saathiLat;
  final double saathiLng;
  final String vehicleType;
  final double? distanceMeters;
  final String cancelReason;
  final int rating;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  static const searching = 'searching';
  static const accepted = 'accepted';
  static const arriving = 'arriving';
  static const started = 'started';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  const RideModel({
    required this.rideId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.saathiId,
    required this.saathiName,
    required this.saathiPhone,
    required this.pickupVillage,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationVillage,
    required this.destinationLat,
    required this.destinationLng,
    required this.status,
    required this.fare,
    required this.distance,
    required this.otp,
    this.vehicleType = '',
    this.distanceMeters,
    this.saathiLat = 0,
    this.saathiLng = 0,
    this.cancelReason = '',
    this.rating = 0,
    this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
  });

  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RideModel(
      rideId: d['rideId'] ?? doc.id,
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      saathiId: d['saathiId'] ?? '',
      saathiName: d['saathiName'] ?? '',
      saathiPhone: d['saathiPhone'] ?? '',
      pickupVillage: d['pickupVillage'] ?? '',
      pickupLat: (d['pickupLat'] ?? 0).toDouble(),
      pickupLng: (d['pickupLng'] ?? 0).toDouble(),
      destinationVillage: d['destinationVillage'] ?? '',
      destinationLat: (d['destinationLat'] ?? 0).toDouble(),
      destinationLng: (d['destinationLng'] ?? 0).toDouble(),
      status: d['status'] ?? searching,
      fare: (d['fare'] ?? 0).toDouble(),
      distance: (d['distance'] ?? 0).toDouble(),
      otp: d['otp'] ?? '',
      saathiLat: (d['saathiLat'] ?? 0).toDouble(),
      saathiLng: (d['saathiLng'] ?? 0).toDouble(),
      vehicleType: d['vehicleType'] ?? '',
      distanceMeters: (d['distanceMeters'] ?? d['distance'])?.toDouble(),
      cancelReason: d['cancelReason'] ?? '',
      rating: (d['rating'] ?? 0).toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
      startedAt: (d['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'rideId': rideId,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'saathiId': saathiId,
        'saathiName': saathiName,
        'saathiPhone': saathiPhone,
        'pickupVillage': pickupVillage,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'destinationVillage': destinationVillage,
        'destinationLat': destinationLat,
        'destinationLng': destinationLng,
        'status': status,
        'fare': fare,
        'distance': distance,
        'otp': otp,
        'saathiLat': saathiLat,
        'saathiLng': saathiLng,
        'cancelReason': cancelReason,
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
        'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };
}
