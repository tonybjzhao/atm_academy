import 'package:atm_flutter/features/radar_v2/core/attention/attention_focus_state.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_level.dart';
import 'package:atm_flutter/features/radar_v2/core/cognitive_load/cognitive_load_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/cognitive_cascade_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_archetype.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_archetype_engine.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/controller_archetype_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/meta_cognition_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/predictive_mental_model_state.dart';
import 'package:atm_flutter/features/radar_v2/core/mental_model/working_memory_state.dart';
import 'package:atm_flutter/features/radar_v2/models/simulation_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

SimulationSnapshot _snapshot({
  required Duration elapsed,
  double load = 2.0,
  double pressure = 0.0,
}) {
  return SimulationSnapshot(
    tick: elapsed.inSeconds,
    elapsed: elapsed,
    aircraft: const [],
    separation: const [],
    sectorPressureIndex: pressure,
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

ControllerArchetypeState _evaluate(
  ControllerArchetypeEngine engine, {
  Duration elapsed = const Duration(seconds: 120),
  double load = 2.0,
  double pressure = 0.0,
  AttentionFocusState? attention,
  WorkingMemoryState? workingMemory,
  CognitiveCascadeState? cascade,
  MetaCognitionState? metaCognition,
}) {
  return engine.evaluate(
    snapshot: _snapshot(elapsed: elapsed, load: load, pressure: pressure),
    attention: attention ?? AttentionFocusState.idle,
    workingMemory: workingMemory ?? WorkingMemoryState.idle,
    predictive: const PredictiveMentalModelState(),
    cascade: cascade ?? CognitiveCascadeState.idle,
    metaCognition: metaCognition ??
        MetaCognitionState(
          latestAssessment: MetaAssessmentSnapshot(
            elapsed: elapsed,
            estimatedWorkload: 0.3,
            estimatedScanQuality: 0.7,
            estimatedConfidenceReliability: 0.6,
            estimatedTaskSaturation: 0.3,
            estimatedFixationRisk: 0.1,
            calibrationAccuracy: 0.8,
          ),
        ),
  );
}

void main() {
  group('ControllerArchetypeEngine', () {
    test('idle state has neutral traits and unit bias factors', () {
      final state = ControllerArchetypeState.idle;
      expect(state.biasFactors.fixationProbabilityMult, 1.0);
      expect(state.biasFactors.recoverySpeedMult, 1.0);
      expect(state.biasFactors.memoryDecayMult, 1.0);
      expect(state.archetypeLabel, ControllerArchetypeLabel.neutral);
    });

    test('fromLabel produces correct archetype label', () {
      for (final label in [
        ControllerArchetypeLabel.calmStabilizer,
        ControllerArchetypeLabel.reactiveFirefighter,
        ControllerArchetypeLabel.overconfidentSpeedController,
        ControllerArchetypeLabel.scanDisciplinedVeteran,
        ControllerArchetypeLabel.highCapacityButFragile,
        ControllerArchetypeLabel.conservativeLowRisk,
      ]) {
        final engine = ControllerArchetypeEngine.fromLabel(label);
        expect(engine.archetypeLabel, label);
      }
    });

    test('evaluate returns state with matching label', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.calmStabilizer,
      );
      final state = _evaluate(engine);
      expect(state.archetypeLabel, ControllerArchetypeLabel.calmStabilizer);
    });

    test('all bias multipliers are within [0.55, 1.65] at zero pressure', () {
      for (final label in ControllerArchetypeLabel.values) {
        final engine = ControllerArchetypeEngine.fromLabel(label);
        final state = _evaluate(engine, pressure: 0.0);
        final b = state.biasFactors;
        for (final v in [
          b.fixationProbabilityMult,
          b.confidenceErosionMult,
          b.scanNeglectMult,
          b.recoverySpeedMult,
          b.surpriseCostMult,
          b.memoryDecayMult,
          b.cascadeAmplificationMult,
          b.switchingCostMult,
        ]) {
          expect(v, greaterThanOrEqualTo(0.55),
              reason: 'label=$label');
          expect(v, lessThanOrEqualTo(1.65),
              reason: 'label=$label');
        }
      }
    });

    test('all bias multipliers are within [0.55, 1.65] at max pressure', () {
      for (final label in ControllerArchetypeLabel.values) {
        final engine = ControllerArchetypeEngine.fromLabel(label);
        final state = _evaluate(engine, pressure: 5.0);
        final b = state.biasFactors;
        for (final v in [
          b.fixationProbabilityMult,
          b.confidenceErosionMult,
          b.scanNeglectMult,
          b.recoverySpeedMult,
          b.surpriseCostMult,
          b.memoryDecayMult,
          b.cascadeAmplificationMult,
          b.switchingCostMult,
        ]) {
          expect(v, greaterThanOrEqualTo(0.55),
              reason: 'label=$label');
          expect(v, lessThanOrEqualTo(1.65),
              reason: 'label=$label');
        }
      }
    });

    test('calm stabilizer has lower fixation mult than reactive firefighter', () {
      final calm = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.calmStabilizer,
      );
      final reactive = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.reactiveFirefighter,
      );
      final calmState = _evaluate(calm, pressure: 3.0);
      final reactiveState = _evaluate(reactive, pressure: 3.0);
      expect(
        calmState.biasFactors.fixationProbabilityMult,
        lessThan(reactiveState.biasFactors.fixationProbabilityMult),
      );
    });

    test('scan-disciplined veteran has lower scan neglect mult than reactive', () {
      final veteran = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.scanDisciplinedVeteran,
      );
      final reactive = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.reactiveFirefighter,
      );
      final veteranState = _evaluate(veteran);
      final reactiveState = _evaluate(reactive);
      expect(
        veteranState.biasFactors.scanNeglectMult,
        lessThan(reactiveState.biasFactors.scanNeglectMult),
      );
    });

    test('overconfident controller has higher confidence erosion mult (erodes slower)', () {
      final overconf = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.overconfidentSpeedController,
      );
      final conservative = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.conservativeLowRisk,
      );
      final overconfState = _evaluate(overconf);
      final conservativeState = _evaluate(conservative);
      expect(
        overconfState.biasFactors.confidenceErosionMult,
        greaterThan(conservativeState.biasFactors.confidenceErosionMult),
      );
    });

    test('calm stabilizer has higher recovery speed mult than fragile', () {
      final calm = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.calmStabilizer,
      );
      final fragile = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.highCapacityButFragile,
      );
      final calmState = _evaluate(calm);
      final fragileState = _evaluate(fragile);
      expect(
        calmState.biasFactors.recoverySpeedMult,
        greaterThan(fragileState.biasFactors.recoverySpeedMult),
      );
    });

    test('fixation ticks accumulate when fixation is occurring and bias is high', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.reactiveFirefighter,
      );
      const fixationAttention = AttentionFocusState(
        riskLevel: AttentionRiskLevel.tunnelVision,
      );
      // Run several ticks
      ControllerArchetypeState? lastState;
      for (var i = 0; i < 20; i++) {
        lastState = _evaluate(
          engine,
          elapsed: Duration(seconds: 60 + i * 5),
          attention: fixationAttention,
          pressure: 3.0,
        );
      }
      expect(lastState!.fixationContributionTicks, greaterThan(0));
    });

    test('memory failure ticks accumulate when forgotten intentions are present', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.reactiveFirefighter,
      );
      const badMemory = WorkingMemoryState(
        forgottenIntentionCount: 2,
      );
      ControllerArchetypeState? lastState;
      for (var i = 0; i < 20; i++) {
        lastState = _evaluate(
          engine,
          elapsed: Duration(seconds: 60 + i * 5),
          workingMemory: badMemory,
          pressure: 3.0,
        );
      }
      expect(lastState!.memoryFailureContributionTicks, greaterThan(0));
    });

    test('cascade ticks accumulate when cascade is active and bias is high', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.reactiveFirefighter,
      );
      const activeCascade = CognitiveCascadeState(
        activeChainId: 'test-chain-001',
      );
      ControllerArchetypeState? lastState;
      for (var i = 0; i < 20; i++) {
        lastState = _evaluate(
          engine,
          elapsed: Duration(seconds: 90 + i * 5),
          cascade: activeCascade,
          pressure: 5.0,
        );
      }
      expect(lastState!.cascadeAmplificationTicks, greaterThan(0));
    });

    test('buildDebriefLines includes archetype label line', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.calmStabilizer,
      );
      final lines = engine.buildDebriefLines();
      expect(lines.any((l) => l.contains('Calm Stabilizer')), isTrue);
    });

    test('buildDebriefLines includes at least one Strength line', () {
      for (final label in [
        ControllerArchetypeLabel.calmStabilizer,
        ControllerArchetypeLabel.scanDisciplinedVeteran,
      ]) {
        final engine = ControllerArchetypeEngine.fromLabel(label);
        final lines = engine.buildDebriefLines();
        expect(lines.any((l) => l.startsWith('Strength')), isTrue,
            reason: 'label=$label');
      }
    });

    test('buildDebriefLines includes at least one Vulnerability line for fragile types', () {
      for (final label in [
        ControllerArchetypeLabel.reactiveFirefighter,
        ControllerArchetypeLabel.highCapacityButFragile,
        ControllerArchetypeLabel.overconfidentSpeedController,
      ]) {
        final engine = ControllerArchetypeEngine.fromLabel(label);
        final lines = engine.buildDebriefLines();
        expect(lines.any((l) => l.startsWith('Vulnerability')), isTrue,
            reason: 'label=$label');
      }
    });

    test('debrief injection helpers restore accumulated counters', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.reactiveFirefighter,
      );
      for (var i = 0; i < 12; i++) {
        engine.injectFixationTick();
      }
      for (var i = 0; i < 9; i++) {
        engine.injectMemoryFailureTick();
      }
      for (var i = 0; i < 7; i++) {
        engine.injectCascadeAmplificationTick();
      }
      for (var i = 0; i < 10; i++) {
        engine.injectRecoveryDelayTick();
      }
      final lines = engine.buildDebriefLines();
      expect(lines.any((l) => l.contains('fixation-linked')), isTrue);
      expect(lines.any((l) => l.contains('memory instability')), isTrue);
      expect(lines.any((l) => l.contains('cascade propagation')), isTrue);
      expect(lines.any((l) => l.contains('delayed recovery')), isTrue);
    });

    test('neutral archetype produces neutral bias factors', () {
      final engine = ControllerArchetypeEngine.fromLabel(
        ControllerArchetypeLabel.neutral,
      );
      // At zero pressure, deviation is zero, bias = 1.0 for all
      final state = _evaluate(engine, pressure: 0.0);
      final b = state.biasFactors;
      expect(b.fixationProbabilityMult, closeTo(1.0, 0.01));
      expect(b.scanNeglectMult, closeTo(1.0, 0.01));
      expect(b.memoryDecayMult, closeTo(1.0, 0.01));
    });

    test('archetype label display name is non-empty for all labels', () {
      for (final label in ControllerArchetypeLabel.values) {
        expect(label.displayName.isNotEmpty, isTrue);
      }
    });
  });
}
