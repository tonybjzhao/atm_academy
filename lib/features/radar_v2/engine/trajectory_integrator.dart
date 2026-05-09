import 'dart:math' as math;

import '../models/aircraft_performance_profile.dart';
import '../models/aircraft_state.dart';

class TrajectoryIntegrator {
  static const double defaultTurnRateDegPerSecond = 3;
  static const double defaultAccelerationKtPerSecond = 3;
  static const int defaultClimbRateFpm = 1800;
  static const int defaultDescentRateFpm = 2200;

  const TrajectoryIntegrator();

  AircraftState advance(
    AircraftState aircraft,
    Duration step, {
    double turnRateDegPerSecond = defaultTurnRateDegPerSecond,
    double accelerationKtPerSecond = defaultAccelerationKtPerSecond,
    int climbRateFpm = defaultClimbRateFpm,
    int descentRateFpm = defaultDescentRateFpm,
    AircraftPerformanceProfile? performance,
    double pressureIndex = 0,
    double trackWobbleDeg = 0,
    double groundSpeedVariationKt = 0,
  }) {
    final effectiveTurnRate =
        performance?.turnRateDegPerSecond ?? turnRateDegPerSecond;
    final effectiveTurnAcceleration =
        performance?.turnAccelerationDegPerSecond2 ?? effectiveTurnRate;
    final effectiveAcceleration =
        performance?.accelerationKtPerSecond ?? accelerationKtPerSecond;
    final effectiveSpeedAcceleration =
        performance?.speedAccelerationKtPerSecond2 ?? effectiveAcceleration;
    final effectiveClimbRate = performance?.climbRateFpm ?? climbRateFpm;
    final effectiveDescentRate = performance?.descentRateFpm ?? descentRateFpm;

    // Under high pressure, reduce responsiveness (degraded command efficiency)
    final pressureDegradation = _getResponsivenessDegradation(pressureIndex);
    final degradedTurnRate = effectiveTurnRate * pressureDegradation;
    final degradedAcceleration = effectiveAcceleration * pressureDegradation;

    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    final turn = _approachAngle(
      aircraft.headingDeg,
      aircraft.intent.assignedHeadingDeg ?? aircraft.headingDeg,
      degradedTurnRate * seconds,
      currentTurnRateDegPerSecond: aircraft.turnRateDegPerSecond,
      turnAccelerationDegPerSecond2:
          effectiveTurnAcceleration * pressureDegradation,
      stepSeconds: seconds,
    );
    final speed = _approachSpeed(
      aircraft.groundSpeedKt,
      aircraft.intent.assignedSpeedKt ?? aircraft.groundSpeedKt,
      accelerationKtPerSecond: degradedAcceleration,
      speedAccelerationKtPerSecond2:
          effectiveSpeedAcceleration * pressureDegradation,
      currentSpeedTrendKtPerSecond: aircraft.speedTrendKtPerSecond,
      stepSeconds: seconds,
    );
    final nextAltitude = _advanceAltitude(
      aircraft,
      seconds,
      climbRateFpm: effectiveClimbRate,
      descentRateFpm: effectiveDescentRate,
    );

    final movementHeading = _normalizeHeading(turn.headingDeg + trackWobbleDeg);
    final movementSpeed =
        (speed.speedKt + groundSpeedVariationKt).clamp(80.0, 520.0);
    final headingRad = movementHeading * math.pi / 180;
    final distanceNm = movementSpeed * seconds / 3600;
    final dx = math.sin(headingRad) * distanceNm;
    final dy = math.cos(headingRad) * distanceNm;

    return aircraft.copyWith(
      xNm: aircraft.xNm + dx,
      yNm: aircraft.yNm + dy,
      altitudeFt: nextAltitude.$1,
      headingDeg: _normalizeHeading(turn.headingDeg),
      groundSpeedKt: speed.speedKt,
      verticalSpeedFpm: nextAltitude.$2,
      turnRateDegPerSecond: turn.turnRateDegPerSecond,
      speedTrendKtPerSecond: speed.speedTrendKtPerSecond,
    );
  }

  /// Returns a factor by which to multiply responsiveness under pressure.
  /// At pressure 0–1.0: factor = 1.0 (normal responsiveness)
  /// At pressure 1.0–2.0: factor = 0.85–0.7 (10–30% reduction)
  /// At pressure 2.0–3.0: factor = 0.7–0.55 (30–45% reduction)
  /// At pressure 3.0+: factor = 0.55 (45% reduction)
  double _getResponsivenessDegradation(double pressureIndex) {
    if (pressureIndex <= 1.0) return 1.0;
    final excessPressure = (pressureIndex - 1.0).clamp(0, 2);
    return 1.0 - (excessPressure * 0.225); // 0 to 0.45 reduction
  }

