import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class RunwayFlowAnimation extends StatefulWidget {
  final double width;
  final double height;
  const RunwayFlowAnimation({super.key, this.width = 320, this.height = 120});

  @override
  State<RunwayFlowAnimation> createState() => _RunwayFlowAnimationState();
}

class _RunwayFlowAnimationState extends State<RunwayFlowAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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
        size: Size(widget.width, widget.height),
        painter: _RunwayPainter(_ctrl.value),
      ),
    );
  }
}

class _RunwayPainter extends CustomPainter {
  final double t;
  _RunwayPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rwy = Paint()
      ..color = const Color(0xFF1A2A1A)
      ..style = PaintingStyle.fill;
    final ry = size.height * 0.45;
    final rh = size.height * 0.12;
    canvas.drawRect(Rect.fromLTWH(0, ry, size.width, rh), rwy);

    // Runway centreline dashes
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (int i = 0; i < 8; i++) {
      final x = (i * 44.0 + (t * 44) % 44);
      if (x < size.width) {
        canvas.drawLine(
          Offset(x, ry + rh / 2),
          Offset(min(x + 20, size.width), ry + rh / 2),
          dashPaint,
        );
      }
    }

    // Landing aircraft coming in from right
    final landT = (t + 0.5) % 1.0;
    final landX = size.width * (1.0 - landT);
    final landY = ry + rh / 2 - (1.0 - landT) * size.height * 0.35;
    _drawAircraft(canvas, Offset(landX, landY), AppTheme.secondary, 180);

    // Departing aircraft going to right
    final depT = t;
    final depX = size.width * depT * 1.1 - size.width * 0.05;
    final depY = ry + rh / 2 - depT * size.height * 0.4;
    if (depX > 0 && depX < size.width) {
      _drawAircraft(canvas, Offset(depX, depY), AppTheme.primary, 0);
    }
  }

  void _drawAircraft(Canvas canvas, Offset pos, Color color, double headingDeg) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(headingDeg * pi / 180);
    // Simple arrow shape
    final path = Path()
      ..moveTo(10, 0)
      ..lineTo(-6, -4)
      ..lineTo(-3, 0)
      ..lineTo(-6, 4)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RunwayPainter old) => old.t != t;
}
