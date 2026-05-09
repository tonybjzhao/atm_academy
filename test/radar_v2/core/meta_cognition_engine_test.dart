import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/cognitive_cascade_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/meta_cognition_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/predictive_mental_model_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/working_memory_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot({
  required Duration elapsed,
  required double load,
  AttentionFocusState attention = AttentionFocusState.idle,
}) {
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: const [],
    separation: const [],
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
  group('MetaCognitionEngine', () {
    test('produces non-binary calibration and estimated self-monitoring values', () {
      final engine = MetaCognitionEngine(experienceLevel: 0.68);
      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 240),
          load: 5.7,
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.6,
            overloadDuration: Duration(seconds: 40),
          ),
        ),
        attention: const AttentionFocusState(
          scanCoverageQuality: 0.6,
          overloadDuration: Duration(seconds: 40),
        ),
        workingMemory: const WorkingMemoryState(
          pendingIntentions: [],
        ),
        predictive: const PredictiveMentalModelState(
          aggregatePredictionConfidence: 0.71,
          surpriseLoad: 0.42,
        ),
        cascade: const CognitiveCascadeState(),
      );

      expect(state.latestAssessment.calibrationAccuracy, greaterThan(0));
      expect(state.latestAssessment.calibrationAccuracy, lessThan(1));
      expect(state.latestAssessment.estimatedWorkload, inInclusiveRange(0, 1));
      expect(state.latestAssessment.estimatedScanQuality, inInclusiveRange(0, 1));
    });

    test('high overload and low scan quality can cause degradation blindness', () {
      final engine = MetaCognitionEngine(experienceLevel: 0.25);
      var blinded = false;

      for (var i = 0; i < 120; i++) {
        final state = engine.evaluate(
          snapshot: _snapshot(
            elapsed: Duration(seconds: 600 + i),
            load: 9.0,
            attention: const AttentionFocusState(
              scanCoverageQuality: 0.28,
              overloadDuration: Duration(seconds: 130),
            ),
          ),
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.28,
            overloadDuration: Duration(seconds: 130),
          ),
          workingMemory: const WorkingMemoryState(
            pendingIntentions: [],
            unrecoveredTaskCount: 3,
          ),
          predictive: const PredictiveMentalModelState(
            aggregatePredictionConfidence: 0.82,
            surpriseLoad: 0.78,
          ),
          cascade: const CognitiveCascadeState(),
        );
        if (state.latestAssessment.degradationBlindness) {
          blinded = true;
          break;
        }
      }

      expect(blinded, isTrue);
    });

    test('when not blind and under pressure, recovery actions are generated', () {
      final engine = MetaCognitionEngine(experienceLevel: 0.8);
      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 420),
          load: 7.4,
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.46,
            overloadDuration: Duration(seconds: 65),
            riskLevel: AttentionRiskLevel.fixationRisk,
          ),
        ),
        attention: const AttentionFocusState(
          scanCoverageQuality: 0.46,
          overloadDuration: Duration(seconds: 65),
          riskLevel: AttentionRiskLevel.fixationRisk,
        ),
        workingMemory: const WorkingMemoryState(
          pendingIntentions: [],
          unrecoveredTaskCount: 2,
        ),
        predictive: const PredictiveMentalModelState(
          aggregatePredictionConfidence: 0.69,
          surpriseLoad: 0.64,
        ),
        cascade: const CognitiveCascadeState(
          intentionInterruptionActive: true,
        ),
      );

      expect(state.recentRecoveryActions, isNotEmpty);
      expect(
        state.recentRecoveryActions.map((a) => a.action).join(' '),
        contains('scan'),
      );
    });
  });
}
