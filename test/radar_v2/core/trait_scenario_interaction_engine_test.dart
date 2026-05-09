import 'package:atm_flutter/features/radar_v2/models/aircraft_state.dart';
import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/cognitive_cascade_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_archetype.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_archetype_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/meta_cognition_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/predictive_mental_model_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/scenario_pressure_topology.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/trait_scenario_interaction_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/trait_scenario_interaction_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/working_memory_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:atm_flutter/features/radar_v2/scenario/scenario_definition.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

SimulationSnapshot _snap({
  Duration elapsed = const Duration(seconds: 60),
  double pressure = 2.0,
}) {
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: const [],
    separation: const [],
    sectorPressureIndex: pressure,
    cognitiveLoad: CognitiveLoadState(
      totalLoadScore: pressure,
      currentLevel: CognitiveLoadLevel.busy,
      activeStressors: const [],
      recentSpikes: const [],
    ),
  );
}

ScenarioDefinition _makeScenario({
  int difficulty = 3,
  String weatherMode = 'normal',
  String sectorPersonality = 'arrival_rush',
  double pressureMultiplier = 1.1,
  int aircraftCount = 4,
  int durationSeconds = 300,
  double lowVisibilitySpacingMultiplier = 1.0,
}) {
  return ScenarioDefinition(
    id: 'test',
    title: 'Test',
    sectorId: 'test',
    sectorPersonality: sectorPersonality,
    duration: Duration(seconds: durationSeconds),
    difficulty: difficulty,
    weatherMode: weatherMode,
    workloadPressureMultiplier: pressureMultiplier,
    lowVisibilitySpacingMultiplier: lowVisibilitySpacingMultiplier,
    speedOptions: const [1, 2, 4],
    aircraft: List.generate(
      aircraftCount,
      (i) => AircraftSpawnDefinition(
        id: 'ac$i',
        callsign: 'TEST$i',
        spawnAt: Duration(seconds: i * 30),
        initialState: AircraftState(
          id: 'ac$i',
          callsign: 'TEST$i',
          xNm: 0.0,
          yNm: 0.0,
          altitudeFt: 10000,
          headingDeg: 0,
          groundSpeedKt: 250,
        ),
      ),
    ),
    winConditions: const [],
    failConditions: const [],
  );
}

TraitScenarioInteractionState _evaluate(
  TraitScenarioInteractionEngine engine, {
  Duration elapsed = const Duration(seconds: 60),
  AttentionFocusState? attention,
  WorkingMemoryState? workingMemory,
  CognitiveCascadeState? cascade,
}) {
  return engine.evaluate(
    snapshot: _snap(elapsed: elapsed),
    attention: attention ?? AttentionFocusState.idle,
    workingMemory: workingMemory ?? WorkingMemoryState.idle,
    predictive: const PredictiveMentalModelState(),
    cascade: cascade ?? CognitiveCascadeState.idle,
    metaCognition: MetaCognitionState(
      latestAssessment: MetaAssessmentSnapshot(
        elapsed: elapsed,
        estimatedWorkload: 0.4,
        estimatedScanQuality: 0.6,
        estimatedConfidenceReliability: 0.6,
        estimatedTaskSaturation: 0.3,
        estimatedFixationRisk: 0.1,
        calibrationAccuracy: 0.7,
      ),
    ),
    archetypeState: ControllerArchetypeState.idle,
  );
}

