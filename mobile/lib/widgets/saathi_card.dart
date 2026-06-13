import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/saathi_model.dart';
import 'rating_widget.dart';
import 'gujarati_text.dart';

class SaathiCard extends StatelessWidget {
  final SaathiModel saathi;
  final double distanceMeters;
  final bool isPreferred;
  final VoidCallback onBook;

  const SaathiCard({
    super.key,
    required this.saathi,
    required this.distanceMeters,
    required this.isPreferred,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);
    final etaMin = (distanceMeters / 1000 / 25 * 60).ceil().clamp(1, 120);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPreferred
            ? const BorderSide(color: AppColors.primaryGreen, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.bgGreen,
                  child: Text(
                    saathi.name.isNotEmpty ? saathi.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                        color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(saathi.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          if (isPreferred) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PREFERRED',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text(saathi.vehicleType,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 12)),
                    ],
                  ),
                ),
                StarRating(rating: saathi.rating),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.textGrey),
                Text(' $distanceKm km away · ~$etaMin min',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey)),
                const Spacer(),
                GujaratiText(gujarati: saathi.village, english: 'Village', gujaratiSize: 11, englishSize: 9),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen),
                onPressed: onBook,
                child: const GujaratiText(
                  gujarati: 'બુક કરો',
                  english: 'Book',
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
