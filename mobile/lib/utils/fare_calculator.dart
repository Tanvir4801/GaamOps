class FareCalculator {
  FareCalculator._();

  static double calculate({
    required double distanceMeters,
    required Map<String, dynamic> settings,
  }) {
    final distanceKm = distanceMeters / 1000;

    final base = (settings['rideFareBase'] ?? 20).toDouble();
    final perKm = (settings['rideFarePerKm'] ?? 8).toDouble();
    final min = (settings['rideFareMinimum'] ?? 25).toDouble();
    final max = (settings['rideFareMaximum'] ?? 200).toDouble();

    if (distanceKm <= 0 || distanceKm > 50) return min;

    double fare = base + (distanceKm * perKm);
    fare = fare.clamp(min, max).toDouble();

    return ((fare / 5).round() * 5).toDouble();
  }

  static double haulCommission(Map<String, dynamic> settings) {
    return (settings['haulCommission'] ?? 75).toDouble();
  }

  static double ownerEarnings(int ratePerHour, String duration) {
    const hours = {
      '1h': 1.0,
      '2h': 2.0,
      'half_day': 4.0,
      'full_day': 8.0,
    };
    return ratePerHour * (hours[duration] ?? 1.0);
  }

  static String format(double fare) => '₹${fare.toStringAsFixed(0)}';
}
