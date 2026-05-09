import 'package:atm_flutter/features/radar_v2/models/aircraft_performance_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AircraftPerformanceProfile', () {
    test('parses heavy aliases', () {
      expect(
        AircraftPerformanceProfile.parseType('heavy_jet'),
        AircraftPerformanceType.heavy,
      );
      expect(
        AircraftPerformanceProfile.parseType('widebody'),
        AircraftPerformanceType.heavy,
      );
      expect(
        AircraftPerformanceProfile.parseType('heavy'),
        AircraftPerformanceType.heavy,
      );
    });

    test('heavy profile has stronger inertia envelope than jet', () {
      final heavy =
          AircraftPerformanceProfile.byType(AircraftPerformanceType.heavy);
      final jet = AircraftPerformanceProfile.byType(AircraftPerformanceType.jet);

      expect(heavy.turnRateDegPerSecond, lessThan(jet.turnRateDegPerSecond));
      expect(
        heavy.accelerationKtPerSecond,
        lessThan(jet.accelerationKtPerSecond),
      );
      expect(heavy.approachSpeedKt, greaterThan(jet.approachSpeedKt));
    });
  });
}