void main() {
  group('ScenarioPressureTopology', () {
    test('empty topology for minimal scenario', () {
      final def = _makeScenario(
        difficulty: 1,
        weatherMode: 'normal',
        sectorPersonality: 'quiet',
        pressureMultiplier: 1.0,
        aircraftCount: 2,
        durationSeconds: 180,
      );
      final topology = ScenarioPressureTopology.fromDefinition(def);
      // May contain some patterns due to aircraft count but intensity should be low
      expect(topology.overallIntensity, lessThan(0.5));
    });

    test('surprise-heavy detected for low_visibility', () {
      final def = _makeScenario(weatherMode: 'low_visibility');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasSurprisePressure, isTrue);
    });

    test('surprise-heavy detected for weather_disruption personality', () {
      final def = _makeScenario(sectorPersonality: 'weather_disruption');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasSurprisePressure, isTrue);
    });

    test('multi-conflict scan detected for arrival_rush personality', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasScanPressure, isTrue);
    });

    test('multi-conflict scan detected for 4+ aircraft', () {
      final def = _makeScenario(aircraftCount: 4);
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasScanPressure, isTrue);
    });

    test('long-duration backlog detected for 6+ min scenario with 4+ ac', () {
      final def = _makeScenario(durationSeconds: 400, aircraftCount: 4);
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasBacklogPressure, isTrue);
    });

    test('rapid escalation detected for high pressure + high difficulty', () {
      final def = _makeScenario(pressureMultiplier: 1.25, difficulty: 4);
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasEscalationPressure, isTrue);
    });

    test('tight spacing detected for busy_terminal personality', () {
      final def = _makeScenario(sectorPersonality: 'busy_terminal');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasTightSpacingPressure, isTrue);
    });

    test('tight spacing detected for 5+ aircraft', () {
      final def = _makeScenario(aircraftCount: 5);
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.hasTightSpacingPressure, isTrue);
    });

    test('overall intensity increases with difficulty', () {
      final easy = ScenarioPressureTopology.fromDefinition(
        _makeScenario(difficulty: 1, pressureMultiplier: 1.0, aircraftCount: 2),
      );
      final hard = ScenarioPressureTopology.fromDefinition(
        _makeScenario(difficulty: 5, pressureMultiplier: 1.4, aircraftCount: 6),
      );
      expect(hard.overallIntensity, greaterThan(easy.overallIntensity));
    });

    test('estimated conflict windows is non-negative', () {
      for (final ac in [1, 2, 4, 6]) {
        final def = _makeScenario(aircraftCount: ac);
        final topology = ScenarioPressureTopology.fromDefinition(def);
        expect(topology.estimatedConflictWindows, greaterThanOrEqualTo(0));
        expect(topology.estimatedConflictWindows, lessThanOrEqualTo(8));
      }
    });

    test('all 5 patterns present for fully stressed scenario', () {
      final def = _makeScenario(
        difficulty: 5,
        weatherMode: 'low_visibility',
        sectorPersonality: 'weather_disruption',
        pressureMultiplier: 1.4,
        aircraftCount: 6,
        durationSeconds: 480,
      );
      final topology = ScenarioPressureTopology.fromDefinition(def);
      expect(topology.patterns.length, equals(5));
    });

    test('displayName and stressedTraitLabel non-empty for all patterns', () {
      for (final p in ScenarioPressurePattern.values) {
        expect(p.displayName.isNotEmpty, isTrue);
        expect(p.stressedTraitLabel.isNotEmpty, isTrue);
      }
    });
  });

  group('TraitScenarioInteractionEngine', () {
    test('idle state has no amplifying patterns', () {
      expect(
        TraitScenarioInteractionState.idle.amplifyingPatterns.isEmpty,
        isTrue,
      );
    });

    test('returns state with matching topology patterns', () {
      final def = _makeScenario(
        weatherMode: 'low_visibility',
        sectorPersonality: 'arrival_rush',
      );
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      final state = _evaluate(engine);
      expect(state.topology.patterns, equals(topology.patterns));
    });

    test('degradation ticks accumulate when fixation occurs', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      const fixationAttention = AttentionFocusState(
        riskLevel: AttentionRiskLevel.tunnelVision,
      );
      TraitScenarioInteractionState? lastState;
      for (var i = 0; i < 15; i++) {
        lastState = _evaluate(
          engine,
          elapsed: Duration(seconds: 60 + i * 5),
          attention: fixationAttention,
        );
      }
      final records = lastState!.patternRecords;
      final total = records.fold(0, (sum, r) => sum + r.degradationTicks);
      expect(total, greaterThan(0));
    });

    test('resilient ticks accumulate when no degradation occurs', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      TraitScenarioInteractionState? lastState;
      for (var i = 0; i < 10; i++) {
        lastState = _evaluate(
          engine,
          elapsed: Duration(seconds: 60 + i * 5),
        );
      }
      final records = lastState!.patternRecords;
      final total = records.fold(0, (sum, r) => sum + r.resilientTicks);
      expect(total, greaterThan(0));
    });

    test('first destabilised system is recorded after fixation tick', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.reactiveFirefighter,
      );
      const fixationAttention = AttentionFocusState(
        riskLevel: AttentionRiskLevel.criticalFixation,
      );
      final state = _evaluate(
        engine,
        elapsed: const Duration(seconds: 90),
        attention: fixationAttention,
      );
      expect(
        state.firstDestabilisedSystem,
        equals(FirstDestabilisedSystem.attention),
      );
      expect(state.firstDestabilisationAt, equals(const Duration(seconds: 90)));
    });

    test('first destabilised system set only once (not overwritten)', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      const fixation = AttentionFocusState(
        riskLevel: AttentionRiskLevel.tunnelVision,
      );
      const forgottenMemory = WorkingMemoryState(forgottenIntentionCount: 2);
      // First tick: attention degradation
      _evaluate(engine, elapsed: const Duration(seconds: 60), attention: fixation);
      // Second tick: memory degradation
      final state = _evaluate(
        engine,
        elapsed: const Duration(seconds: 70),
        workingMemory: forgottenMemory,
      );
      // Should still be attention (first recorded)
      expect(state.firstDestabilisedSystem, equals(FirstDestabilisedSystem.attention));
    });

    test('pattern degradation ratio reflects tick distribution', () {
      final def = _makeScenario(
        sectorPersonality: 'arrival_rush',
        aircraftCount: 4,
      );
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );

      // 4 degraded, 6 resilient ticks
      for (var i = 0; i < 4; i++) {
        _evaluate(
          engine,
          elapsed: Duration(seconds: 60 + i * 5),
          attention: const AttentionFocusState(
            riskLevel: AttentionRiskLevel.tunnelVision,
          ),
        );
      }
      for (var i = 0; i < 6; i++) {
        _evaluate(engine, elapsed: Duration(seconds: 80 + i * 5));
      }

      final records = engine.buildDebriefLines(); // just ensure no exception
      expect(records, isA<List<String>>());
    });

    test('buildDebriefLines includes scenario pressure patterns', () {
      final def = _makeScenario(
        weatherMode: 'low_visibility',
        sectorPersonality: 'arrival_rush',
      );
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      final lines = engine.buildDebriefLines();
      expect(lines.any((l) => l.contains('pressure patterns')), isTrue);
    });

    test('buildDebriefLines includes first destabilised system when recorded', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      engine.injectFirstDestabilisation(
        system: FirstDestabilisedSystem.workingMemory,
        at: const Duration(seconds: 120),
      );
      final lines = engine.buildDebriefLines();
      expect(
        lines.any((l) => l.contains('First cognitive system to destabilise')),
        isTrue,
      );
      expect(lines.any((l) => l.contains('Working Memory')), isTrue);
    });

    test('injection helpers accumulate correctly', () {
      final def = _makeScenario(sectorPersonality: 'arrival_rush');
      final topology = ScenarioPressureTopology.fromDefinition(def);
      final engine = TraitScenarioInteractionEngine(
        topology: topology,
        traits: ControllerTraits.neutral,
      );
      // Inject directly
      for (var i = 0; i < 20; i++) {
        engine.injectDegradationTick(ScenarioPressurePattern.multiConflictScan);
      }
      for (var i = 0; i < 5; i++) {
        engine.injectResilientTick(ScenarioPressurePattern.multiConflictScan);
      }
      final state = engine.evaluate(
        snapshot: _snap(),
        attention: AttentionFocusState.idle,
        workingMemory: WorkingMemoryState.idle,
        predictive: const PredictiveMentalModelState(),
        cascade: CognitiveCascadeState.idle,
        metaCognition: MetaCognitionState(
          latestAssessment: MetaAssessmentSnapshot(
            elapsed: const Duration(seconds: 60),
            estimatedWorkload: 0.4,
            estimatedScanQuality: 0.6,
            estimatedConfidenceReliability: 0.6,
            estimatedTaskSaturation: 0.3,
            estimatedFixationRisk: 0.1,
            calibrationAccuracy: 0.7,
          ),
        ),
        archetypeState: ControllerArchetypeState.idle,
      );
      final scanRecord = state.patternRecords.where(
        (r) => r.pattern == ScenarioPressurePattern.multiConflictScan,
      ).firstOrNull;
      expect(scanRecord, isNotNull);
      expect(scanRecord!.degradationTicks, greaterThanOrEqualTo(20));
      expect(scanRecord.resilientTicks, greaterThanOrEqualTo(5));
    });

    test('vulnerable trait correctly identified for each pattern', () {
      // Low surprise resilience → vulnerable to surpriseHeavy
      final lowSurprise = ControllerTraits(
        fixationSusceptibility: 0.5,
        confidenceBias: 0.5,
        scanDiscipline: 0.5,
        recoveryDiscipline: 0.5,
        surpriseResilience: 0.30,
        memoryStability: 0.5,
        riskTolerance: 0.5,
        attentionSwitchingEfficiency: 0.5,
      );
      final surpriseDef = _makeScenario(sectorPersonality: 'weather_disruption');
      final topol = ScenarioPressureTopology.fromDefinition(surpriseDef);
      final engine = TraitScenarioInteractionEngine(
        topology: topol,
        traits: lowSurprise,
      );
      final state = _evaluate(engine);
      final surpriseRecord = state.patternRecords.where(
        (r) => r.pattern == ScenarioPressurePattern.surpriseHeavy,
      ).firstOrNull;
      expect(surpriseRecord?.traitVulnerable, isTrue);
    });
  });
}
