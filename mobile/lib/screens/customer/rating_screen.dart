import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../customer/customer_main_shell.dart';

class RatingScreen extends StatefulWidget {
  final RideModel ride;

  const RatingScreen({super.key, required this.ride});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final Set<String> _selectedChips = {};
  bool _submitting = false;

  static const List<String> _chips = [
    'સમયસર / On time',
    'સ્વચ્છ વાહન / Clean vehicle',
    'સારો સ્વભાવ / Friendly',
    'સુરક્ષિત ડ્રાઇવિંગ / Safe driving',
  ];

  String get _ratingLabel {
    switch (_rating) {
      case 1: return 'ખૂબ ખરાબ / Very Poor';
      case 2: return 'ખરાબ / Poor';
      case 3: return 'ઠીક / Okay';
      case 4: return 'સારો / Good';
      case 5: return 'ઉત્કૃષ્ટ / Excellent!';
      default: return 'Rating પસંદ કરો / Select rating';
    }
  }

  Color get _labelColor {
    switch (_rating) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.amber;
      case 4: return AppColors.primaryGreen;
      case 5: return const Color(0xFF1B5E20);
      default: return AppColors.textGrey;
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      if (_rating > 0) {
        await RideService.submitRating(
          rideId: widget.ride.rideId,
          saathiId: widget.ride.saathiId,
          rating: _rating.toDouble(),
          tags: _selectedChips.toList(),
        );
      }
    } catch (_) {}
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CustomerMainShell()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final saathiInitial = ride.saathiName.isNotEmpty
        ? ride.saathiName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 72,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'સવારી પૂર્ણ! / Ride Complete!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 6),
              Text(
                'Fare paid: ₹${ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 16, color: AppColors.primaryGreen),
              ),

              const SizedBox(height: 36),

              CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.bgGreen,
                child: Text(
                  saathiInitial,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ride.saathiName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                ride.vehicleType,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textGrey),
              ),

              const SizedBox(height: 28),
              const Text(
                'Saathi ને રેટ કરો / Rate your Saathi',
                style: TextStyle(fontSize: 16, color: AppColors.textDark),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 46,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                _ratingLabel,
                style: TextStyle(
                    fontSize: 14,
                    color: _labelColor,
                    fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 24),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _chips.map((chip) {
                  final selected = _selectedChips.contains(chip);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedChips.remove(chip);
                      } else {
                        _selectedChips.add(chip);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.bgGreen : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryGreen
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? AppColors.primaryGreen
                              : AppColors.textDark,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _rating == 0 ? 'Skip / છોડો' : 'Submit Rating',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
