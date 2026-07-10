import 'package:cloud_firestore/cloud_firestore.dart';

class RideModel {
  final String rideId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String saathiId;
  final String saathiName;
  final String saathiPhone;
  final String targetSaathiId;
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
  final String paymentMethod;
  final String paymentStatus;
  final bool paymentConfirmedBySaathi;
  final String paymentId;
  final String razorpayOrderId;
  /// Permanent 4-digit customer ride code (from customer profile).
  /// Falls back to legacy per-ride 'otp' for historical documents.
  final String customerRideCode;
  final double baseFare;
  final double distanceCharge;
  final double surgeMultiplier;
  final double lateNightFee;
  final double gstAmount;
  final double platformFee;
  final double promoDiscount;
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

  static const paymentCash = 'cash';
  static const paymentUpi = 'upi';          // legacy — prefer paymentUpiDirect
  static const paymentUpiDirect = 'upi_direct';
  static const paymentPending = 'pending';
  static const paymentPaid = 'paid';         // legacy — prefer paymentCollected
  static const paymentCollected = 'collected';

  const RideModel({
    required this.rideId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.saathiId,
    required this.saathiName,
    required this.saathiPhone,
    this.targetSaathiId = '',
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
    this.paymentMethod = paymentCash,
    this.paymentStatus = paymentPending,
    this.paymentConfirmedBySaathi = false,
    this.paymentId = '',
    this.razorpayOrderId = '',
    this.customerRideCode = '',
    this.baseFare = 0,
    this.distanceCharge = 0,
    this.surgeMultiplier = 1.0,
    this.lateNightFee = 0,
    this.gstAmount = 0,
    this.platformFee = 0,
    this.promoDiscount = 0,
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
      targetSaathiId: d['targetSaathiId'] ?? '',
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
      paymentMethod: d['paymentMethod'] ?? paymentCash,
      paymentStatus: d['paymentStatus'] ?? paymentPending,
      paymentConfirmedBySaathi: d['paymentConfirmedBySaathi'] == true,
      paymentId: d['paymentId'] ?? '',
      razorpayOrderId: d['razorpayOrderId'] ?? '',
      // Prefer new field; fall back to legacy per-ride otp for old documents
      customerRideCode: d['customerRideCode'] as String? ??
          d['otp'] as String? ?? '',
      baseFare: (d['baseFare'] ?? 0).toDouble(),
      distanceCharge: (d['distanceCharge'] ?? 0).toDouble(),
      surgeMultiplier: (d['surgeMultiplier'] ?? 1.0).toDouble(),
      lateNightFee: (d['lateNightFee'] ?? 0).toDouble(),
      gstAmount: (d['gstAmount'] ?? 0).toDouble(),
      platformFee: (d['platformFee'] ?? 0).toDouble(),
      promoDiscount: (d['promoDiscount'] ?? 0).toDouble(),
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
        'targetSaathiId': targetSaathiId,
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
        'customerRideCode': customerRideCode,
        'saathiLat': saathiLat,
        'saathiLng': saathiLng,
        'cancelReason': cancelReason,
        'rating': rating,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'paymentId': paymentId,
        'razorpayOrderId': razorpayOrderId,
        'baseFare': baseFare,
        'distanceCharge': distanceCharge,
        'surgeMultiplier': surgeMultiplier,
        'lateNightFee': lateNightFee,
        'gstAmount': gstAmount,
        'platformFee': platformFee,
        'promoDiscount': promoDiscount,
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
        'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      };
}
