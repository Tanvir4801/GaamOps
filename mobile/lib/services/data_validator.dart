import 'package:flutter/foundation.dart';

class DataValidator {
  static const _validRideStatuses = [
    'searching', 'accepted', 'arriving', 'started', 'completed', 'cancelled'
  ];
  static const _validHaulStatuses = [
    'searching', 'accepted', 'started', 'completed', 'cancelled'
  ];
  static const _validDurations = ['1h', '2h', 'half_day', 'full_day'];
  static const _validHaulVehicles = [
    'mini_tempo', 'pickup', 'tractor', 'truck_407'
  ];
  static const _validRoles = ['customer', 'saathi', 'both'];

  static void validateRideData(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? '';
    assert(!status.contains('|'),
        'INVALID: status contains pipe separator: $status');
    assert(_validRideStatuses.contains(status),
        'INVALID: status not in valid list: $status');
    assert(data['customerId'] is String &&
        (data['customerId'] as String).isNotEmpty,
        'INVALID: missing or empty customerId');
    assert(!data.containsKey('customerId::'),
        'INVALID: double-colon field name found (customerId::)');
    final fare = (data['fare'] ?? 0).toDouble();
    assert(fare >= 0 && fare <= 500,
        'INVALID: fare out of range (0–500): $fare');
    final dist = (data['distance'] ?? 0).toDouble();
    assert(dist >= 0 && dist <= 50,
        'INVALID: distance out of range — check meters vs km: $dist');
    final otp = data['otp'] as String? ?? '';
    assert(otp.length == 4,
        'INVALID: OTP must be 4 digits, got: ${otp.length}');
  }

  static void validateHaulBooking(Map<String, dynamic> data) {
    final duration = data['duration'] as String? ?? '';
    final vehicle = data['vehicleType'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    assert(!duration.contains('|'),
        'INVALID: duration contains pipe: $duration');
    assert(_validDurations.contains(duration),
        'INVALID: duration not in valid list: $duration');
    assert(!vehicle.contains('|'),
        'INVALID: vehicleType contains pipe: $vehicle');
    assert(_validHaulVehicles.contains(vehicle),
        'INVALID: vehicleType not valid: $vehicle');
    assert(!status.contains('|'),
        'INVALID: status contains pipe: $status');
    assert(_validHaulStatuses.contains(status),
        'INVALID: haul status not valid: $status');
    assert(data['appCommission'] == 75,
        'INVALID: appCommission must be 75, got: ${data['appCommission']}');
  }

  static void validateUserData(Map<String, dynamic> data) {
    final role = data['role'] as String? ?? '';
    assert(!role.contains('|'),
        'INVALID: role contains pipe separator: $role');
    assert(_validRoles.contains(role),
        'INVALID: role not in valid list: $role');
    assert(data['uid'] is String && (data['uid'] as String).isNotEmpty,
        'INVALID: missing uid');
    assert(data['isBlocked'] is bool,
        'INVALID: isBlocked must be a bool');
  }

  static void run(String label, Map<String, dynamic> data,
      void Function(Map<String, dynamic>) fn) {
    if (kDebugMode) {
      try {
        fn(data);
      } catch (e) {
        debugPrint('❌ DataValidator [$label]: $e');
        rethrow;
      }
    }
  }
}
