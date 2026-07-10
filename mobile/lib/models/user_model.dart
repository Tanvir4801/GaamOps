import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String displayName;
  final String phone;
  final String role;
  final String village;
  final String profilePhoto;
  final String fcmToken;
  final bool isBlocked;
  /// Permanent 4-digit code generated once at signup.
  /// Shown to customer; driver enters it to start every ride.
  final String rideCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.displayName,
    required this.phone,
    required this.role,
    required this.village,
    this.profilePhoto = '',
    this.fcmToken = '',
    this.isBlocked = false,
    this.rideCode = '',
    this.createdAt,
    this.updatedAt,
  });

  static const roleCustomer = 'customer';
  static const roleSaathi = 'saathi';
  static const roleBoth = 'both';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: d['uid'] ?? doc.id,
      name: d['name'] ?? '',
      displayName: d['displayName'] ?? d['name'] ?? '',
      phone: d['phone'] ?? '',
      role: d['role'] ?? 'customer',
      village: d['village'] ?? '',
      profilePhoto: d['profilePhoto'] ?? '',
      fcmToken: d['fcmToken'] ?? '',
      isBlocked: d['isBlocked'] ?? false,
      rideCode: d['rideCode'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'displayName': displayName,
        'phone': phone,
        'role': role,
        'village': village,
        'profilePhoto': profilePhoto,
        'fcmToken': fcmToken,
        'isBlocked': isBlocked,
        'rideCode': rideCode,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  UserModel copyWith({
    String? name,
    String? displayName,
    String? phone,
    String? role,
    String? village,
    String? profilePhoto,
    String? fcmToken,
    bool? isBlocked,
    String? rideCode,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      village: village ?? this.village,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      fcmToken: fcmToken ?? this.fcmToken,
      isBlocked: isBlocked ?? this.isBlocked,
      rideCode: rideCode ?? this.rideCode,
    );
  }
}
