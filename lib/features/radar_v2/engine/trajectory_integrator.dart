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
    double verticalProfileVariationFpm = 0,
    double weatherTurbulence = 0,
  }) {
    final type = performance?.type ?? aircraft.performanceType;
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
    final inertiaFactor = _inertiaFactor(type);
    final degradedTurnRate =
        (effectiveTurnRate * pressureDegradation) / inertiaFactor;
    final degradedAcceleration =
        (effectiveAcceleration * pressureDegradation) / inertiaFactor;

    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    final bankLimit = _bankLimitDeg(
      type,
      aircraft.groundSpeedKt,
      weatherTurbulence,
    );
    final bankLimitedTurnRate = math.min(
      degradedTurnRate,
      _turnRateFromBankLimit(
        bankLimitDeg: bankLimit,
        speedKt: aircraft.groundSpeedKt,
      ),
    );
    final speedOvershootBias =
        ((aircraft.groundSpeedKt - 250) / 170).clamp(0.0, 1.0);
    final rollResponse =
        (1.0 - 0.18 * speedOvershootBias - (inertiaFactor - 1.0) * 0.5)
            .clamp(0.55, 1.05);
    final turn = _approachAngle(
      aircraft.headingDeg,
      aircraft.intent.assignedHeadingDeg ?? aircraft.headingDeg,
      bankLimitedTurnRate * seconds,
      currentTurnRateDegPerSecond: aircraft.turnRateDegPerSecond,
      turnAccelerationDegPerSecond2:
          effectiveTurnAcceleration * pressureDegradation,
      stepSeconds: seconds,
      rollResponse: rollResponse,
      overshootBias: speedOvershootBias,
    );
    final speed = _approachSpeed(
      aircraft.groundSpeedKt,
      aircraft.intent.assignedSpeedKt ?? aircraft.groundSpeedKt,
      accelerationKtPerSecond: degradedAcceleration,
      speedAccelerationKtPerSecond2:
          effectiveSpeedAcceleration * pressureDegradation,
      currentSpeedTrendKtPerSecond: aircraft.speedTrendKtPerSecond,
      stepSeconds: seconds,
      turbulenceFactor: weatherTurbulence,
      inertiaFactor: inertiaFactor,
      overshootBias: speedOvershootBias,
    );
    final nextAltitude = _advanceAltitude(
      aircraft,
      seconds,
      climbRateFpm: effectiveClimbRate,
      descentRateFpm: effectiveDescentRate,
      verticalProfileVariationFpm: verticalProfileVariationFpm,
      turbulenceFactor: weatherTurbulence,
      inertiaFactor: inertiaFactor,
    );

    final movementHeading = _normalizeHeading(turn.headingDeg + trackWobbleDeg);
    final movementSpeed = (speed.speedKt + groundSpeedVariationKt)
      .clamp(80.0, 520.0);
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
    required double verticalProfileVariationFpm,
    required double turbulenceFactor,
    required double inertiaFactor,
  }) {
    final target = aircraft.intent.assignedAltitudeFt;
    if (target == null) {
      final settleRate = _approachScalar(
        aircraft.verticalSpeedFpm.toDouble(),
        0,
        (420 / inertiaFactor) * seconds,
      );
      final altitude = aircraft.altitudeFt + settleRate * seconds / 60;
      return (altitude.round(), settleRate.round());
    }

    final delta = target - aircraft.altitudeFt;
    if (delta == 0 && aircraft.verticalSpeedFpm.abs() <= 35) {
      return (target, 0);
    }

    var desiredRateFpm = delta > 0 ? climbRateFpm.toDouble() : -descentRateFpm.toDouble();

    if (delta < 0 &&
        aircraft.verticalSpeedFpm > -220 &&
        delta.abs() > 900) {
      // Descent planning lag: some aircraft initiate descent conservatively.
      desiredRateFpm *= 0.58;
    }

    if (delta.abs() < 1300) {
      final approach = (delta.abs() / 1300).clamp(0.14, 1.0);
      desiredRateFpm *= approach;
    }

    final verticalAccel = (480 / inertiaFactor) * (1 - turbulenceFactor * 0.22);
    var nextRateFpm = _approachScalar(
      aircraft.verticalSpeedFpm.toDouble(),
      desiredRateFpm,
      verticalAccel.clamp(180.0, 620.0) * seconds,
    );
    nextRateFpm += verticalProfileVariationFpm * 0.18;

    var nextAltitude = aircraft.altitudeFt + nextRateFpm * seconds / 60;
    if (_crossed(aircraft.altitudeFt.toDouble(), target.toDouble(), nextAltitude)) {
      final overshootFt = (nextAltitude - target).abs();
      if (overshootFt < 24 && nextRateFpm.abs() < 120) {
        return (target, 0);
      }
      final oscillationFactor = (0.24 + turbulenceFactor * 0.22 + (inertiaFactor - 1) * 0.12)
          .clamp(0.18, 0.52);
      nextRateFpm *= -(0.28 + oscillationFactor);
      nextAltitude = target + (nextAltitude - target) * (0.18 + oscillationFactor);
    }

    if ((nextAltitude - target).abs() < 55 && nextRateFpm.abs() < 90) {
      return (target, 0);
    }
    return (nextAltitude.round(), nextRateFpm.round());
  }

  _SpeedStep _approachSpeed(
    double current,
    double target, {
    required double accelerationKtPerSecond,
    required double speedAccelerationKtPerSecond2,
    required double currentSpeedTrendKtPerSecond,
    required double stepSeconds,
    required double turbulenceFactor,
    required double inertiaFactor,
    required double overshootBias,
  }) {
    final delta = target - current;
    if (delta.abs() < 0.05 && currentSpeedTrendKtPerSecond.abs() < 0.05) {
      return _SpeedStep(target, 0);
    }

    // Deceleration is intentionally a bit slower than acceleration to avoid
    // robotic speed snaps and create inertia for heavier aircraft behavior.
    final accelRate =
      accelerationKtPerSecond * (1 - turbulenceFactor * 0.18);
    final decelRate =
      accelerationKtPerSecond * 0.72 * (1 - turbulenceFactor * 0.24);
    final maxRate = delta > 0 ? accelRate : decelRate;
    var desiredTrend = delta.sign * maxRate;

    // Near target, ease in to avoid abrupt final locking.
    if (delta.abs() < 12) {
      desiredTrend *= (0.25 + delta.abs() / 16).clamp(0.25, 1.0);
    }

    final trendStep = speedAccelerationKtPerSecond2 * stepSeconds;
    var nextTrend =
        _approachScalar(
      currentSpeedTrendKtPerSecond,
      desiredTrend,
      (trendStep / inertiaFactor).clamp(0.08, trendStep),
    );
    var nextSpeed = current + nextTrend * stepSeconds;

    if (_crossed(current, target, nextSpeed)) {
      final overshoot = (nextSpeed - target).abs();
      final lockThreshold = 0.45 + overshootBias * 0.8;
      if (overshoot < lockThreshold && nextTrend.abs() < 0.35) {
        return _SpeedStep(target, 0);
      }
      final rebound = (0.35 - overshootBias * 0.14).clamp(0.2, 0.38);
      nextTrend *= -rebound;
      final retain = (0.28 + overshootBias * 0.22).clamp(0.2, 0.5);
      nextSpeed = target + (nextSpeed - target) * retain;
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
    required double rollResponse,
    required double overshootBias,
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
      turnAccelerationDegPerSecond2 * stepSeconds * rollResponse,
    );
    var nextHeading = current + nextRate * stepSeconds;

    if (_headingCrossed(current, target, nextHeading)) {
      final overshoot = _shortestAngleDelta(target, nextHeading).abs();
      final lockThreshold = 0.25 + overshootBias * 0.9;
      if (overshoot < lockThreshold && nextRate.abs() < 0.35) {
        return _TurnStep(target, 0);
      }
      // Keep a small overshoot/settle feel, but damp the reversal quickly so
      // aircraft remain predictable and controller-safe.
      final rebound = (0.42 - overshootBias * 0.16).clamp(0.24, 0.44);
      nextRate *= -rebound;
      final settle = (0.35 + overshootBias * 0.22).clamp(0.28, 0.58);
      nextHeading = target + _shortestAngleDelta(target, nextHeading) * settle;
    }
    return _TurnStep(nextHeading, nextRate);
  }

  double _inertiaFactor(AircraftPerformanceType type) {
    return switch (type) {
      AircraftPerformanceType.heavy => 1.42,
      AircraftPerformanceType.jet => 1.22,
      AircraftPerformanceType.regional => 1.0,
      AircraftPerformanceType.turboprop => 0.86,
    };
  }

  double _bankLimitDeg(
    AircraftPerformanceType type,
    double speedKt,
    double turbulence,
  ) {
    final base = switch (type) {
      AircraftPerformanceType.heavy => 21.0,
      AircraftPerformanceType.jet => 24.0,
      AircraftPerformanceType.regional => 27.0,
      AircraftPerformanceType.turboprop => 30.0,
    };
    final speedPenalty = ((speedKt - 260) / 130).clamp(0.0, 1.0) * 2.6;
    final turbulencePenalty = turbulence.clamp(0.0, 1.0) * 1.2;
    return (base - speedPenalty - turbulencePenalty).clamp(19.0, 31.0);
  }

  double _turnRateFromBankLimit({
    required double bankLimitDeg,
    required double speedKt,
  }) {
    final speed = speedKt.clamp(120.0, 520.0);
    final rate = (1091.0 * math.tan(bankLimitDeg * math.pi / 180)) / speed;
    return rate.clamp(1.2, 4.2);
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
