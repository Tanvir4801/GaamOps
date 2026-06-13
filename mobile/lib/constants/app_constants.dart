class AppConstants {
  AppConstants._();

  static const adminEmails = ['admin@gaamride.com'];

  static const serviceZoneSW = {'lat': 20.780, 'lng': 73.190};
  static const serviceZoneNE = {'lat': 20.920, 'lng': 73.320};

  static const defaultRideFareBase = 20.0;
  static const defaultRideFarePerKm = 8.0;
  static const defaultRideFareMinimum = 25.0;
  static const defaultRideFareMaximum = 200.0;
  static const defaultHaulCommission = 75.0;

  static const locationUpdateInterval = 10;
  static const locationDistanceFilter = 20;
  static const rideRequestTimeout = 30;
  static const markerAnimationSteps = 30;
  static const markerAnimationMs = 33;
  static const maintenanceCheckInterval = 30;
}
