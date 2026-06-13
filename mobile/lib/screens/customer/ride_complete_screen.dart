import 'package:flutter/material.dart';
import '../../models/ride_model.dart';
import 'rating_screen.dart';

class RideCompleteScreen extends StatelessWidget {
  final RideModel ride;

  const RideCompleteScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RatingScreen(ride: ride)),
      );
    });
    return const SizedBox.shrink();
  }
}
