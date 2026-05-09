import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_expectation_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/predictive_mental_model_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/predictive_mental_model_state.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_intent.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot({
  required Duration elapsed,
  required List<AircraftState> aircraft,
  AttentionFocusState attention = AttentionFocusState.idle,
  CognitiveLoadLevel level = CognitiveLoadLevel.calm,
}) {
  final loadScore = switch (level) {
    CognitiveLoadLevel.calm => 1.2,
    CognitiveLoadLevel.busy => 4.5,
    CognitiveLoadLevel.overloaded => 7.4,
    CognitiveLoadLevel.saturated => 9.0,
  };
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: aircraft,
    separation: const [],
    attentionFocus: attention,
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: loadScore,
      currentLevel: level,
      activeStressors: const [],
      recentSpikes: const [],
    ),
  );
}

AircraftState _aircraft({
  required String id,
  required double heading,
  required int altitude,
  required double speed,
  double? assignedHeading,
  int? assignedAltitude,
  double? assignedSpeed,
}) {
  return AircraftState(
    id: id,
    callsign: id,
    xNm: 0,
    yNm: 0,
    altitudeFt: altitude,
    headingDeg: heading,
    groundSpeedKt: speed,
    verticalSpeedFpm: 0,
    intent: AircraftIntent(
      assignedHeadingDeg: assignedHeading,
      assignedAltitudeFt: assignedAltitude,
      assignedSpeedKt: assignedSpeed,
    ),
  );
}

void main() {
  group('PredictiveMentalModelEngine', () {
    test('detects deterministic delayed-turn mismatch from heading non-response', () {
      final engine = PredictiveMentalModelEngine();
      const expectation = ControllerExpectationState.idle;

      engine.evaluate(
        snapshot: _snapshot(
          elapsed: Duration.zero,
          aircraft: [
            _aircraft(
              id: 'a1',
              heading: 90,
              altitude: 12000,
              speed: 250,
              assignedHeading: 180,
            ),
          ],
        ),
        expectationState: expectation,
        attentionFocus: const AttentionFocusState(),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 2,
          currentLevel: CognitiveLoadLevel.calm,
          activeStressors: [],
          recentSpikes: [],
        ),
      );

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 6),
          aircraft: [
            _aircraft(
              id: 'a1',
              heading: 90,
              altitude: 12000,
              speed: 250,
              assignedHeading: 180,
            ),
          ],
        ),
        expectationState: expectation,
        attentionFocus: const AttentionFocusState(),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 2,
          currentLevel: CognitiveLoadLevel.calm,
          activeStressors: [],
          recentSpikes: [],
        ),
      );

      expect(state.activeMismatches, isNotEmpty);
      expect(
        state.activeMismatches.any((m) => m.type == PredictionMismatchType.delayedTurn),
        isTrue,
      );
    });

    test('poor scan conditions produce late-recognition flag on mismatch', () {
      final engine = PredictiveMentalModelEngine();
      const expectation = ControllerExpectationState.idle;

      engine.evaluate(
        snapshot: _snapshot(
          elapsed: Duration.zero,
          aircraft: [
            _aircraft(
              id: 'a2',
              heading: 210,
              altitude: 15000,
              speed: 280,
              assignedHeading: 120,
            ),
          ],
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.4,
            scanBlindDuration: Duration(seconds: 9),
          ),
          level: CognitiveLoadLevel.overloaded,
        ),
        expectationState: expectation,
        attentionFocus: const AttentionFocusState(
          scanCoverageQuality: 0.4,
          scanBlindDuration: Duration(seconds: 9),
        ),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 8,
          currentLevel: CognitiveLoadLevel.overloaded,
          activeStressors: [],
          recentSpikes: [],
        ),
      );

      final state = engine.evaluate(
        snapshot: _snapshot(
          elapsed: const Duration(seconds: 12),
          aircraft: [
            _aircraft(
              id: 'a2',
              heading: 210,
              altitude: 15000,
              speed: 280,
              assignedHeading: 120,
            ),
          ],
          attention: const AttentionFocusState(
            scanCoverageQuality: 0.4,
            scanBlindDuration: Duration(seconds: 12),
          ),
          level: CognitiveLoadLevel.overloaded,
        ),
        expectationState: expectation,
        attentionFocus: const AttentionFocusState(
          scanCoverageQuality: 0.4,
          scanBlindDuration: Duration(seconds: 12),
        ),
        cognitiveLoad: const CognitiveLoadState(
          totalLoadScore: 8,
          currentLevel: CognitiveLoadLevel.overloaded,
          activeStressors: [],
          recentSpikes: [],
        ),
      );

      expect(state.lateRecognitionCount, greaterThanOrEqualTo(1));
      expect(state.surpriseLoad, greaterThan(0));
    });
  });
}
