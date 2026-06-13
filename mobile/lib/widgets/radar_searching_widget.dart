import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RadarSearchingWidget extends StatefulWidget {
  final String? statusText;
  const RadarSearchingWidget({super.key, this.statusText});

  @override
  State<RadarSearchingWidget> createState() => _RadarSearchingWidgetState();
}

class _RadarSearchingWidgetState extends State<RadarSearchingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late AnimationController _pingCtrl;
  late Animation<double> _ping1;
  late Animation<double> _ping2;
  late Animation<double> _ping3;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _ping1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pingCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    _ping2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pingCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _ping3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _pingCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
    _rotateAnim = _rotateCtrl;
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _pingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pingCtrl, _rotateCtrl]),
            builder: (_, __) => CustomPaint(
              painter: _RadarPainter(
                ping1: _ping1.value,
                ping2: _ping2.value,
                ping3: _ping3.value,
                rotation: _rotateAnim.value,
              ),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withAlpha(80),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🛵', style: TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _AnimatedDots(),
        const SizedBox(height: 8),
        Text(
          widget.statusText ?? 'સાથી શોધી રહ્યા છીએ...',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Finding best Saathi near you',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double ping1;
  final double ping2;
  final double ping3;
  final double rotation;

  _RadarPainter({
    required this.ping1,
    required this.ping2,
    required this.ping3,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    void drawPing(double progress) {
      if (progress <= 0) return;
      final radius = maxRadius * progress;
      final opacity = (1 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = AppColors.primaryGreen.withAlpha((opacity * 60).toInt())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);

      final strokePaint = Paint()
        ..color = AppColors.primaryGreen.withAlpha((opacity * 120).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, strokePaint);
    }

    drawPing(ping1);
    drawPing(ping2);
    drawPing(ping3);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi / 2,
        colors: [
          AppColors.primaryGreen.withAlpha(0),
          AppColors.primaryGreen.withAlpha(60),
        ],
        transform: GradientRotation(rotation * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius - 8))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius - 8, sweepPaint);

    final dotPaint = Paint()
      ..color = AppColors.primaryGreen.withAlpha(200)
      ..style = PaintingStyle.fill;
    final angle = rotation * 2 * pi;
    final dotPos = Offset(
      center.dx + (maxRadius - 16) * cos(angle),
      center.dy + (maxRadius - 16) * sin(angle),
    );
    canvas.drawCircle(dotPos, 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final phase = (_ctrl.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = i == phase;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: active ? 10 : 6,
              height: active ? 10 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primaryGreen
                    : AppColors.primaryGreen.withAlpha(60),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