  (int, int) _advanceAltitude(
    AircraftState aircraft,
    double seconds, {
    required int climbRateFpm,
    required int descentRateFpm,
  }) {
    final target = aircraft.intent.assignedAltitudeFt;
    if (target == null || target == aircraft.altitudeFt) {
      return (aircraft.altitudeFt, 0);
    }

    final delta = target - aircraft.altitudeFt;
    final rate = delta > 0 ? climbRateFpm : -descentRateFpm;
    final stepFeet = rate * seconds / 60;
    if (stepFeet.abs() >= delta.abs()) {
      return (target, 0);
    }
    return ((aircraft.altitudeFt + stepFeet).round(), rate);
  }

  _SpeedStep _approachSpeed(
    double current,
    double target, {
    required double accelerationKtPerSecond,
    required double speedAccelerationKtPerSecond2,
    required double currentSpeedTrendKtPerSecond,
    required double stepSeconds,
  }) {
    final delta = target - current;
    if (delta.abs() < 0.05 && currentSpeedTrendKtPerSecond.abs() < 0.05) {
      return _SpeedStep(target, 0);
    }

    // Deceleration is intentionally a bit slower than acceleration to avoid
    // robotic speed snaps and create inertia for heavier aircraft behavior.
    final accelRate = accelerationKtPerSecond;
    final decelRate = accelerationKtPerSecond * 0.72;
    final maxRate = delta > 0 ? accelRate : decelRate;
    var desiredTrend = delta.sign * maxRate;

    // Near target, ease in to avoid abrupt final locking.
    if (delta.abs() < 12) {
      desiredTrend *= (0.25 + delta.abs() / 16).clamp(0.25, 1.0);
    }

    final trendStep = speedAccelerationKtPerSecond2 * stepSeconds;
    var nextTrend =
        _approachScalar(currentSpeedTrendKtPerSecond, desiredTrend, trendStep);
    var nextSpeed = current + nextTrend * stepSeconds;

    if (_crossed(current, target, nextSpeed)) {
      final overshoot = (nextSpeed - target).abs();
      if (overshoot < 0.45 && nextTrend.abs() < 0.35) {
        return _SpeedStep(target, 0);
      }
      nextTrend *= -0.35;
      nextSpeed = target + (nextSpeed - target) * 0.28;
    }
    return _SpeedStep(nextSpeed, nextTrend);
  }

  _TurnStep _approachAngle(
    double current,
    double target,
    double maxStep, {
    required double currentTurnRateDegPerSecond,
    required double turnAccelerationDegPerSecond2,
    required double stepSeconds,
  }) {
    final delta = _shortestAngleDelta(current, target);
    final absDelta = delta.abs();
    if (absDelta < 0.08 && currentTurnRateDegPerSecond.abs() < 0.08) {
      return _TurnStep(target, 0);
    }

    // Large heading changes begin assertively (anticipation), then taper near
    // capture (rollout smoothing) to reduce robotic heading snaps.
    final anticipationFactor = absDelta > 40
        ? 1.12
        : absDelta > 20
            ? 1.0
            : 0.72;
    final rolloutFactor = absDelta < 8 ? (0.35 + (absDelta / 8) * 0.65) : 1.0;
    final maxTurnRate = maxStep / stepSeconds;
    final desiredRate =
        delta.sign * maxTurnRate * anticipationFactor * rolloutFactor;
    var nextRate = _approachScalar(
      currentTurnRateDegPerSecond,
      desiredRate,
      turnAccelerationDegPerSecond2 * stepSeconds,
    );
    var nextHeading = current + nextRate * stepSeconds;

    if (_headingCrossed(current, target, nextHeading)) {
      final overshoot = _shortestAngleDelta(target, nextHeading).abs();
      if (overshoot < 0.25 && nextRate.abs() < 0.35) {
        return _TurnStep(target, 0);
      }
      // Keep a small overshoot/settle feel, but damp the reversal quickly so
      // aircraft remain predictable and controller-safe.
      nextRate *= -0.42;
      nextHeading = target + _shortestAngleDelta(target, nextHeading) * 0.35;
    }
    return _TurnStep(nextHeading, nextRate);
  }

  double _approachScalar(double current, double target, double maxStep) {
    final delta = target - current;
    if (delta.abs() <= maxStep) return target;
    return current + maxStep * delta.sign;
  }

  bool _crossed(double from, double target, double to) {
    return (target - from).sign != (target - to).sign && target != from;
  }

  bool _headingCrossed(double from, double target, double to) {
    final before = _shortestAngleDelta(from, target);
    final after = _shortestAngleDelta(to, target);
    return before != 0 && before.sign != after.sign;
  }

  double _shortestAngleDelta(double fromDeg, double toDeg) {
    return ((toDeg - fromDeg + 540) % 360) - 180;
  }

  double _normalizeHeading(double headingDeg) {
    final normalized = headingDeg % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }
}

class _TurnStep {
  final double headingDeg;
  final double turnRateDegPerSecond;

  const _TurnStep(this.headingDeg, this.turnRateDegPerSecond);
}

class _SpeedStep {
  final double speedKt;
  final double speedTrendKtPerSecond;

  const _SpeedStep(this.speedKt, this.speedTrendKtPerSecond);
}
