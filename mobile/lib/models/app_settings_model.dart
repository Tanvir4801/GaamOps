class AppSettingsModel {
  final double rideFareBase;
  final double rideFarePerKm;
  final double rideFareMinimum;
  final double rideFareMaximum;
  final double haulCommission;
  final Map<String, dynamic> serviceZoneSW;
  final Map<String, dynamic> serviceZoneNE;
  final bool maintenanceMode;
  final String appVersion;

  const AppSettingsModel({
    required this.rideFareBase,
    required this.rideFarePerKm,
    required this.rideFareMinimum,
    required this.rideFareMaximum,
    required this.haulCommission,
    required this.serviceZoneSW,
    required this.serviceZoneNE,
    required this.maintenanceMode,
    required this.appVersion,
  });

  factory AppSettingsModel.fromFirestore(Map<String, dynamic> d) {
    return AppSettingsModel(
      rideFareBase: (d['rideFareBase'] ?? 20).toDouble(),
      rideFarePerKm: (d['rideFarePerKm'] ?? 8).toDouble(),
      rideFareMinimum: (d['rideFareMinimum'] ?? 25).toDouble(),
      rideFareMaximum: (d['rideFareMaximum'] ?? 200).toDouble(),
      haulCommission: (d['haulCommission'] ?? 75).toDouble(),
      serviceZoneSW: (d['serviceZoneSW'] as Map<String, dynamic>?) ??
          {'lat': 20.780, 'lng': 73.190},
      serviceZoneNE: (d['serviceZoneNE'] as Map<String, dynamic>?) ??
          {'lat': 20.920, 'lng': 73.320},
      maintenanceMode: d['maintenanceMode'] ?? false,
      appVersion: d['appVersion'] ?? '1.0.0',
    );
  }

  factory AppSettingsModel.defaults() => const AppSettingsModel(
        rideFareBase: 20,
        rideFarePerKm: 8,
        rideFareMinimum: 25,
        rideFareMaximum: 200,
        haulCommission: 75,
        serviceZoneSW: {'lat': 20.780, 'lng': 73.190},
        serviceZoneNE: {'lat': 20.920, 'lng': 73.320},
        maintenanceMode: false,
        appVersion: '1.0.0',
      );

  Map<String, dynamic> toMap() => {
        'rideFareBase': rideFareBase,
        'rideFarePerKm': rideFarePerKm,
        'rideFareMinimum': rideFareMinimum,
        'rideFareMaximum': rideFareMaximum,
        'haulCommission': haulCommission,
        'serviceZoneSW': serviceZoneSW,
        'serviceZoneNE': serviceZoneNE,
        'maintenanceMode': maintenanceMode,
        'appVersion': appVersion,
      };
}
