import 'package:atm_flutter/features/radar_v2/engine/pilot_behavior_realism_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PilotBehaviorRealismProfile scenario calibration', () {
    test('weather-heavy scenario amplifies weather impact over baseline', () {
      final base = PilotBehaviorRealismProfile.fromScenarioContext(
        difficulty: 3,
        weatherMode: 'normal',
        weatherZoneCount: 0,
        maxWeatherSeverity: 0,
        densityScale: 1.0,
        workloadPressureMultiplier: 1.0,
        maxControllerLoad: 6,
      );
      final weatherHeavy = PilotBehaviorRealismProfile.fromScenarioContext(
        difficulty: 3,
        weatherMode: 'low_visibility',
        weatherZoneCount: 3,
        maxWeatherSeverity: 3,
        densityScale: 1.0,
        workloadPressureMultiplier: 1.0,
        maxControllerLoad: 6,
      );

      expect(weatherHeavy.weatherImpactScale, greaterThan(base.weatherImpactScale));
      expect(weatherHeavy.executionDelayScale, greaterThan(base.executionDelayScale));
    });

    test('dense-traffic scenario amplifies workload impact over baseline', () {
      final base = PilotBehaviorRealismProfile.fromScenarioContext(
        difficulty: 4,
        weatherMode: 'normal',
        weatherZoneCount: 0,
        maxWeatherSeverity: 0,
        densityScale: 1.0,
        workloadPressureMultiplier: 1.0,
        maxControllerLoad: 6,
      );
      final dense = PilotBehaviorRealismProfile.fromScenarioContext(
        difficulty: 4,
        weatherMode: 'normal',
        weatherZoneCount: 0,
        maxWeatherSeverity: 0,
        densityScale: 1.4,
        workloadPressureMultiplier: 1.2,
        maxControllerLoad: 8,
      );

      expect(dense.workloadImpactScale, greaterThan(base.workloadImpactScale));
      expect(dense.variabilityChanceScale, greaterThan(base.variabilityChanceScale));
    });

    test('light traffic suppresses variability for training-safe behavior', () {
      final normal = PilotBehaviorRealismProfile.fromScenarioContext(
        difficulty: 2,
        weatherMode: 'normal',
        weatherZoneCount: 0,
        maxWeatherSeverity: 0,
        densityScale: 1.0,
        workloadPressureMultiplier: 1.0,
        maxControllerLoad: 6,
      );
      final lightTraffic = PilotBehaviorRealismProfile.fromScenarioContext(
        difficulty: 2,
        weatherMode: 'normal',
        weatherZoneCount: 0,
        maxWeatherSeverity: 0,
        densityScale: 0.8,
        workloadPressureMultiplier: 0.9,
        maxControllerLoad: 4,
      );

      expect(
        lightTraffic.variabilityChanceScale,
        lessThan(normal.variabilityChanceScale),
      );
      expect(
        lightTraffic.executionDelayScale,
        lessThan(normal.executionDelayScale),
      );
    });
  });
}
