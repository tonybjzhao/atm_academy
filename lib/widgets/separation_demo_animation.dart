import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SeparationDemoAnimation extends StatefulWidget {
  final double size;
  const SeparationDemoAnimation({super.key, this.size = 240});

  @override
  State<SeparationDemoAnimation> createState() => _SeparationDemoState();
}

class _SeparationDemoState extends State<SeparationDemoAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
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
        size: Size(widget.size, widget.size * 0.65),
        painter: _SepPainter(_ctrl.value),
      ),
    );
  }
}

class _SepPainter extends CustomPainter {
  final double t;
  _SepPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Oscillate between 0 and 1 (approach and diverge)
    final phase = (sin(t * 2 * pi) + 1) / 2;

    final a1 = Offset(size.width * 0.1 + size.width * 0.35 * phase, size.height * 0.3);
    final a2 = Offset(size.width * 0.9 - size.width * 0.35 * phase, size.height * 0.7);

    final dist = (a1 - a2).distance;
    final tooClose = dist < size.width * 0.3;

    // Draw separation ring
    final ringColor = tooClose ? AppTheme.danger : AppTheme.primary.withValues(alpha: 0.3);
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(a1, size.width * 0.13, ringPaint);
    canvas.drawCircle(a2, size.width * 0.13, ringPaint);

    // Draw line between aircraft
    final linePaint = Paint()
      ..color = tooClose ? AppTheme.danger.withValues(alpha: 0.6) : AppTheme.textSecondary.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a1, a2, linePaint);

    // Aircraft blips
    _drawBlip(canvas, a1, 'AC1', tooClose ? AppTheme.danger : AppTheme.secondary);
    _drawBlip(canvas, a2, 'AC2', tooClose ? AppTheme.danger : AppTheme.primary);

    // Conflict label
    if (tooClose) {
      final tp = TextPainter(
        text: const TextSpan(
          text: '⚠ CONFLICT',
          style: TextStyle(color: Color(0xFFFF1744), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, 4));
    }
  }

  void _drawBlip(Canvas canvas, Offset pos, String label, Color color) {
    canvas.drawCircle(pos, 5, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos + const Offset(8, -6));
  }

  @override
  bool shouldRepaint(covariant _SepPainter old) => old.t != t;
}
