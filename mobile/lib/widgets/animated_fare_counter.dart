import 'package:flutter/material.dart';

class AnimatedFareCounter extends StatefulWidget {
  final double targetFare;
  final TextStyle? style;
  final Duration duration;

  const AnimatedFareCounter({
    super.key,
    required this.targetFare,
    this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedFareCounter> createState() => _AnimatedFareCounterState();
}

class _AnimatedFareCounterState extends State<AnimatedFareCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _prevTarget = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.targetFare).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    if (widget.targetFare > 0) _ctrl.forward();
    _prevTarget = widget.targetFare;
  }

  @override
  void didUpdateWidget(AnimatedFareCounter old) {
    super.didUpdateWidget(old);
    if (widget.targetFare != _prevTarget) {
      _anim = Tween<double>(begin: _prevTarget, end: widget.targetFare).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl
        ..reset()
        ..forward();
      _prevTarget = widget.targetFare;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Text(
        '₹${_anim.value.toStringAsFixed(0)}',
        style: widget.style,
      ),
    );
  }
}
