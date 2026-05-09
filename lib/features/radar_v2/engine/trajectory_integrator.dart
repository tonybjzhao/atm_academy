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
  }) {
    final effectiveTurnRate =
        performance?.turnRateDegPerSecond ?? turnRateDegPerSecond;
    final effectiveAcceleration =
        performance?.accelerationKtPerSecond ?? accelerationKtPerSecond;
    final effectiveClimbRate = performance?.climbRateFpm ?? climbRateFpm;
    final effectiveDescentRate = performance?.descentRateFpm ?? descentRateFpm;

    // Under high pressure, reduce responsiveness (degraded command efficiency)
    final pressureDegradation = _getResponsivenessDegradation(pressureIndex);
    final degradedTurnRate = effectiveTurnRate * pressureDegradation;
    final degradedAcceleration = effectiveAcceleration * pressureDegradation;

    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    final nextHeading = _approachAngle(
      aircraft.headingDeg,
      aircraft.intent.assignedHeadingDeg ?? aircraft.headingDeg,
      degradedTurnRate * seconds,
      pressureIndex: pressureIndex,
    );
    final nextSpeed = _approachSpeed(
      aircraft.groundSpeedKt,
      aircraft.intent.assignedSpeedKt ?? aircraft.groundSpeedKt,
      accelerationKtPerSecond: degradedAcceleration,
      stepSeconds: seconds,
      pressureIndex: pressureIndex,
    );
    final nextAltitude = _advanceAltitude(
      aircraft,
      seconds,
      climbRateFpm: effectiveClimbRate,
      descentRateFpm: effectiveDescentRate,
    );

    final headingRad = nextHeading * math.pi / 180;
    final distanceNm = nextSpeed * seconds / 3600;
    final dx = math.sin(headingRad) * distanceNm;
    final dy = math.cos(headingRad) * distanceNm;

    return aircraft.copyWith(
      xNm: aircraft.xNm + dx,
      yNm: aircraft.yNm + dy,
      altitudeFt: nextAltitude.$1,
      headingDeg: _normalizeHeading(nextHeading),
      groundSpeedKt: nextSpeed,
      verticalSpeedFpm: nextAltitude.$2,
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

  double _approachSpeed(
    double current,
    double target, {
    required double accelerationKtPerSecond,
    required double stepSeconds,
    required double pressureIndex,
  }) {
    final delta = target - current;
    if (delta.abs() < 0.05) return target;

    // Preserve baseline deterministic speed response at low pressure.
    if (pressureIndex < 0.8) {
      final maxStep = accelerationKtPerSecond * stepSeconds;
      if (delta.abs() <= maxStep) return target;
      return current + maxStep * delta.sign;
    }

    // Deceleration is intentionally a bit slower than acceleration to avoid
    // robotic speed snaps and create inertia for heavier aircraft behavior.
    final accelRate = accelerationKtPerSecond;
    final decelRate = accelerationKtPerSecond * 0.72;
    final rate = delta > 0 ? accelRate : decelRate;
    final maxStep = rate * stepSeconds;

    // Near target, ease in to avoid abrupt final locking.
    final damping = delta.abs() < 10 ? (0.45 + delta.abs() / 20) : 1.0;
    final easedStep = maxStep * damping;

    if (delta.abs() <= easedStep) return target;
    return current + easedStep * delta.sign;
  }

  double _approachAngle(
    double current,
    double target,
    double maxStep, {
    required double pressureIndex,
  }) {
    final delta = _shortestAngleDelta(current, target);
    final absDelta = delta.abs();

    // Preserve baseline deterministic turn response at low pressure.
    if (pressureIndex < 0.8) {
      if (absDelta <= maxStep) return target;
      return current + maxStep * delta.sign;
    }

    // Large heading changes begin assertively (anticipation), then taper near
    // capture (rollout smoothing) to reduce robotic heading snaps.
    final anticipationFactor = absDelta > 40
        ? 1.12
        : absDelta > 20
            ? 1.0
            : 0.72;
    final rolloutFactor = absDelta < 8
        ? (0.35 + (absDelta / 8) * 0.65)
        : 1.0;
    final dynamicStep = maxStep * anticipationFactor * rolloutFactor;

    if (absDelta <= dynamicStep) return target;
    return current + dynamicStep * delta.sign;
  }

  double _shortestAngleDelta(double fromDeg, double toDeg) {
    return ((toDeg - fromDeg + 540) % 360) - 180;
  }

  double _normalizeHeading(double headingDeg) {
    final normalized = headingDeg % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }
}
