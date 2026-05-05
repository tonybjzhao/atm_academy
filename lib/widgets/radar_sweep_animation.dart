import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class RadarSweepAnimation extends StatefulWidget {
  final double size;
  const RadarSweepAnimation({super.key, this.size = 160});

  @override
  State<RadarSweepAnimation> createState() => _RadarSweepAnimationState();
}

class _RadarSweepAnimationState extends State<RadarSweepAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RadarSweepPainter(_ctrl.value * 2 * pi),
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  _RadarSweepPainter(this.sweepAngle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final bgPaint = Paint()..color = const Color(0xFF07110A);
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, radius * r, ringPaint);
    }
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), ringPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), ringPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: sweepAngle - 1.2,
        endAngle: sweepAngle,
        colors: [Colors.transparent, AppTheme.primary.withValues(alpha: 0.7)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, sweepPaint);

    final linePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 1.5;
    canvas.drawLine(
      center,
      Offset(center.dx + cos(sweepAngle) * radius, center.dy + sin(sweepAngle) * radius),
      linePaint,
    );

    // Static blips
    final blipPaint = Paint()..color = AppTheme.primary..style = PaintingStyle.fill;
    for (final blip in [
      Offset(center.dx + radius * 0.4, center.dy - radius * 0.3),
      Offset(center.dx - radius * 0.5, center.dy + radius * 0.2),
      Offset(center.dx + radius * 0.1, center.dy + radius * 0.55),
    ]) {
      canvas.drawCircle(blip, 3, blipPaint);
    }

    final clipPaint = Paint()
      ..color = const Color(0xFF07110A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, clipPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter old) => old.sweepAngle != sweepAngle;
}
