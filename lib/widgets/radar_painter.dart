import 'dart:math';
import 'package:flutter/material.dart';
import '../core/models/aircraft.dart';
import '../core/theme/app_theme.dart';

class RadarPainter extends CustomPainter {
  final List<Aircraft> aircraft;
  final double sweepAngle;
  final Aircraft? selected;
  final bool conflict;

  const RadarPainter({
    required this.aircraft,
    required this.sweepAngle,
    required this.selected,
    required this.conflict,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) * 0.46;

    // Background
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF050F0A),
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final r in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, radius * r, gridPaint);
    }
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      canvas.drawLine(
        center,
        Offset(center.dx + cos(angle) * radius, center.dy + sin(angle) * radius),
        gridPaint,
      );
    }

    // Sweep trail (filled sector)
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: sweepAngle - 1.4,
      endAngle: sweepAngle,
      colors: [Colors.transparent, AppTheme.primary.withValues(alpha: 0.18)],
    );
    final sweepRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = sweepGradient.createShader(sweepRect),
    );

    // Sweep line
    canvas.drawLine(
      center,
      Offset(center.dx + cos(sweepAngle) * radius, center.dy + sin(sweepAngle) * radius),
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.8)
        ..strokeWidth = 1.5,
    );

    // Aircraft blips
    for (final a in aircraft) {
      final pt = Offset(a.x, a.y);
      final isSelected = selected == a;
      final blipColor = isSelected
          ? Colors.yellowAccent
          : conflict
              ? AppTheme.danger
              : AppTheme.primary;

      // Halo for selected
      if (isSelected) {
        canvas.drawCircle(pt, 14, Paint()..color = Colors.yellowAccent.withValues(alpha: 0.12));
      }

      // Heading vector
      final radians = a.heading * pi / 180;
      canvas.drawLine(
        pt,
        Offset(pt.dx + cos(radians) * 22, pt.dy + sin(radians) * 22),
        Paint()..color = blipColor.withValues(alpha: 0.6)..strokeWidth = 1,
      );

      // Blip
      canvas.drawCircle(pt, isSelected ? 7 : 5, Paint()..color = blipColor);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: '${a.callsign}\nFL${a.altitude}',
          style: TextStyle(color: blipColor, fontSize: 10, height: 1.3),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pt + const Offset(9, -8));
    }

    // Outer ring border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) => true;
}
