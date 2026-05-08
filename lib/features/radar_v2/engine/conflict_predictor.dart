import 'dart:math' as math;

import '../models/aircraft_state.dart';
import '../models/separation_result.dart';

class ConflictPredictor {
  final double minimumLateralNm;
  final int minimumVerticalFt;
  final Duration lookahead;

  const ConflictPredictor({
    this.minimumLateralNm = 5,
    this.minimumVerticalFt = 1000,
    this.lookahead = const Duration(minutes: 8),
  });

  /// Under high pressure (sectorPressureIndex > 2.0), some conflicts may be
  /// missed or detected late due to controller workload saturation.
  /// This increases the effective conflict thresholds, making conflicts harder to detect.
  List<SeparationResult> predictPairs(
    List<AircraftState> aircraft, {
    double pressureIndex = 0,
  }) {
    final active =
        aircraft.where((target) => target.active).toList(growable: false);
    final results = <SeparationResult>[];
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        final prediction =
            predict(active[i], active[j], pressureIndex: pressureIndex);
        if (prediction != null) results.add(prediction);
      }
    }
    return results;
  }

  SeparationResult? predict(
    AircraftState a,
    AircraftState b, {
    double pressureIndex = 0,
  }) {
    final ax = a.xNm;
    final ay = a.yNm;
    final bx = b.xNm;
    final by = b.yNm;
    final av = _velocityNmPerSecond(a);
    final bv = _velocityNmPerSecond(b);
    final rx = ax - bx;
    final ry = ay - by;
    final vx = av.$1 - bv.$1;
    final vy = av.$2 - bv.$2;
    final relativeSpeedSquared = vx * vx + vy * vy;

    final closestSeconds = relativeSpeedSquared == 0
        ? 0.0
        : (-(rx * vx + ry * vy) / relativeSpeedSquared)
            .clamp(0.0, lookahead.inSeconds.toDouble());

    final closestAx = ax + av.$1 * closestSeconds;
    final closestAy = ay + av.$2 * closestSeconds;
    final closestBx = bx + bv.$1 * closestSeconds;
    final closestBy = by + bv.$2 * closestSeconds;
    final lateral = math.sqrt(
      math.pow(closestAx - closestBx, 2) + math.pow(closestAy - closestBy, 2),
    );
    final vertical =
        _verticalAt(a, closestSeconds) - _verticalAt(b, closestSeconds);

    // Under high pressure, increase effective thresholds (harder to detect)
    final pressureFactor = _getPressureFactor(pressureIndex);
    final effectiveMinLateral = minimumLateralNm * pressureFactor;
    final effectiveMinVertical = minimumVerticalFt * pressureFactor;

    if (lateral >= effectiveMinLateral ||
        vertical.abs() >= effectiveMinVertical) {
      return null;
    }

    return SeparationResult(
      aircraftAId: a.id,
      aircraftBId: b.id,
      lateralNm: lateral,
      verticalFt: vertical.abs().round(),
      isLossOfSeparation: false,
      isPredictedConflict: true,
      timeToConflict: Duration(seconds: closestSeconds.round()),
      conflictXNm: (closestAx + closestBx) / 2,
      conflictYNm: (closestAy + closestBy) / 2,
    );
  }

  /// Returns a factor by which to multiply thresholds under pressure.
  /// At pressure 0–1.0: factor = 1.0 (normal detection)
  /// At pressure 1.0–2.0: factor = 1.0–1.3 (slightly reduced)
  /// At pressure 2.0–3.0: factor = 1.3–1.6 (moderately reduced)
  /// At pressure 3.0+: factor = 1.6+ (severely reduced)
  double _getPressureFactor(double pressureIndex) {
    if (pressureIndex <= 1.0) return 1.0;
    final excessPressure = (pressureIndex - 1.0).clamp(0, 2);
    return 1.0 + (excessPressure * 0.3);
  }

  (double, double) _velocityNmPerSecond(AircraftState aircraft) {
    final headingRad = aircraft.headingDeg * math.pi / 180;
    final nmPerSecond = aircraft.groundSpeedKt / 3600;
    return (
      math.sin(headingRad) * nmPerSecond,
      math.cos(headingRad) * nmPerSecond,
    );
  }

  double _verticalAt(AircraftState aircraft, double seconds) {
    return aircraft.altitudeFt + aircraft.verticalSpeedFpm * seconds / 60;
  }
}
