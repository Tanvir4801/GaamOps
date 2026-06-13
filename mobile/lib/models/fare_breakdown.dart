class FareBreakdown {
  final double baseFare;
  final double distanceKm;
  final double distanceCharge;
  final double surgeMultiplier;
  final bool isSurge;
  final String surgeLabel;
  final bool isLateNight;
  final double lateNightFee;
  final double subtotal;
  final double gstPercent;
  final double gstAmount;
  final double platformFee;
  final double promoDiscount;
  final double totalFare;
  final String gaamRideUpi;

  const FareBreakdown({
    required this.baseFare,
    required this.distanceKm,
    required this.distanceCharge,
    required this.surgeMultiplier,
    required this.isSurge,
    required this.surgeLabel,
    required this.isLateNight,
    required this.lateNightFee,
    required this.subtotal,
    required this.gstPercent,
    required this.gstAmount,
    required this.platformFee,
    this.promoDiscount = 0,
    required this.totalFare,
    required this.gaamRideUpi,
  });

  FareBreakdown copyWithDiscount(double discount) {
    final newTotal = (totalFare - discount).clamp(0, double.infinity).toDouble();
    return FareBreakdown(
      baseFare: baseFare,
      distanceKm: distanceKm,
      distanceCharge: distanceCharge,
      surgeMultiplier: surgeMultiplier,
      isSurge: isSurge,
      surgeLabel: surgeLabel,
      isLateNight: isLateNight,
      lateNightFee: lateNightFee,
      subtotal: subtotal,
      gstPercent: gstPercent,
      gstAmount: gstAmount,
      platformFee: platformFee,
      promoDiscount: discount,
      totalFare: newTotal,
      gaamRideUpi: gaamRideUpi,
    );
  }

  Map<String, dynamic> toMap() => {
    'baseFare': baseFare,
    'distanceKm': distanceKm,
    'distanceCharge': distanceCharge,
    'surgeMultiplier': surgeMultiplier,
    'lateNightFee': lateNightFee,
    'gstAmount': gstAmount,
    'platformFee': platformFee,
    'promoDiscount': promoDiscount,
    'totalFare': totalFare,
  };
}
