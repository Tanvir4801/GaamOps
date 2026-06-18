import 'package:cloud_firestore/cloud_firestore.dart';

class HaulVehicleModel {
  final String uid;
  final String ownerName;
  final String phone;
  final String village;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final String capacity;
  final double ratePerHour;
  final String vehicleNumber;
  final bool isAvailable;
  final bool isOnline;
  final bool isBlocked;
  final bool isVerified;
  final Map<String, dynamic>? position;
  final DateTime? lastSeen;
  final int totalBookings;
  final double rating;
  final String fcmToken;
  final DateTime? createdAt;

  // Document URLs
  final String profilePhotoUrl;
  final String dlFrontUrl;
  final String dlBackUrl;
  final String rcUrl;
  final String vehiclePhotoUrl;
  final String insuranceUrl;
  final String pucUrl;

  // Payment (optional)
  final String upiId;
  final String bankAccount;
  final String ifsc;

  // Status: pending | approved | active | rejected | blocked
  final String status;
  final String rejectionReason;

  static const chhotaHathi = 'chhota_hathi';
  static const tataAceGold = 'tata_ace_gold_cng';
  static const mahindraJeeto = 'mahindra_jeeto';
  static const ashokLeylandDost = 'ashok_leyland_dost';
  static const marutiSuperCarry = 'maruti_super_carry';
  static const boleroPickup = 'bolero_pickup';
  static const tataYodha = 'tata_yodha';
  static const eicherTruck = 'eicher_truck';
  static const tractor = 'tractor';
  static const cargoTempo = 'cargo_tempo';
  static const cngCargo = 'cng_cargo';
  static const other = 'other';

  const HaulVehicleModel({
    required this.uid,
    required this.ownerName,
    required this.phone,
    required this.village,
    required this.vehicleType,
    this.vehicleBrand = '',
    this.vehicleModel = '',
    this.capacity = '',
    this.ratePerHour = 0,
    this.vehicleNumber = '',
    this.isAvailable = false,
    this.isOnline = false,
    this.isBlocked = false,
    this.isVerified = false,
    this.position,
    this.lastSeen,
    this.totalBookings = 0,
    this.rating = 5.0,
    this.fcmToken = '',
    this.createdAt,
    this.profilePhotoUrl = '',
    this.dlFrontUrl = '',
    this.dlBackUrl = '',
    this.rcUrl = '',
    this.vehiclePhotoUrl = '',
    this.insuranceUrl = '',
    this.pucUrl = '',
    this.upiId = '',
    this.bankAccount = '',
    this.ifsc = '',
    this.status = 'pending',
    this.rejectionReason = '',
  });

  factory HaulVehicleModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return HaulVehicleModel(
      uid:             d['uid'] ?? doc.id,
      ownerName:       d['ownerName'] ?? '',
      phone:           d['phone'] ?? '',
      village:         d['village'] ?? '',
      vehicleType:     d['vehicleType'] ?? '',
      vehicleBrand:    d['vehicleBrand'] ?? '',
      vehicleModel:    d['vehicleModel'] ?? '',
      capacity:        d['capacity'] ?? '',
      ratePerHour:     (d['ratePerHour'] ?? 0).toDouble(),
      vehicleNumber:   d['vehicleNumber'] ?? '',
      isAvailable:     d['isAvailable'] ?? false,
      isOnline:        d['isOnline'] ?? false,
      isBlocked:       d['isBlocked'] ?? false,
      isVerified:      d['isVerified'] ?? false,
      position:        d['position'] as Map<String, dynamic>?,
      lastSeen:        (d['lastSeen'] as Timestamp?)?.toDate(),
      totalBookings:   (d['totalBookings'] ?? 0).toInt(),
      rating:          (d['rating'] ?? 5.0).toDouble(),
      fcmToken:        d['fcmToken'] ?? '',
      createdAt:       (d['createdAt'] as Timestamp?)?.toDate(),
      profilePhotoUrl: d['profilePhotoUrl'] ?? '',
      dlFrontUrl:      d['dlFrontUrl'] ?? '',
      dlBackUrl:       d['dlBackUrl'] ?? '',
      rcUrl:           d['rcUrl'] ?? '',
      vehiclePhotoUrl: d['vehiclePhotoUrl'] ?? '',
      insuranceUrl:    d['insuranceUrl'] ?? '',
      pucUrl:          d['pucUrl'] ?? '',
      upiId:           d['upiId'] ?? '',
      bankAccount:     d['bankAccount'] ?? '',
      ifsc:            d['ifsc'] ?? '',
      status:          d['status'] ?? 'pending',
      rejectionReason: d['rejectionReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid, 'ownerName': ownerName, 'phone': phone,
    'village': village, 'vehicleType': vehicleType,
    'vehicleBrand': vehicleBrand, 'vehicleModel': vehicleModel,
    'capacity': capacity, 'ratePerHour': ratePerHour,
    'vehicleNumber': vehicleNumber, 'isAvailable': isAvailable,
    'isOnline': isOnline, 'isBlocked': isBlocked, 'isVerified': isVerified,
    'totalBookings': totalBookings, 'rating': rating, 'fcmToken': fcmToken,
    'profilePhotoUrl': profilePhotoUrl, 'dlFrontUrl': dlFrontUrl,
    'dlBackUrl': dlBackUrl, 'rcUrl': rcUrl,
    'vehiclePhotoUrl': vehiclePhotoUrl, 'insuranceUrl': insuranceUrl,
    'pucUrl': pucUrl, 'upiId': upiId, 'bankAccount': bankAccount,
    'ifsc': ifsc, 'status': status, 'rejectionReason': rejectionReason,
  };

  String get vehicleTypeLabel {
    switch (vehicleType) {
      case chhotaHathi:      return 'Chhota Hathi / Tata Ace';
      case tataAceGold:      return 'Tata Ace Gold CNG';
      case mahindraJeeto:    return 'Mahindra Jeeto';
      case ashokLeylandDost: return 'Ashok Leyland Dost';
      case marutiSuperCarry: return 'Maruti Super Carry';
      case boleroPickup:     return 'Bolero Pickup';
      case tataYodha:        return 'Tata Yodha Pickup';
      case eicherTruck:      return 'Eicher Truck';
      case tractor:          return 'Tractor';
      case cargoTempo:       return 'Cargo Tempo';
      case cngCargo:         return 'CNG Cargo Vehicle';
      default:               return vehicleType.isNotEmpty ? vehicleType : 'Other';
    }
  }

  String get vehicleTypeEmoji {
    switch (vehicleType) {
      case chhotaHathi:
      case tataAceGold:
      case mahindraJeeto:
      case ashokLeylandDost:
      case marutiSuperCarry:
        return '🚚';
      case boleroPickup:
      case tataYodha:
        return '🛻';
      case eicherTruck:    return '🚛';
      case tractor:        return '🚜';
      case cargoTempo:     return '📦';
      case cngCargo:       return '⛽';
      default:             return '🚛';
    }
  }

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved' || status == 'active';
  bool get isRejected => status == 'rejected';
}
