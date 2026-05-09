import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/aircraft_state.dart';
import '../models/separation_result.dart';
import '../models/simulation_snapshot.dart';

class RadarV2Painter extends CustomPainter {
  final SimulationSnapshot snapshot;
  final SimulationSnapshot? previousSnapshot;
  final double interpolation;
  final double rangeNm;
  final String? selectedAircraftId;
  final String? recentlyCommandedAircraftId;
  final bool alertPulse;
  final bool sweepEnabled;
  final double sweepAngleRad;

  const RadarV2Painter({
    required this.snapshot,
    this.previousSnapshot,
    this.interpolation = 1,
    this.rangeNm = 40,
    this.selectedAircraftId,
    this.recentlyCommandedAircraftId,
    this.alertPulse = false,
    this.sweepEnabled = true,
    this.sweepAngleRad = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.46;
    final scale = radius / rangeNm;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x1F46F5A7);
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x3046F5A7);

    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius * 0.33, gridPaint);
    canvas.drawLine(
        center.translate(-radius, 0), center.translate(radius, 0), axisPaint);
    canvas.drawLine(
        center.translate(0, -radius), center.translate(0, radius), axisPaint);
    _drawWeather(canvas, center, scale);
    _drawArrivalFlows(canvas, center, scale);
    _drawRunwayCrossingConflicts(canvas, center, scale);
    _drawHoldPatterns(canvas, center, scale);
    _drawWaypoints(canvas, center, scale);
    if (sweepEnabled) {
      _drawSweep(canvas, center, radius);
    }

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
      final renderAircraft = _interpolatedAircraft(aircraft);
      _drawAircraft(
        canvas,
        center,
        scale,
        renderAircraft,
        urgency: _urgencyForAircraft(aircraft.id),
        selected: selectedAircraftId == aircraft.id,
        recentlyCommanded: recentlyCommandedAircraftId == aircraft.id,
        sweepPulse: sweepEnabled ? _sweepPulseFor(renderAircraft) : 0,
      );
    }
  }

  void _drawAircraft(
      Canvas canvas, Offset center, double scale, AircraftState aircraft,
      {required _ConflictUrgency urgency,
      required bool selected,
      required bool recentlyCommanded,
      required double sweepPulse}) {
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
        text: _datablockText(aircraft),
        style: const TextStyle(
          color: Color(0xFFE7FFF4),
          fontSize: 9,
          height: 1.1,
          fontFamily: 'monospace',
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 88);

    canvas.drawLine(position, vectorEnd, vectorPaint);
    canvas.drawLine(
      position.translate(7, -12),
      position.translate(31, -24),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = aircraftColor.withValues(alpha: 0.45),
    );
    if (selected || recentlyCommanded) {
      canvas.drawCircle(
        position,
        selected ? 22 : 18,
        Paint()
          ..style = PaintingStyle.fill
          ..color = (selected ? aircraftColor : const Color(0xFF62D2FF))
              .withValues(alpha: selected ? 0.12 : 0.08),
      );
      _drawIntentVector(canvas, position, aircraft, selected ? 54 : 42);
    }
    canvas.drawCircle(position, 4, targetPaint);
    if (sweepPulse > 0) {
      canvas.drawCircle(
        position,
        11 + 8 * sweepPulse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = aircraftColor.withValues(alpha: 0.18 + 0.35 * sweepPulse),
      );
    }
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
    for (var i = 1; i < points.length; i++) {
      final from =
          _toCanvas(center, scale, points[i - 1].xNm, points[i - 1].yNm);
      final to = _toCanvas(center, scale, points[i].xNm, points[i].yNm);
      final alpha = (0.12 + i / points.length * 0.42).clamp(0.12, 0.54);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF46F5A7).withValues(alpha: alpha),
      );
    }
  }

  String _datablockText(AircraftState aircraft) {
    final callsign = aircraft.callsign.padRight(6).substring(0, 6);
    final heading = aircraft.headingDeg.round().toString().padLeft(3, '0');
    final altitude = (aircraft.altitudeFt ~/ 100).toString().padLeft(3, '0');
    final speed = aircraft.groundSpeedKt.round().toString().padLeft(3, '0');
    final vertical = aircraft.verticalSpeedFpm > 100
        ? '↑'
        : aircraft.verticalSpeedFpm < -100
            ? '↓'
            : ' ';
    return '$callsign HDG→$heading\nA$altitude$vertical  S$speed';
  }

  void _drawWeather(Canvas canvas, Offset center, double scale) {
    for (final zone in snapshot.weatherZones) {
      final position = _toCanvas(center, scale, zone.xNm, zone.yNm);
      final radius = zone.radiusNm * scale;
      final color = zone.severity >= 2
          ? const Color(0xFFFF4D4D)
          : const Color(0xFFFFD166);
      canvas.drawCircle(
        position,
        radius + (alertPulse ? 1.8 : 0),
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: alertPulse ? 0.16 : 0.1),
      );
      canvas.drawCircle(
        position,
        radius + (alertPulse ? 2.5 : 0),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: alertPulse ? 0.85 : 0.58),
      );
      _drawAlertLabel(
        canvas,
        position.translate(radius + 4, -8),
        zone.id,
        color,
      );
    }
  }

  void _drawArrivalFlows(Canvas canvas, Offset center, double scale) {
    final boundaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x3355D6BE);

    for (final flow in snapshot.arrivalFlows) {
      final merge = snapshot.waypoints[flow.mergeWaypointId];
      final finalFix = snapshot.waypoints[flow.finalFixWaypointId];
      final threshold = snapshot.waypoints[flow.thresholdWaypointId];
      if (merge == null || finalFix == null || threshold == null) continue;

      final mergePoint = _toCanvas(center, scale, merge.xNm, merge.yNm);
      final finalPoint = _toCanvas(center, scale, finalFix.xNm, finalFix.yNm);
      final thresholdPoint =
          _toCanvas(center, scale, threshold.xNm, threshold.yNm);
      canvas.drawLine(mergePoint, finalPoint, boundaryPaint);
      final runwayActive = _runwayActive(flow.runwayId);
      final occupied = _runwayOccupied(flow.runwayId);
      final centerlinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = runwayActive ? 2.2 : 1.2
        ..color = occupied
            ? (alertPulse ? const Color(0xFFFF4D4D) : const Color(0xFFFFD166))
            : (runwayActive
                ? const Color(0xFF62D2FF)
                : const Color(0x6655D6BE));
      canvas.drawLine(finalPoint, thresholdPoint, centerlinePaint);
      _drawCenterlineExtension(
          canvas, finalPoint, thresholdPoint, centerlinePaint);

      final dx = thresholdPoint.dx - finalPoint.dx;
      final dy = thresholdPoint.dy - finalPoint.dy;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length > 0) {
        final normal = Offset(-dy / length, dx / length) * 12;
        final funnel = Path()
          ..moveTo(mergePoint.dx, mergePoint.dy)
          ..lineTo(finalPoint.dx + normal.dx, finalPoint.dy + normal.dy)
          ..lineTo(thresholdPoint.dx + normal.dx * 0.4,
              thresholdPoint.dy + normal.dy * 0.4)
          ..moveTo(mergePoint.dx, mergePoint.dy)
          ..lineTo(finalPoint.dx - normal.dx, finalPoint.dy - normal.dy)
          ..lineTo(thresholdPoint.dx - normal.dx * 0.4,
              thresholdPoint.dy - normal.dy * 0.4);
        canvas.drawPath(funnel, boundaryPaint);
      }

      _drawAlertLabel(
        canvas,
        mergePoint.translate(8, 8),
        'MERGE ${flow.spacingTargetNm.toStringAsFixed(0)}NM',
        const Color(0xFF55D6BE),
      );
      _drawAlertLabel(
        canvas,
        thresholdPoint.translate(8, -10),
        _runwayLabel(flow.runwayId),
        occupied
            ? (alertPulse ? const Color(0xFFFF4D4D) : const Color(0xFFFFD166))
            : const Color(0xFF55D6BE),
      );
    }
  }

  void _drawCenterlineExtension(
    Canvas canvas,
    Offset finalPoint,
    Offset thresholdPoint,
    Paint centerlinePaint,
  ) {
    final dx = thresholdPoint.dx - finalPoint.dx;
    final dy = thresholdPoint.dy - finalPoint.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0) return;
    final ux = dx / length;
    final uy = dy / length;
    final extension = thresholdPoint.translate(ux * 52, uy * 52);
    canvas.drawLine(
      thresholdPoint,
      extension,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = centerlinePaint.strokeWidth
        ..color = centerlinePaint.color.withValues(alpha: 0.45),
    );
  }

  void _drawRunwayCrossingConflicts(
    Canvas canvas,
    Offset center,
    double scale,
  ) {
    for (final departureFlow in snapshot.departureFlows) {
      final departureRunway = snapshot.waypoints[departureFlow.runwayId];
      if (departureRunway == null) continue;
      final departurePoint =
          _toCanvas(center, scale, departureRunway.xNm, departureRunway.yNm);
      for (final crossingRunwayId in departureFlow.crossingRunwayIds) {
        final crossingRunway = snapshot.waypoints[crossingRunwayId];
        if (crossingRunway == null) continue;
        final crossingPoint =
            _toCanvas(center, scale, crossingRunway.xNm, crossingRunway.yNm);
        final risk = _crossingConflictRisk(
          departureFlow.runwayId,
          crossingRunwayId,
        );
        _drawDashedLine(
          canvas,
          departurePoint,
          crossingPoint,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = risk ? 2 : 1.3
            ..color = risk
                ? (alertPulse
                    ? const Color(0xFFFF4D4D)
                    : const Color(0xFFFFD166))
                : const Color(0x5562D2FF),
        );
        final midpoint = Offset.lerp(departurePoint, crossingPoint, 0.5)!;
        if (risk) {
          _drawAlertLabel(
            canvas,
            midpoint.translate(6, -14),
            '${departureFlow.runwayId}/${crossingRunwayId} X-RWY RISK',
            alertPulse ? const Color(0xFFFF4D4D) : const Color(0xFFFFD166),
          );
        }
      }
    }
  }

  bool _crossingConflictRisk(
      String departureRunwayId, String crossingRunwayId) {
    final departureOccupied = _runwayOccupied(departureRunwayId);
    final crossingOccupied = _runwayOccupied(crossingRunwayId);
    if (departureOccupied && crossingOccupied) return true;

    final crossingArrivalFlow = snapshot.arrivalFlows.where(
      (flow) => flow.runwayId == crossingRunwayId,
    );
    if (crossingArrivalFlow.isNotEmpty) {
      final threshold =
          snapshot.waypoints[crossingArrivalFlow.first.thresholdWaypointId];
      if (threshold != null) {
        final shortFinalArrival = snapshot.aircraft.any((aircraft) {
          if (!aircraft.active || aircraft.intent.isDeparture) return false;
          if (aircraft.intent.assignedRunwayId != crossingRunwayId)
            return false;
          final dx = aircraft.xNm - threshold.xNm;
          final dy = aircraft.yNm - threshold.yNm;
          return dx * dx + dy * dy < 7 * 7;
        });
        if (shortFinalArrival) return true;
      }
    }

    final departureThreshold = snapshot.waypoints[departureRunwayId];
    if (departureThreshold == null) return false;
    final departureRolling = snapshot.aircraft.any((aircraft) {
      if (!aircraft.active || !aircraft.intent.isDeparture) return false;
      if (aircraft.intent.assignedRunwayId != departureRunwayId) return false;
      final dx = aircraft.xNm - departureThreshold.xNm;
      final dy = aircraft.yNm - departureThreshold.yNm;
      return dx * dx + dy * dy < 8 * 8;
    });
    return departureRolling && (crossingOccupied || departureOccupied);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final distance = (to - from).distance;
    if (distance <= 0) return;
    const dash = 8.0;
    const gap = 5.0;
    final direction = (to - from) / distance;
    var traveled = 0.0;
    while (traveled < distance) {
      final start = from + direction * traveled;
      final end = from + direction * math.min(traveled + dash, distance);
      canvas.drawLine(start, end, paint);
      traveled += dash + gap;
    }
  }

  String _runwayLabel(String runwayId) {
    final state = snapshot.runwayState(runwayId);
    if (state == null || !state.isOccupiedAt(snapshot.elapsed)) {
      return runwayId;
    }
    final remaining =
        state.occupiedUntil.inSeconds - snapshot.elapsed.inSeconds;
    return '$runwayId OCC ${remaining}s';
  }

  bool _runwayOccupied(String runwayId) {
    final state = snapshot.runwayState(runwayId);
    return state != null && state.isOccupiedAt(snapshot.elapsed);
  }

  bool _runwayActive(String runwayId) {
    final hasArrival = snapshot.aircraft.any((aircraft) {
      return aircraft.active &&
          aircraft.intent.assignedRunwayId == runwayId &&
          !aircraft.intent.isDeparture;
    });
    if (hasArrival) return true;
    return snapshot.aircraft.any((aircraft) {
      return aircraft.active &&
          aircraft.intent.assignedRunwayId == runwayId &&
          aircraft.intent.isDeparture;
    });
  }

  void _drawHoldPatterns(Canvas canvas, Offset center, double scale) {
    for (final pattern in snapshot.holdPatterns) {
      final fix = snapshot.waypoints[pattern.fixWaypointId];
      if (fix == null) continue;
      final position = _toCanvas(center, scale, fix.xNm, fix.yNm);
      final headingRad = pattern.inboundHeadingDeg * math.pi / 180;
      final along = Offset(math.sin(headingRad), -math.cos(headingRad));
      final across = Offset(along.dy, -along.dx);
      final length = (pattern.legSeconds / 60 * 4.5 * scale).clamp(26.0, 56.0);
      const width = 15.0;
      final path = Path()
        ..moveTo(
          position.dx - across.dx * width,
          position.dy - across.dy * width,
        )
        ..lineTo(
          position.dx + along.dx * length - across.dx * width,
          position.dy + along.dy * length - across.dy * width,
        )
        ..arcToPoint(
          Offset(
            position.dx + along.dx * length + across.dx * width,
            position.dy + along.dy * length + across.dy * width,
          ),
          radius: const Radius.circular(width),
        )
        ..lineTo(
          position.dx + across.dx * width,
          position.dy + across.dy * width,
        )
        ..arcToPoint(
          Offset(
            position.dx - across.dx * width,
            position.dy - across.dy * width,
          ),
          radius: const Radius.circular(width),
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x889B8CFF),
      );
      _drawAlertLabel(
        canvas,
        position.translate(8, 12),
        'HOLD ${pattern.id}',
        const Color(0xFF9B8CFF),
      );
    }
  }

  void _drawWaypoints(Canvas canvas, Offset center, double scale) {
    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x4446F5A7);
    for (final aircraft in snapshot.aircraft) {
      if (!aircraft.active || aircraft.intent.route.length < 2) continue;
      final routePath = Path();
      var started = false;
      for (final waypointId in aircraft.intent.route) {
        final waypoint = snapshot.waypoints[waypointId];
        if (waypoint == null) continue;
        final point = _toCanvas(center, scale, waypoint.xNm, waypoint.yNm);
        if (!started) {
          routePath.moveTo(point.dx, point.dy);
          started = true;
        } else {
          routePath.lineTo(point.dx, point.dy);
        }
      }
      if (started) canvas.drawPath(routePath, routePaint);
    }

    for (final waypoint in snapshot.waypoints.values) {
      final position = _toCanvas(center, scale, waypoint.xNm, waypoint.yNm);
      canvas.drawRect(
        Rect.fromCenter(center: position, width: 4, height: 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xAA46F5A7),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: waypoint.id,
          style: const TextStyle(
            color: Color(0x9946F5A7),
            fontSize: 8,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      painter.paint(canvas, position.translate(5, -5));
    }
  }

  void _drawSweep(Canvas canvas, Offset center, double radius) {
    final end = center.translate(
      math.sin(sweepAngleRad) * radius,
      -math.cos(sweepAngleRad) * radius,
    );
    canvas.drawLine(
      center,
      end,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x8846F5A7),
    );

    final wedge = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        sweepAngleRad - math.pi / 2 - 0.18,
        0.36,
        false,
      )
      ..close();
    canvas.drawPath(
      wedge,
      Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0x1246F5A7),
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
    canvas.drawCircle(
      position,
      alertPulse ? 18 : 14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = paint.color.withValues(alpha: alertPulse ? 0.55 : 0.24),
    );
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
    _drawClosureArrow(canvas, center, scale, conflict, paint);
  }

  void _drawClosureArrow(
    Canvas canvas,
    Offset center,
    double scale,
    SeparationResult conflict,
    Paint paint,
  ) {
    final a = snapshot.aircraftById(conflict.aircraftAId);
    final b = snapshot.aircraftById(conflict.aircraftBId);
    final x = conflict.conflictXNm;
    final y = conflict.conflictYNm;
    if (a == null || b == null || x == null || y == null) return;
    final conflictPoint = _toCanvas(center, scale, x, y);
    for (final aircraft in [a, b]) {
      final position = _toCanvas(center, scale, aircraft.xNm, aircraft.yNm);
      final arrowEnd = Offset.lerp(position, conflictPoint, 0.35)!;
      canvas.drawLine(position, arrowEnd, paint..strokeWidth = 1.2);
      final angle =
          math.atan2(arrowEnd.dy - position.dy, arrowEnd.dx - position.dx);
      final left = arrowEnd.translate(
        -math.cos(angle - 0.45) * 6,
        -math.sin(angle - 0.45) * 6,
      );
      final right = arrowEnd.translate(
        -math.cos(angle + 0.45) * 6,
        -math.sin(angle + 0.45) * 6,
      );
      canvas.drawLine(arrowEnd, left, paint);
      canvas.drawLine(arrowEnd, right, paint);
    }
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

  AircraftState _interpolatedAircraft(AircraftState current) {
    final previous = previousSnapshot?.aircraftById(current.id);
    if (previous == null || !previous.active) return current;
    final rawT = interpolation.clamp(0, 1).toDouble();
    final t = rawT * rawT * (3 - 2 * rawT);
    return current.copyWith(
      xNm: _lerp(previous.xNm, current.xNm, t),
      yNm: _lerp(previous.yNm, current.yNm, t),
      altitudeFt: _lerp(previous.altitudeFt, current.altitudeFt, t).round(),
      headingDeg: _lerpAngle(previous.headingDeg, current.headingDeg, t),
      groundSpeedKt: _lerp(previous.groundSpeedKt, current.groundSpeedKt, t),
    );
  }

  double _sweepPulseFor(AircraftState aircraft) {
    final targetAngle = math.atan2(aircraft.xNm, aircraft.yNm);
    final delta =
        (((targetAngle - sweepAngleRad) + math.pi * 3) % (math.pi * 2)) -
            math.pi;
    final distance = delta.abs();
    if (distance > 0.22) return 0;
    return 1 - distance / 0.22;
  }

  double _lerp(num a, num b, double t) => a + (b - a) * t;

  double _lerpAngle(double a, double b, double t) {
    final delta = ((b - a + 540) % 360) - 180;
    final value = a + delta * t;
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  @override
  bool shouldRepaint(covariant RadarV2Painter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.previousSnapshot != previousSnapshot ||
        oldDelegate.interpolation != interpolation ||
        oldDelegate.rangeNm != rangeNm ||
        oldDelegate.selectedAircraftId != selectedAircraftId ||
        oldDelegate.recentlyCommandedAircraftId !=
            recentlyCommandedAircraftId ||
        oldDelegate.alertPulse != alertPulse ||
        oldDelegate.sweepEnabled != sweepEnabled ||
        oldDelegate.sweepAngleRad != sweepAngleRad;
  }
}

enum _ConflictUrgency {
  normal,
  predicted,
  urgent,
  loss,
}
