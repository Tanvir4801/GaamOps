import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class GujaratiText extends StatelessWidget {
  final String gujarati;
  final String english;
  final double gujaratiSize;
  final double englishSize;
  final Color? color;
  final FontWeight weight;
  final CrossAxisAlignment alignment;

  const GujaratiText({
    super.key,
    required this.gujarati,
    required this.english,
    this.gujaratiSize = 15,
    this.englishSize = 12,
    this.color,
    this.weight = FontWeight.normal,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gujarati,
          style: TextStyle(
            fontSize: gujaratiSize,
            fontWeight: weight,
            color: color ?? AppColors.textDark,
          ),
        ),
        Text(
          english,
          style: TextStyle(
            fontSize: englishSize,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}
