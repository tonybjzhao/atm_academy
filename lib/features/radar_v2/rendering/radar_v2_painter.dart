import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/aircraft_state.dart';
import '../models/separation_result.dart';
import '../models/simulation_snapshot.dart';

class RadarV2Painter extends CustomPainter {
  final SimulationSnapshot snapshot;
  final double rangeNm;
  final String? selectedAircraftId;
  final String? recentlyCommandedAircraftId;
  final bool alertPulse;

  const RadarV2Painter({
    required this.snapshot,
    this.rangeNm = 40,
    this.selectedAircraftId,
    this.recentlyCommandedAircraftId,
    this.alertPulse = false,
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

    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      _drawTrail(canvas, center, scale, aircraft);
    }

    for (final loss
        in snapshot.separation.where((item) => item.isLossOfSeparation)) {
      _drawLoss(canvas, center, scale, loss);
    }

    for (final conflict
        in snapshot.separation.where((item) => item.isPredictedConflict)) {
      _drawConflict(canvas, center, scale, conflict);
    }

    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active) continue;
      _drawAircraft(
        canvas,
        center,
        scale,
        aircraft,
        urgency: _urgencyForAircraft(aircraft.id),
        selected: selectedAircraftId == aircraft.id,
        recentlyCommanded: recentlyCommandedAircraftId == aircraft.id,
      );
    }
  }

  void _drawAircraft(
      Canvas canvas, Offset center, double scale, AircraftState aircraft,
      {required _ConflictUrgency urgency,
      required bool selected,
      required bool recentlyCommanded}) {
    final position = _toCanvas(center, scale, aircraft.xNm, aircraft.yNm);
    final headingRad = aircraft.headingDeg * math.pi / 180;
    final vectorLength =
        (aircraft.groundSpeedKt * 60 / 3600 * scale).clamp(12.0, 70.0);
    final vectorEnd = position.translate(
      math.sin(headingRad) * vectorLength,
      -math.cos(headingRad) * vectorLength,
    );
    final aircraftColor = _colorForUrgency(urgency);
    final targetPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = aircraftColor;
    final vectorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = aircraftColor.withValues(alpha: 0.8);
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
    if (selected || recentlyCommanded) {
      _drawIntentVector(canvas, position, aircraft, selected ? 54 : 42);
    }
    canvas.drawCircle(position, 4, targetPaint);
    canvas.drawCircle(
      position,
      selected ? 12 : 8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2 : 1
        ..color = aircraftColor.withValues(alpha: 0.55),
    );
    if (recentlyCommanded) {
      canvas.drawCircle(
        position,
        17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF62D2FF),
      );
    }
    labelPainter.paint(canvas, position.translate(8, -18));
  }

  void _drawTrail(
    Canvas canvas,
    Offset center,
    double scale,
    AircraftState aircraft,
  ) {
    final points = snapshot.trailFor(aircraft.id);
    if (points.length < 2) return;
    final path = Path()
      ..moveTo(
        _toCanvas(center, scale, points.first.xNm, points.first.yNm).dx,
        _toCanvas(center, scale, points.first.xNm, points.first.yNm).dy,
      );
    for (final point in points.skip(1)) {
      final offset = _toCanvas(center, scale, point.xNm, point.yNm);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x6646F5A7),
    );
  }

  void _drawIntentVector(
    Canvas canvas,
    Offset position,
    AircraftState aircraft,
    double length,
  ) {
    final assignedHeading = aircraft.intent.assignedHeadingDeg;
    if (assignedHeading == null) return;
    final headingRad = assignedHeading * math.pi / 180;
    final end = position.translate(
      math.sin(headingRad) * length,
      -math.cos(headingRad) * length,
    );
    canvas.drawLine(
      position,
      end,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF62D2FF),
    );
  }

  void _drawLoss(
    Canvas canvas,
    Offset center,
    double scale,
    SeparationResult loss,
  ) {
    final a = snapshot.aircraftById(loss.aircraftAId);
    final b = snapshot.aircraftById(loss.aircraftBId);
    if (a == null || b == null || !a.active || !b.active) return;
    final aPosition = _toCanvas(center, scale, a.xNm, a.yNm);
    final bPosition = _toCanvas(center, scale, b.xNm, b.yNm);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFF4D4D);
    canvas.drawLine(aPosition, bPosition, paint);
    _drawAlertLabel(
      canvas,
      Offset.lerp(aPosition, bPosition, 0.5)!,
      'LOSS ${loss.lateralNm.toStringAsFixed(1)}NM',
      const Color(0xFFFF4D4D),
    );
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
      ..color = _isUrgent(conflict) && alertPulse
          ? const Color(0xFFFF4D4D)
          : const Color(0xFFFFD166);
    canvas.drawCircle(position, 10, paint);
    canvas.drawLine(
        position.translate(-8, -8), position.translate(8, 8), paint);
    canvas.drawLine(
        position.translate(-8, 8), position.translate(8, -8), paint);
    final seconds = conflict.timeToConflict?.inSeconds;
    final label = seconds == null
        ? 'CONFLICT'
        : 'CONFLICT T-${seconds}s ${conflict.lateralNm.toStringAsFixed(1)}NM';
    _drawAlertLabel(
        canvas, position.translate(12, -22), label, const Color(0xFFFFD166));
  }

  void _drawAlertLabel(
    Canvas canvas,
    Offset position,
    String text,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);
    painter.paint(canvas, position);
  }

  _ConflictUrgency _urgencyForAircraft(String aircraftId) {
    var urgency = _ConflictUrgency.normal;
    for (final result in snapshot.separation) {
      final involved =
          result.aircraftAId == aircraftId || result.aircraftBId == aircraftId;
      if (!involved) continue;
      if (result.isLossOfSeparation) return _ConflictUrgency.loss;
      if (result.isPredictedConflict && _isUrgent(result)) {
        urgency = _ConflictUrgency.urgent;
      } else if (result.isPredictedConflict &&
          urgency == _ConflictUrgency.normal) {
        urgency = _ConflictUrgency.predicted;
      }
    }
    return urgency;
  }

  bool _isUrgent(SeparationResult result) {
    return (result.timeToConflict?.inSeconds ?? 999) <= 60;
  }

  Color _colorForUrgency(_ConflictUrgency urgency) {
    switch (urgency) {
      case _ConflictUrgency.normal:
        return const Color(0xFF46F5A7);
      case _ConflictUrgency.predicted:
        return const Color(0xFFFFD166);
      case _ConflictUrgency.urgent:
        return alertPulse ? const Color(0xFFFF4D4D) : const Color(0xFFFFD166);
      case _ConflictUrgency.loss:
        return const Color(0xFFFF4D4D);
    }
  }

  Offset _toCanvas(Offset center, double scale, double xNm, double yNm) {
    return center.translate(xNm * scale, -yNm * scale);
  }

  @override
  bool shouldRepaint(covariant RadarV2Painter oldDelegate) {
    return oldDelegate.snapshot != snapshot || oldDelegate.rangeNm != rangeNm;
  }
}

enum _ConflictUrgency {
  normal,
  predicted,
  urgent,
  loss,
}
