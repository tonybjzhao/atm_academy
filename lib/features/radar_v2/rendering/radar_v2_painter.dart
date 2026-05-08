import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/aircraft_state.dart';
import '../models/separation_result.dart';
import '../models/simulation_snapshot.dart';

class RadarV2Painter extends CustomPainter {
  final SimulationSnapshot snapshot;
  final double rangeNm;

  const RadarV2Painter({
    required this.snapshot,
    this.rangeNm = 40,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46;
    final scale = radius / rangeNm;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x3346F5A7);
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x5546F5A7);

    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius * 0.33, gridPaint);
    canvas.drawLine(
        center.translate(-radius, 0), center.translate(radius, 0), axisPaint);
    canvas.drawLine(
        center.translate(0, -radius), center.translate(0, radius), axisPaint);

    for (final conflict
        in snapshot.separation.where((item) => item.isPredictedConflict)) {
      _drawConflict(canvas, center, scale, conflict);
    }

    for (final aircraft in snapshot.aircraft) {
      _drawAircraft(canvas, center, scale, aircraft);
    }
  }

  void _drawAircraft(
    Canvas canvas,
    Offset center,
    double scale,
    AircraftState aircraft,
  ) {
    final position = _toCanvas(center, scale, aircraft.xNm, aircraft.yNm);
    final headingRad = aircraft.headingDeg * math.pi / 180;
    final vectorLength = math.max(14, aircraft.groundSpeedKt / 12);
    final vectorEnd = position.translate(
      math.sin(headingRad) * vectorLength,
      -math.cos(headingRad) * vectorLength,
    );
    final targetPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF46F5A7);
    final vectorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xCC46F5A7);
    final labelPainter = TextPainter(
      text: TextSpan(
        text:
            '${aircraft.callsign}\n${aircraft.altitudeFt ~/ 100} ${aircraft.groundSpeedKt.round()}kt',
        style: const TextStyle(
          color: Color(0xFFE7FFF4),
          fontSize: 10,
          height: 1.1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 88);

    canvas.drawLine(position, vectorEnd, vectorPaint);
    canvas.drawCircle(position, 4, targetPaint);
    canvas.drawCircle(
      position,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x8846F5A7),
    );
    labelPainter.paint(canvas, position.translate(8, -18));
  }

  void _drawConflict(
    Canvas canvas,
    Offset center,
    double scale,
    SeparationResult conflict,
  ) {
    final x = conflict.conflictXNm;
    final y = conflict.conflictYNm;
    if (x == null || y == null) return;
    final position = _toCanvas(center, scale, x, y);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFD166);
    canvas.drawCircle(position, 10, paint);
    canvas.drawLine(
        position.translate(-8, -8), position.translate(8, 8), paint);
    canvas.drawLine(
        position.translate(-8, 8), position.translate(8, -8), paint);
  }

  Offset _toCanvas(Offset center, double scale, double xNm, double yNm) {
    return center.translate(xNm * scale, -yNm * scale);
  }

  @override
  bool shouldRepaint(covariant RadarV2Painter oldDelegate) {
    return oldDelegate.snapshot != snapshot || oldDelegate.rangeNm != rangeNm;
  }
}
