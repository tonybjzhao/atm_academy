import 'package:atm_flutter/features/radar_v2/engine/separation_calculator.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_performance_profile.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeparationCalculator wake ecology', () {
    test('expands spacing minima behind heavy leaders', () {
      const leadHeavy = AircraftState(
        id: 'lead',
        callsign: 'QFA214',
        xNm: 0,
        yNm: 0,
        altitudeFt: 7000,
        headingDeg: 90,
        groundSpeedKt: 210,
        performanceType: AircraftPerformanceType.heavy,
      );
      const trailLight = AircraftState(
        id: 'trail',
        callsign: 'REX438',
        xNm: 6.3,
        yNm: 0,
        altitudeFt: 7000,
        headingDeg: 90,
        groundSpeedKt: 180,
        performanceType: AircraftPerformanceType.turboprop,
      );
      const leadMedium = AircraftState(
        id: 'lead',
        callsign: 'QFA214',
        xNm: 0,
        yNm: 0,
        altitudeFt: 7000,
        headingDeg: 90,
        groundSpeedKt: 210,
        performanceType: AircraftPerformanceType.jet,
      );

      const calculator = SeparationCalculator();
      final heavyResult = calculator.calculate(leadHeavy, trailLight);
      final mediumResult = calculator.calculate(leadMedium, trailLight);

      expect(heavyResult.isLossOfSeparation, isTrue);
      expect(mediumResult.isLossOfSeparation, isFalse);
    });
  });
}
