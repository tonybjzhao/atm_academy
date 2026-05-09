import 'dart:math' as math;

import '../models/aircraft_state.dart';

class PredictiveVectorStyle {
  final double projectedLengthPx;
  final double turnArcRadiusPx;
  final double turnArcSweepRad;
  final double turnDirection;
  final SpeedTrendIndicator speedTrend;

  const PredictiveVectorStyle({
    required this.projectedLengthPx,
    required this.turnArcRadiusPx,
    required this.turnArcSweepRad,
    required this.turnDirection,
    required this.speedTrend,
  });
}

class ClosureVisualStyle {
  final double closureRateKt;
  final double convergenceStrength;
  final double leadFraction;
  final double strokeWidth;
  final bool showCompressionHint;

  const ClosureVisualStyle({
    required this.closureRateKt,
    required this.convergenceStrength,
    required this.leadFraction,
    required this.strokeWidth,
    required this.showCompressionHint,
  });
}

class ReplayPredictionStyle {
  final double conflictEmphasisOpacity;
  final double compressionGlow;

  const ReplayPredictionStyle({
    required this.conflictEmphasisOpacity,
    required this.compressionGlow,
  });
}

enum SpeedTrendIndicator {
  accelerating,
  decelerating,
  stable,
}

class RadarPredictiveVisuals {
  static PredictiveVectorStyle vectorStyle({
    required AircraftState aircraft,
    required double scalePxPerNm,
    required bool replayMode,
    required bool selected,
  }) {
    final minutesAhead = selected ? 1.4 : 1.1;
    final predictedNm =
        (aircraft.groundSpeedKt / 60.0 * minutesAhead).clamp(0.5, 3.2);
    final speedTrendAdj = 1 + aircraft.speedTrendKtPerSecond * 0.025;
    final replayAdj = replayMode ? 1.08 : 1.0;
    final length =
        (predictedNm * scalePxPerNm * speedTrendAdj * replayAdj).clamp(10.0, 86.0);

    final assigned = aircraft.intent.assignedHeadingDeg;
    final headingDelta =
        assigned == null ? 0.0 : _signedAngleDeltaDeg(aircraft.headingDeg, assigned);
    final turnMag = headingDelta.abs();
    final turnSweep = (turnMag * math.pi / 180).clamp(0.0, math.pi * 0.72);
    final turnDir = headingDelta == 0
        ? 0.0
        : (headingDelta.isNegative ? -1.0 : 1.0);

    final trend = aircraft.speedTrendKtPerSecond > 0.16
        ? SpeedTrendIndicator.accelerating
        : aircraft.speedTrendKtPerSecond < -0.16
            ? SpeedTrendIndicator.decelerating
            : SpeedTrendIndicator.stable;

    return PredictiveVectorStyle(
      projectedLengthPx: length,
      turnArcRadiusPx: (14 + turnMag * 0.22).clamp(12.0, 34.0),
      turnArcSweepRad: turnSweep,
      turnDirection: turnDir,
      speedTrend: trend,
    );
  }

  static ClosureVisualStyle closureStyle({
    required AircraftState a,
    required AircraftState b,
    required bool replayMode,
  }) {
    final dx = b.xNm - a.xNm;
    final dy = b.yNm - a.yNm;
    final distance = math.max(0.1, math.sqrt(dx * dx + dy * dy));
    final ux = dx / distance;
    final uy = dy / distance;

    final va = _velocityNmPerMinute(a.headingDeg, a.groundSpeedKt);
    final vb = _velocityNmPerMinute(b.headingDeg, b.groundSpeedKt);
    final rel = _Vec2(vb.dx - va.dx, vb.dy - va.dy);

    final closingNmPerMinute = -((rel.dx * ux) + (rel.dy * uy));
    final closureKt = (closingNmPerMinute * 60).clamp(0.0, 360.0);
    final strength = (closureKt / 220.0).clamp(0.0, 1.0);
    final lead = (0.24 + strength * 0.26 + (replayMode ? 0.04 : 0.0))
        .clamp(0.2, 0.62);

    return ClosureVisualStyle(
      closureRateKt: closureKt,
      convergenceStrength: strength,
      leadFraction: lead,
      strokeWidth: (1.0 + strength * 1.4).clamp(1.0, 2.6),
      showCompressionHint: closureKt > 95,
    );
  }

  static ReplayPredictionStyle replayStyle({
    required Duration? currentTtc,
    required Duration? previousTtc,
  }) {
    final cur = (currentTtc?.inSeconds ?? 999).toDouble();
    final prev = (previousTtc?.inSeconds ?? cur).toDouble();
    final compression = (prev - cur).clamp(-60.0, 60.0);
    final compressionNorm = (compression / 60.0).clamp(0.0, 1.0);
    final urgency = (1 - (cur / 180.0)).clamp(0.0, 1.0);

    return ReplayPredictionStyle(
      conflictEmphasisOpacity: (0.18 + urgency * 0.42).clamp(0.18, 0.6),
      compressionGlow: (0.08 + compressionNorm * 0.34).clamp(0.08, 0.42),
    );
  }

  static _Vec2 _velocityNmPerMinute(double headingDeg, double speedKt) {
    final rad = headingDeg * math.pi / 180;
    final speedNmPerMinute = speedKt / 60.0;
    return _Vec2(
      math.sin(rad) * speedNmPerMinute,
      math.cos(rad) * speedNmPerMinute,
    );
  }

  static double _signedAngleDeltaDeg(double fromDeg, double toDeg) {
    var delta = (toDeg - fromDeg) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }
}

class _Vec2 {
  final double dx;
  final double dy;

  const _Vec2(this.dx, this.dy);
}
