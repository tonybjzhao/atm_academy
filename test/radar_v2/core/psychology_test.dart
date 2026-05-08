import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/escalation_curve.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/linked_event_chain.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/pressure_pacing_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/scenario_pressure_phase.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot(
  int seconds, {
  CognitiveLoadLevel level = CognitiveLoadLevel.calm,
}) {
  return SimulationSnapshot(
    tick: seconds,
    elapsed: Duration(seconds: seconds),
    aircraft: const [],
    separation: const [],
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: switch (level) {
        CognitiveLoadLevel.calm => 1,
        CognitiveLoadLevel.busy => 4,
        CognitiveLoadLevel.overloaded => 7,
        CognitiveLoadLevel.saturated => 9,
      },
      currentLevel: level,
      activeStressors: const [],
      recentSpikes: const [],
    ),
  );
}

void main() {
  group('EscalationCurve', () {
    test('moves through rhythmic pressure phases', () {
      const curve = EscalationCurve();

      expect(curve.phaseAt(Duration.zero), ScenarioPressurePhase.calm);
      expect(
        curve.phaseAt(const Duration(seconds: 60)),
        ScenarioPressurePhase.building,
      );
      expect(
        curve.phaseAt(const Duration(seconds: 135)),
        ScenarioPressurePhase.unstable,
      );
      expect(
        curve.phaseAt(const Duration(seconds: 190)),
        ScenarioPressurePhase.overload,
      );
      expect(
        curve.phaseAt(const Duration(seconds: 230)),
        ScenarioPressurePhase.recovery,
      );
    });

    test('marks false stability and attention trap windows', () {
      const curve = EscalationCurve();

      expect(curve.deceptiveCalmAt(const Duration(seconds: 70)), isTrue);
      expect(curve.attentionTrapAt(const Duration(seconds: 100)), isTrue);
    });
  });

  group('PressurePacingEngine', () {
    test('false stability reduces event density and delays alerts', () {
      final engine = PressurePacingEngine();

      final state = engine.evaluate(_snapshot(70));

      expect(state.deceptiveCalmActive, isTrue);
      expect(state.eventDensityFactor, lessThan(1));
      expect(state.alertTimingFactor, greaterThan(1));
    });

    test('escalation chain produces active chain and report line', () {
      final engine = PressurePacingEngine();

      final state = engine.evaluate(_snapshot(130));

      expect(state.escalationChainActive, isTrue);
      expect(state.activeChainId, isNotNull);
      expect(state.reportLines.join(' '), contains('weather deviation chain'));
    });

    test('overloaded cognitive state increases pressure multiplier', () {
      final engine = PressurePacingEngine();

      final calm = engine.evaluate(_snapshot(100));
      final overloaded = engine.evaluate(
        _snapshot(100, level: CognitiveLoadLevel.overloaded),
      );

      expect(
          overloaded.pressureMultiplier, greaterThan(calm.pressureMultiplier));
    });
  });

  group('LinkedEventChain', () {
    test('activates believable cascade steps by offset', () {
      final chain = LinkedEventChain.weatherDeviation(
        const Duration(seconds: 100),
      );

      expect(
        chain.activeStepAt(const Duration(seconds: 100))?.label,
        'weather deviation',
      );
      expect(
        chain.activeStepAt(const Duration(seconds: 136))?.label,
        'unstable approach',
      );
      expect(
        chain.activeStepAt(const Duration(seconds: 160))?.label,
        'runway backlog',
      );
    });
  });
}
