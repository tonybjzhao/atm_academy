import 'package:atm_flutter/features/radar_v2/core/alerts/alert_priority.dart';
import 'package:atm_flutter/features/radar_v2/core/alerts/operational_alert.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/expectation_tracker.dart';
import 'package:atm_flutter/features/radar_v2/core/psychology/scenario_pressure_phase.dart';
import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/models/runway_state.dart';
import 'package:atm_flutter/features/radar_v2/models/separation_result.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/models/weather_zone.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot(
  int seconds, {
  CognitiveLoadLevel level = CognitiveLoadLevel.calm,
  int activeAircraft = 2,
  int predictedConflicts = 0,
  int weatherSeverity = 0,
  int highAlerts = 0,
  bool runwayOccupied = false,
  ScenarioPsychologyState psychology = ScenarioPsychologyState.idle,
  AttentionFocusState attention = AttentionFocusState.idle,
}) {
  return SimulationSnapshot(
    tick: seconds,
    elapsed: Duration(seconds: seconds),
    aircraft: List.generate(
      activeAircraft,
      (index) => AircraftState(
        id: 'A$index',
        callsign: 'QFA$index',
        xNm: index.toDouble(),
        yNm: index.toDouble(),
        altitudeFt: 5000,
        headingDeg: 90,
        groundSpeedKt: 240,
      ),
    ),
    separation: List.generate(
      predictedConflicts,
      (index) => SeparationResult(
        aircraftAId: 'A$index',
        aircraftBId: 'B$index',
        lateralNm: 4,
        verticalFt: 1000,
        isLossOfSeparation: false,
        isPredictedConflict: true,
        timeToConflict: const Duration(seconds: 80),
      ),
    ),
    runwayStates: [
      if (runwayOccupied)
        RunwayState(
          runwayId: '16',
          occupiedUntil: Duration(seconds: seconds + 30),
        ),
    ],
    weatherZones: [
      if (weatherSeverity > 0)
        WeatherZone(
          id: 'WX',
          xNm: 10,
          yNm: 10,
          radiusNm: 8,
          severity: weatherSeverity,
        ),
    ],
    maxControllerLoad: 6,
    sectorPressureIndex: level.index * 1.4,
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
    operationalAlerts: List.generate(
      highAlerts,
      (index) => OperationalAlert(
        id: 'alert$index',
        type: OperationalAlertType.predictedConflict,
        priority: AlertPriority.high,
        createdAt: Duration(seconds: seconds),
        workloadImpact: 7,
      ),
    ),
    attentionFocus: attention,
    psychologyState: psychology,
  );
}

void main() {
  group('ExpectationTracker', () {
    test('starts aligned with current sector reality', () {
      final tracker = ExpectationTracker();

      final state = tracker.evaluate(_snapshot(0));

      expect(state.driftScore, 0);
      expect(state.driftLabel, 'aligned');
    });

    test('detects assumption drift when instability quietly rises', () {
      final tracker = ExpectationTracker();
      tracker.evaluate(_snapshot(0));

      final state = tracker.evaluate(
        _snapshot(
          184,
          level: CognitiveLoadLevel.overloaded,
          activeAircraft: 6,
          predictedConflicts: 2,
          weatherSeverity: 3,
          highAlerts: 2,
          psychology: const ScenarioPsychologyState(
            phase: ScenarioPressurePhase.unstable,
            pressureMultiplier: 1.5,
            eventDensityFactor: 1.1,
            alertTimingFactor: 0.75,
            spacingInstabilityProbability: 0.42,
            escalationChainActive: true,
          ),
        ),
      );

      expect(state.driftScore, greaterThan(0.25));
      expect(state.reportLines.join(' '), contains('diverged'));
    });

    test('confirmation bias lowers threat sensitivity under overload', () {
      final tracker = ExpectationTracker();
      tracker.evaluate(_snapshot(0));

      final state = tracker.evaluate(
        _snapshot(
          80,
          level: CognitiveLoadLevel.saturated,
          predictedConflicts: 1,
          highAlerts: 1,
        ),
      );

      expect(state.confirmationBiasActive, isTrue);
      expect(state.threatSensitivity, lessThan(0.9));
    });

    test('false recovery is detected when calm presentation hides instability',
        () {
      final tracker = ExpectationTracker();
      tracker.evaluate(_snapshot(0));

      final state = tracker.evaluate(
        _snapshot(
          220,
          level: CognitiveLoadLevel.calm,
          activeAircraft: 5,
          weatherSeverity: 4,
          psychology: const ScenarioPsychologyState(
            phase: ScenarioPressurePhase.recovery,
            pressureMultiplier: 0.8,
            eventDensityFactor: 0.7,
            alertTimingFactor: 1.1,
            spacingInstabilityProbability: 0.36,
            escalationChainActive: true,
          ),
        ),
      );

      expect(state.falseRecoveryActive, isTrue);
      expect(state.reportLines.join(' '), contains('False recovery'));
    });

    test('attention anchoring is reported during biased drift', () {
      final tracker = ExpectationTracker();
      tracker.evaluate(
        _snapshot(
          0,
          attention: const AttentionFocusState(
            currentFocusTarget: 'aircraft:A1',
          ),
        ),
      );
      tracker.evaluate(
        _snapshot(
          1,
          attention: const AttentionFocusState(
            currentFocusTarget: 'aircraft:A1',
          ),
        ),
      );

      final state = tracker.evaluate(
        _snapshot(
          30,
          level: CognitiveLoadLevel.overloaded,
          predictedConflicts: 2,
          highAlerts: 2,
          attention: const AttentionFocusState(
            currentFocusTarget: 'aircraft:A1',
          ),
        ),
      );

      expect(state.attentionAnchored, isTrue);
      expect(state.reportLines.join(' '), contains('anchored'));
    });
  });
}
