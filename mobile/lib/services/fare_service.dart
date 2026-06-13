import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fare_breakdown.dart';

class FareService {
  static Future<FareBreakdown> calculateFromFirestore({
    required double distanceKm,
    DateTime? rideTime,
  }) async {
    Map<String, dynamic> data = {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      if (doc.exists) data = doc.data() ?? {};
    } catch (_) {}

    return calculate(
      distanceKm: distanceKm,
      baseFare: (data['rideFareBase'] ?? 15).toDouble(),
      ratePerKm: (data['rideFarePerKm'] ?? 8).toDouble(),
      minimumFare: (data['rideFareMinimum'] ?? 25).toDouble(),
      gstPercent: (data['gstPercent'] ?? 5.0).toDouble(),
      platformFee: (data['platformFee'] ?? 3.0).toDouble(),
      lateNightFee: (data['lateNightFee'] ?? 10.0).toDouble(),
      surgeMorning: (data['surgeMorning'] ?? 1.0).toDouble(),
      surgeEvening: (data['surgeEvening'] ?? 1.0).toDouble(),
      surgeWeekend: (data['surgeWeekend'] ?? 1.0).toDouble(),
      gaamRideUpi: (data['gaamRideUpi'] as String?) ?? 'gaamride@upi',
      rideTime: rideTime,
    );
  }

  static FareBreakdown calculate({
    required double distanceKm,
    double baseFare = 15,
    double ratePerKm = 8,
    double minimumFare = 25,
    double gstPercent = 5.0,
    double platformFee = 3.0,
    double lateNightFee = 10.0,
    double surgeMorning = 1.0,
    double surgeEvening = 1.0,
    double surgeWeekend = 1.0,
    String gaamRideUpi = 'gaamride@upi',
    DateTime? rideTime,
  }) {
    final now = rideTime ?? DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday;

    final bool isMorningPeak = hour >= 7 && hour < 9;
    final bool isEveningPeak = hour >= 17 && hour < 20;
    final bool isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;
    final bool isLateNight = hour >= 23 || hour < 5;

    double surgeMultiplier = 1.0;
    String surgeLabel = '';
    if (isMorningPeak && surgeMorning > 1.0) {
      surgeMultiplier = surgeMorning;
      surgeLabel = 'Morning Peak';
    } else if (isEveningPeak && surgeEvening > 1.0) {
      surgeMultiplier = surgeEvening;
      surgeLabel = 'Evening Peak';
    }
    if (isWeekend && surgeWeekend > surgeMultiplier) {
      surgeMultiplier = surgeWeekend;
      surgeLabel = 'Weekend';
    }

    final distanceCharge = distanceKm * ratePerKm;
    double preGst = (baseFare + distanceCharge) * surgeMultiplier;
    if (isLateNight) preGst += lateNightFee;
    if (preGst < minimumFare) preGst = minimumFare;

    final gstAmount = preGst * gstPercent / 100;
    final total = preGst + gstAmount + platformFee;

    return FareBreakdown(
      baseFare: baseFare,
      distanceKm: distanceKm,
      distanceCharge: distanceCharge,
      surgeMultiplier: surgeMultiplier,
      isSurge: surgeMultiplier > 1.0,
      surgeLabel: surgeLabel,
      isLateNight: isLateNight,
      lateNightFee: isLateNight ? lateNightFee : 0,
      subtotal: preGst,
      gstPercent: gstPercent,
      gstAmount: gstAmount,
      platformFee: platformFee,
      totalFare: total,
      gaamRideUpi: gaamRideUpi,
    );
  }
}
