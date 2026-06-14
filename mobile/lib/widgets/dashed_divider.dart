import 'package:flutter/material.dart';

class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1,
    this.color = const Color(0xFFE0E0E0),
    this.dashWidth = 5,
    this.dashSpace = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final boxWidth = constraints.constrainWidth();
      final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(dashCount, (_) {
          return SizedBox(
            width: dashWidth,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color),
            ),
          );
        }),
      );
    });
  }
}
