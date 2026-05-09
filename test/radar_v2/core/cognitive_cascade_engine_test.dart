import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/cognitive_cascade_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_expectation_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/predictive_mental_model_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/working_memory_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot({
  required Duration elapsed,
  required double load,
  required Set<String> activeDistractions,
  required AttentionFocusState attention,
}) {
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: const [],
    separation: const [],
    activeDistractions: activeDistractions,
    attentionFocus: attention,
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: load,
      currentLevel: load >= 8
          ? CognitiveLoadLevel.saturated
          : load >= 6
              ? CognitiveLoadLevel.overloaded
              : load >= 3
                  ? CognitiveLoadLevel.busy
                  : CognitiveLoadLevel.calm,
      activeStressors: const [],
      recentSpikes: const [],
    ),
  );
}

void main() {
  group('CognitiveCascadeEngine', () {
    test('high amplification factors can start a cascade chain from surprise', () {
      final engine = CognitiveCascadeEngine();
      final predictive = PredictiveMentalModelState(
        aggregatePredictionConfidence: 0.9,
        newlyDetectedMismatches: const [
          PredictionMismatchSnapshot(
            id: 'm1',
            aircraftId: 'a1',
            type: PredictionMismatchType.delayedTurn,
            firstDetectedAt: Duration(seconds: 10),
            lastSeenAt: Duration(seconds: 10),
            severity: 0.95,
            confidenceAtDetection: 0.9,
          ),
        ],
      );

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 10),
          load: 9.0,
          activeDistractions: const {'d1', 'd2', 'd3'},
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.25,
            overloadDuration: Duration(seconds: 80),
            activeInterrupts: ['radio chatter', 'weather update'],
          ),
        ),
        predictive: predictive,
        attention: const AttentionFocusState(
          scanCoverageQuality: 0.25,
          overloadDuration: Duration(seconds: 80),
          activeInterrupts: ['radio chatter', 'weather update'],
        ),
        workingMemory: const WorkingMemoryState(unrecoveredTaskCount: 2),
        expectation: ControllerExpectationState.idle,
      );

      expect(state.chainStartedThisTick, isTrue);
      expect(state.activeChainId, isNotNull);
      expect(state.scanQualityPenalty, greaterThan(0));
    });

    test('active cascade can produce secondary failures and recovery state', () {
      CognitiveCascadeEngine? seededEngine;
      for (var i = 0; i < 80; i++) {
        final candidate = CognitiveCascadeEngine();
        final seededPredictive = PredictiveMentalModelState(
          aggregatePredictionConfidence: 0.88,
          newlyDetectedMismatches: [
            PredictionMismatchSnapshot(
              id: 'm2_$i',
              aircraftId: 'a2',
              type: PredictionMismatchType.unexpectedSpeed,
              firstDetectedAt: const Duration(seconds: 5),
              lastSeenAt: const Duration(seconds: 5),
              severity: 0.9,
              confidenceAtDetection: 0.84,
            ),
          ],
        );

        final start = candidate.evaluate(
          snapshot: _snapshot(
            elapsed: const Duration(seconds: 5),
            load: 8.5,
            activeDistractions: const {'d1', 'd2'},
            attention: const AttentionFocusState(
              scanCoverageQuality: 0.32,
              overloadDuration: Duration(seconds: 55),
              activeInterrupts: ['emergency distraction'],
            ),
          ),
          predictive: seededPredictive,
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.32,
            overloadDuration: Duration(seconds: 55),
            activeInterrupts: ['emergency distraction'],
          ),
          workingMemory: const WorkingMemoryState(unrecoveredTaskCount: 1),
          expectation: ControllerExpectationState.idle,
        );
        if (start.chainStartedThisTick) {
          seededEngine = candidate;
          break;
        }
      }

      expect(seededEngine, isNotNull);

      final state = seededEngine!.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 25),
          load: 3.0,
          activeDistractions: const {'d1'},
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.52,
            activeInterrupts: ['runway change'],
          ),
        ),
        predictive: const PredictiveMentalModelState(
          aggregatePredictionConfidence: 0.78,
          surpriseLoad: 0.4,
        ),
        attention: const AttentionFocusState(
          scanCoverageQuality: 0.52,
          activeInterrupts: ['runway change'],
        ),
        workingMemory: const WorkingMemoryState(unrecoveredTaskCount: 1),
        expectation: ControllerExpectationState.idle,
      );

      expect(state.activeChainId, isNotNull);
      expect(
        state.scanQualityPenalty > 0 || state.secondaryFailuresThisTick.isNotEmpty,
        isTrue,
      );
    });
  });
}
