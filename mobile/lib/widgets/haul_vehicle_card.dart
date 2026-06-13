import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/haul_vehicle_model.dart';
import 'gujarati_text.dart';

class HaulVehicleCard extends StatelessWidget {
  final HaulVehicleModel vehicle;
  final double distanceMeters;
  final VoidCallback onBook;

  const HaulVehicleCard({
    super.key,
    required this.vehicle,
    required this.distanceMeters,
    required this.onBook,
  });

  IconData get _vehicleIcon {
    switch (vehicle.vehicleType) {
      case HaulVehicleModel.tractor: return Icons.agriculture;
      case HaulVehicleModel.truck407: return Icons.local_shipping;
      default: return Icons.local_taxi;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.bgOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_vehicleIcon, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.vehicleTypeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(vehicle.ownerName,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${vehicle.ratePerHour.toStringAsFixed(0)}/hr',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                            fontSize: 14)),
                    Text(vehicle.capacity,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textGrey)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.textGrey),
                Text(' $distanceKm km · ${vehicle.village}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange),
                onPressed: onBook,
                child: const GujaratiText(
                  gujarati: 'ભાડે કરો',
                  english: 'Hire Vehicle',
                  gujaratiSize: 14,
                  englishSize: 10,
                  color: Colors.white,
                  alignment: CrossAxisAlignment.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
