import 'dart:math' as math;

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
  }) {
    final seconds = step.inMicroseconds / Duration.microsecondsPerSecond;
    final nextHeading = _approachAngle(
      aircraft.headingDeg,
      aircraft.intent.assignedHeadingDeg ?? aircraft.headingDeg,
      turnRateDegPerSecond * seconds,
    );
    final nextSpeed = _approachDouble(
      aircraft.groundSpeedKt,
      aircraft.intent.assignedSpeedKt ?? aircraft.groundSpeedKt,
      accelerationKtPerSecond * seconds,
    );
    final nextAltitude = _advanceAltitude(
      aircraft,
      seconds,
      climbRateFpm: climbRateFpm,
      descentRateFpm: descentRateFpm,
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

  double _approachDouble(double current, double target, double maxStep) {
    final delta = target - current;
    if (delta.abs() <= maxStep) return target;
    return current + maxStep * delta.sign;
  }

  double _approachAngle(double current, double target, double maxStep) {
    final delta = _shortestAngleDelta(current, target);
    if (delta.abs() <= maxStep) return target;
    return current + maxStep * delta.sign;
  }

  double _shortestAngleDelta(double fromDeg, double toDeg) {
    return ((toDeg - fromDeg + 540) % 360) - 180;
  }

  double _normalizeHeading(double headingDeg) {
    final normalized = headingDeg % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }
}
