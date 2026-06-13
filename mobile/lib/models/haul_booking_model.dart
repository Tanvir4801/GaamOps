import 'package:cloud_firestore/cloud_firestore.dart';

class HaulBookingModel {
  final String bookingId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String vehicleOwnerId;
  final String ownerName;
  final String ownerPhone;
  final String vehicleType;
  final String duration;
  final double durationHours;
  final String loadDescription;
  final String pickupVillage;
  final double pickupLat;
  final double pickupLng;
  final String status;
  final double appCommission;
  final double ownerEarnings;
  final double ownerLat;
  final double ownerLng;
  final String cancelReason;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  static const searching = 'searching';
  static const accepted = 'accepted';
  static const started = 'started';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const duration1h = '1h';
  static const duration2h = '2h';
  static const durationHalfDay = 'half_day';
  static const durationFullDay = 'full_day';

  const HaulBookingModel({
    required this.bookingId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.vehicleOwnerId,
    required this.ownerName,
    required this.ownerPhone,
    required this.vehicleType,
    required this.duration,
    required this.durationHours,
    required this.loadDescription,
    required this.pickupVillage,
    required this.pickupLat,
    required this.pickupLng,
    required this.status,
    this.appCommission = 75,
    this.ownerEarnings = 0,
    this.ownerLat = 0,
    this.ownerLng = 0,
    this.cancelReason = '',
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  factory HaulBookingModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return HaulBookingModel(
      bookingId: d['bookingId'] ?? doc.id,
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      customerPhone: d['customerPhone'] ?? '',
      vehicleOwnerId: d['vehicleOwnerId'] ?? '',
      ownerName: d['ownerName'] ?? '',
      ownerPhone: d['ownerPhone'] ?? '',
      vehicleType: d['vehicleType'] ?? '',
      duration: d['duration'] ?? '1h',
      durationHours: (d['durationHours'] ?? 1).toDouble(),
      loadDescription: d['loadDescription'] ?? '',
      pickupVillage: d['pickupVillage'] ?? '',
      pickupLat: (d['pickupLat'] ?? 0).toDouble(),
      pickupLng: (d['pickupLng'] ?? 0).toDouble(),
      status: d['status'] ?? searching,
      appCommission: (d['appCommission'] ?? 75).toDouble(),
      ownerEarnings: (d['ownerEarnings'] ?? 0).toDouble(),
      ownerLat: (d['ownerLat'] ?? 0).toDouble(),
      ownerLng: (d['ownerLng'] ?? 0).toDouble(),
      cancelReason: d['cancelReason'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
    );
  }
     String get vehicleTypeLabel {
  switch (vehicleType.toLowerCase()) {
    case 'tractor':
      return 'Tractor';
    case 'tempo':
      return 'Tempo';
    case 'pickup':
      return 'Pickup';
    case 'truck':
      return 'Truck';
    default:
      return vehicleType;
  }
}

  String get durationLabel {
    switch (duration) {
      case '1h': return '1 Hour';
      case '2h': return '2 Hours';
      case 'half_day': return 'Half Day (4h)';
      case 'full_day': return 'Full Day (8h)';
      default: return duration;
    }
  }
}
  