import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class CommsPulseAnimation extends StatefulWidget {
  final double size;
  const CommsPulseAnimation({super.key, this.size = 160});

  @override
  State<CommsPulseAnimation> createState() => _CommsPulseState();
}

class _CommsPulseState extends State<CommsPulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
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
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _CommsPainter(_ctrl.value),
      ),
    );
  }
}

class _CommsPainter extends CustomPainter {
  final double t;
  _CommsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.75);

    // Animated arcs expanding outward
    for (int i = 0; i < 3; i++) {
      final phase = (t - i * 0.33) % 1.0;
      if (phase < 0) continue;
      final radius = phase * size.width * 0.45;
      final opacity = (1.0 - phase) * 0.7;
      final arcPaint = Paint()
        ..color = AppTheme.secondary.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi * 1.1,
        pi * 0.6,
        false,
        arcPaint,
      );
    }

    // Tower icon
    final towerPaint = Paint()..color = AppTheme.textSecondary..strokeWidth = 2..style = PaintingStyle.stroke;
    // Mast
    canvas.drawLine(center, Offset(center.dx, center.dy - size.height * 0.25), towerPaint);
    // Base
    canvas.drawLine(
      Offset(center.dx - 12, center.dy),
      Offset(center.dx + 12, center.dy),
      towerPaint,
    );
    // Antenna top dot
    canvas.drawCircle(
      Offset(center.dx, center.dy - size.height * 0.25),
      3,
      Paint()..color = AppTheme.secondary,
    );
  }

  @override
  bool shouldRepaint(covariant _CommsPainter old) => old.t != t;
}
