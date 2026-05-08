import 'package:flutter_test/flutter_test.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';

void main() {
  group('CognitiveLoadEngine — level thresholds', () {
    late CognitiveLoadEngine engine;

    setUp(() => engine = CognitiveLoadEngine());

    CognitiveLoadState _calc(CognitiveLoadInputs inputs) =>
        engine.calculate(inputs, const Duration(seconds: 10));

    const _empty = CognitiveLoadInputs(
      unresolvedConflicts: 0,
      simultaneousAlerts: 0,
      activeAircraftCount: 0,
      departureQueueSize: 0,
      occupiedRunwayCount: 0,
      weatherSeverityTotal: 0,
      goAroundCount: 0,
      recentCommandCount: 0,
      alertEscalationCount: 0,
    );

    test('zero inputs → calm level', () {
      final state = _calc(_empty);
      expect(state.currentLevel, CognitiveLoadLevel.calm);
    });

    test('single unresolved conflict raises score', () {
      final state = _calc(
        const CognitiveLoadInputs(
          unresolvedConflicts: 1,
          simultaneousAlerts: 0,
          activeAircraftCount: 0,
          departureQueueSize: 0,
          occupiedRunwayCount: 0,
          weatherSeverityTotal: 0,
          goAroundCount: 0,
          recentCommandCount: 0,
          alertEscalationCount: 0,
        ),
      );
      // weight 1.8 → score ≥ 1.8
      expect(state.totalLoadScore, greaterThanOrEqualTo(1.8));
    });

    test('heavy load → overloaded or saturated', () {
      final state = _calc(
        const CognitiveLoadInputs(
          unresolvedConflicts: 4,
          simultaneousAlerts: 8,
          activeAircraftCount: 12,
          departureQueueSize: 6,
          occupiedRunwayCount: 4,
          weatherSeverityTotal: 10,
          goAroundCount: 3,
          recentCommandCount: 10,
          alertEscalationCount: 4,
        ),
      );
      expect(state.isOverloaded, isTrue);
    });

    test('score is clamped to 10.0', () {
      final state = _calc(
        const CognitiveLoadInputs(
          unresolvedConflicts: 99,
          simultaneousAlerts: 99,
          activeAircraftCount: 99,
          departureQueueSize: 99,
          occupiedRunwayCount: 99,
          weatherSeverityTotal: 99,
          goAroundCount: 99,
          recentCommandCount: 99,
          alertEscalationCount: 99,
        ),
      );
      expect(state.totalLoadScore, lessThanOrEqualTo(10.0));
    });

    test('stressor list is non-empty when load contributors are active', () {
      final state = _calc(
        const CognitiveLoadInputs(
          unresolvedConflicts: 2,
          simultaneousAlerts: 0,
          activeAircraftCount: 0,
          departureQueueSize: 0,
          occupiedRunwayCount: 0,
          weatherSeverityTotal: 0,
          goAroundCount: 0,
          recentCommandCount: 0,
          alertEscalationCount: 0,
        ),
      );
      expect(state.activeStressors, isNotEmpty);
    });

    test('reset clears spike history', () {
      // Build up some state, then reset
      for (var i = 0; i < 5; i++) {
        engine.calculate(
          const CognitiveLoadInputs(
            unresolvedConflicts: 3,
            simultaneousAlerts: 5,
            activeAircraftCount: 10,
            departureQueueSize: 0,
            occupiedRunwayCount: 0,
            weatherSeverityTotal: 0,
            goAroundCount: 0,
            recentCommandCount: 0,
            alertEscalationCount: 0,
          ),
          Duration(seconds: i * 10),
        );
      }
      engine.reset();
      final state = engine.calculate(_empty, Duration.zero);
      expect(state.recentSpikes, isEmpty);
    });
  });

  group('CognitiveLoadLevel.fromScore', () {
    test('0.0 → calm', () {
      expect(CognitiveLoadLevel.fromScore(0.0), CognitiveLoadLevel.calm);
    });
    test('2.4 → calm', () {
      expect(CognitiveLoadLevel.fromScore(2.4), CognitiveLoadLevel.calm);
    });
    test('2.5 → busy', () {
      expect(CognitiveLoadLevel.fromScore(2.5), CognitiveLoadLevel.busy);
    });
    test('5.5 → overloaded', () {
      expect(CognitiveLoadLevel.fromScore(5.5), CognitiveLoadLevel.overloaded);
    });
    test('8.0 → saturated', () {
      expect(CognitiveLoadLevel.fromScore(8.0), CognitiveLoadLevel.saturated);
    });
    test('10.0 → saturated', () {
      expect(CognitiveLoadLevel.fromScore(10.0), CognitiveLoadLevel.saturated);
    });
  });

  group('CognitiveLoadState', () {
    test('idle state is calm with score 0', () {
      expect(CognitiveLoadState.idle.currentLevel, CognitiveLoadLevel.calm);
      expect(CognitiveLoadState.idle.totalLoadScore, 0.0);
    });

    test('isOverloaded true for overloaded level', () {
      const state = CognitiveLoadState(
        totalLoadScore: 6.0,
        currentLevel: CognitiveLoadLevel.overloaded,
        activeStressors: [],
        recentSpikes: [],
      );
      expect(state.isOverloaded, isTrue);
    });

    test('isOverloaded true for saturated level', () {
      const state = CognitiveLoadState(
        totalLoadScore: 9.0,
        currentLevel: CognitiveLoadLevel.saturated,
        activeStressors: [],
        recentSpikes: [],
      );
      expect(state.isOverloaded, isTrue);
    });

    test('isOverloaded false for calm', () {
      expect(CognitiveLoadState.idle.isOverloaded, isFalse);
    });
  });
}
