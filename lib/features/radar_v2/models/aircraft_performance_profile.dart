enum AircraftPerformanceType {
  jet,
  heavy,
  regional,
  turboprop,
}

enum WakeCategory {
  heavy,
  medium,
  light,
}

class AircraftPerformanceProfile {
  final AircraftPerformanceType type;
  final double turnRateDegPerSecond;
  final double turnAccelerationDegPerSecond2;
  final double accelerationKtPerSecond;
  final double speedAccelerationKtPerSecond2;
  final int climbRateFpm;
  final int descentRateFpm;
  final double approachSpeedKt;

  const AircraftPerformanceProfile({
    required this.type,
    required this.turnRateDegPerSecond,
    required this.turnAccelerationDegPerSecond2,
    required this.accelerationKtPerSecond,
    required this.speedAccelerationKtPerSecond2,
    required this.climbRateFpm,
    required this.descentRateFpm,
    required this.approachSpeedKt,
  });

  static const AircraftPerformanceProfile jet = AircraftPerformanceProfile(
    type: AircraftPerformanceType.jet,
    turnRateDegPerSecond: 3.0,
    turnAccelerationDegPerSecond2: 0.8,
    accelerationKtPerSecond: 3.0,
    speedAccelerationKtPerSecond2: 0.8,
    climbRateFpm: 1800,
    descentRateFpm: 2200,
    approachSpeedKt: 145,
  );

  static const AircraftPerformanceProfile heavy = AircraftPerformanceProfile(
    type: AircraftPerformanceType.heavy,
    turnRateDegPerSecond: 2.5,
    turnAccelerationDegPerSecond2: 0.58,
    accelerationKtPerSecond: 2.2,
    speedAccelerationKtPerSecond2: 0.52,
    climbRateFpm: 1500,
    descentRateFpm: 1900,
    approachSpeedKt: 160,
  );

  static const AircraftPerformanceProfile regional = AircraftPerformanceProfile(
    type: AircraftPerformanceType.regional,
    turnRateDegPerSecond: 3.4,
    turnAccelerationDegPerSecond2: 1.05,
    accelerationKtPerSecond: 2.4,
    speedAccelerationKtPerSecond2: 0.7,
    climbRateFpm: 1600,
    descentRateFpm: 1900,
    approachSpeedKt: 135,
  );

  static const AircraftPerformanceProfile turboprop =
      AircraftPerformanceProfile(
    type: AircraftPerformanceType.turboprop,
    turnRateDegPerSecond: 3.8,
    turnAccelerationDegPerSecond2: 1.35,
    accelerationKtPerSecond: 1.8,
    speedAccelerationKtPerSecond2: 0.55,
    climbRateFpm: 1300,
    descentRateFpm: 1500,
    approachSpeedKt: 120,
  );

  static AircraftPerformanceProfile byType(AircraftPerformanceType type) {
    switch (type) {
      case AircraftPerformanceType.jet:
        return jet;
      case AircraftPerformanceType.heavy:
        return heavy;
      case AircraftPerformanceType.regional:
        return regional;
      case AircraftPerformanceType.turboprop:
        return turboprop;
    }
  }

  static AircraftPerformanceType parseType(Object? value) {
    final text = value?.toString().toLowerCase();
    switch (text) {
      case 'heavy':
      case 'heavy_jet':
      case 'widebody':
        return AircraftPerformanceType.heavy;
      case 'regional':
        return AircraftPerformanceType.regional;
      case 'turboprop':
        return AircraftPerformanceType.turboprop;
      case 'jet':
      case null:
      case '':
        return AircraftPerformanceType.jet;
      default:
        throw FormatException('Unknown aircraft performance type: $value');
    }
  }

  static WakeCategory wakeCategoryForType(AircraftPerformanceType type) {
    switch (type) {
      case AircraftPerformanceType.heavy:
        return WakeCategory.heavy;
      case AircraftPerformanceType.jet:
      case AircraftPerformanceType.regional:
        return WakeCategory.medium;
      case AircraftPerformanceType.turboprop:
        return WakeCategory.light;
    }
  }

  static double wakeSpacingMultiplier({
    required AircraftPerformanceType leaderType,
    required AircraftPerformanceType followerType,
  }) {
    final leaderWake = wakeCategoryForType(leaderType);
    final followerWake = wakeCategoryForType(followerType);
    if (leaderWake == WakeCategory.heavy && followerWake == WakeCategory.light) {
      return 1.42;
    }
    if (leaderWake == WakeCategory.heavy && followerWake == WakeCategory.medium) {
      return 1.3;
    }
    if (leaderWake == WakeCategory.medium && followerWake == WakeCategory.light) {
      return 1.16;
    }
    if (leaderWake == WakeCategory.heavy && followerWake == WakeCategory.heavy) {
      return 1.16;
    }
    return 1.0;
  }
}
