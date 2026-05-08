enum AircraftPerformanceType {
  jet,
  regional,
  turboprop,
}

class AircraftPerformanceProfile {
  final AircraftPerformanceType type;
  final double turnRateDegPerSecond;
  final double accelerationKtPerSecond;
  final int climbRateFpm;
  final int descentRateFpm;
  final double approachSpeedKt;

  const AircraftPerformanceProfile({
    required this.type,
    required this.turnRateDegPerSecond,
    required this.accelerationKtPerSecond,
    required this.climbRateFpm,
    required this.descentRateFpm,
    required this.approachSpeedKt,
  });

  static const AircraftPerformanceProfile jet = AircraftPerformanceProfile(
    type: AircraftPerformanceType.jet,
    turnRateDegPerSecond: 3,
    accelerationKtPerSecond: 3,
    climbRateFpm: 1800,
    descentRateFpm: 2200,
    approachSpeedKt: 145,
  );

  static const AircraftPerformanceProfile regional = AircraftPerformanceProfile(
    type: AircraftPerformanceType.regional,
    turnRateDegPerSecond: 3.4,
    accelerationKtPerSecond: 2.4,
    climbRateFpm: 1600,
    descentRateFpm: 1900,
    approachSpeedKt: 135,
  );

  static const AircraftPerformanceProfile turboprop =
      AircraftPerformanceProfile(
    type: AircraftPerformanceType.turboprop,
    turnRateDegPerSecond: 3.8,
    accelerationKtPerSecond: 1.8,
    climbRateFpm: 1300,
    descentRateFpm: 1500,
    approachSpeedKt: 120,
  );

  static AircraftPerformanceProfile byType(AircraftPerformanceType type) {
    switch (type) {
      case AircraftPerformanceType.jet:
        return jet;
      case AircraftPerformanceType.regional:
        return regional;
      case AircraftPerformanceType.turboprop:
        return turboprop;
    }
  }

  static AircraftPerformanceType parseType(Object? value) {
    final text = value?.toString().toLowerCase();
    switch (text) {
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
}
