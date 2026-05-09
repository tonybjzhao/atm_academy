import '../../models/simulation_snapshot.dart';
import '../attention/attention_focus_state.dart';
import 'cognitive_cascade_state.dart';
import 'controller_archetype.dart';
import 'controller_archetype_state.dart';
import 'meta_cognition_state.dart';
import 'predictive_mental_model_state.dart';
import 'working_memory_state.dart';

/// Converts [ControllerTraits] into per-tick [ArchetypeBiasFactors] and
/// accumulates observable trait-vulnerability signals across the session.
///
/// The engine does NOT decide what happens – it only adjusts the probability
/// parameters that other engines read.  Every bias stays subtle:
/// the mapping from trait deviation to multiplier is intentionally compressed.
class ControllerArchetypeEngine {
  final ControllerTraits traits;
  final ControllerArchetypeLabel archetypeLabel;

  int _fixationContributionTicks = 0;
  int _memoryFailureContributionTicks = 0;
  int _cascadeAmplificationTicks = 0;
  int _recoveryDelayTicks = 0;

  // ── Debrief injection helpers (used by RadarTrainingResultBuilder) ─────────

  void injectFixationTick() => _fixationContributionTicks++;
  void injectMemoryFailureTick() => _memoryFailureContributionTicks++;
  void injectCascadeAmplificationTick() => _cascadeAmplificationTicks++;
  void injectRecoveryDelayTick() => _recoveryDelayTicks++;

  ControllerArchetypeEngine({
    required this.traits,
    required this.archetypeLabel,
  });

  /// Build from a named preset.
  factory ControllerArchetypeEngine.fromLabel(ControllerArchetypeLabel label) {
    final traits = _traitsForLabel(label);
    return ControllerArchetypeEngine(traits: traits, archetypeLabel: label);
  }

  // ── Per-tick evaluation ────────────────────────────────────────────────────

  ControllerArchetypeState evaluate({
    required SimulationSnapshot snapshot,
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required PredictiveMentalModelState predictive,
    required CognitiveCascadeState cascade,
    required MetaCognitionState metaCognition,
  }) {
    final biasFactors = _buildBiasFactors(snapshot: snapshot);

    _accumulate(
      attention: attention,
      workingMemory: workingMemory,
      cascade: cascade,
      metaCognition: metaCognition,
      biasFactors: biasFactors,
    );

    return ControllerArchetypeState(
      traits: traits,
      archetypeLabel: archetypeLabel,
      biasFactors: biasFactors,
      fixationContributionTicks: _fixationContributionTicks,
      memoryFailureContributionTicks: _memoryFailureContributionTicks,
      cascadeAmplificationTicks: _cascadeAmplificationTicks,
      recoveryDelayTicks: _recoveryDelayTicks,
    );
  }

  // ── Bias factor computation ───────────────────────────────────────────────

  /// Maps each trait to a multiplier.
  ///
  /// The trait's deviation from neutral (0.5) produces a max ±30 % shift on
  /// the corresponding probability parameter.  This keeps personalities
  /// probabilistic rather than deterministic.
  ArchetypeBiasFactors _buildBiasFactors({
    required SimulationSnapshot snapshot,
  }) {
    final pressure = snapshot.sectorPressureIndex.clamp(0.0, 5.0) / 5.0;

    // Bias strength scales slightly with pressure so traits become more
    // visible under load – but never dominate behaviour.
    final biasStrength = 0.24 + pressure * 0.12;

    double _bias(double traitValue) =>
        1.0 + (traitValue - 0.5) * 2 * biasStrength;

    final fixationMult = _bias(traits.fixationSusceptibility).clamp(0.55, 1.65);

    // High confidenceBias → confidence erodes *more slowly* → mult > 1.
    final erosionMult = _bias(traits.confidenceBias).clamp(0.55, 1.65);

    // High scanDiscipline → fewer neglect events → mult < 1 on neglect prob.
    final scanNeglectMult = _bias(1.0 - traits.scanDiscipline).clamp(0.55, 1.65);

    // High recoveryDiscipline → faster recovery → mult > 1.
    final recoverySpeedMult = _bias(traits.recoveryDiscipline).clamp(0.55, 1.65);

    // High surpriseResilience → lower surprise cost → mult < 1 on cost.
    final surpriseCostMult = _bias(1.0 - traits.surpriseResilience).clamp(0.55, 1.65);

    // High memoryStability → slower memory decay → mult < 1 on decay rate.
    final memoryDecayMult = _bias(1.0 - traits.memoryStability).clamp(0.55, 1.65);

    // High fixationSusceptibility + low scanDiscipline amplifies cascade risk.
    final cascadeBase = (traits.fixationSusceptibility * 0.5 +
            (1.0 - traits.surpriseResilience) * 0.3 +
            (1.0 - traits.recoveryDiscipline) * 0.2) /
        1.0;
    final cascadeMult = (1.0 + (cascadeBase - 0.5) * 2 * biasStrength).clamp(0.55, 1.65);

    // High attentionSwitchingEfficiency → lower switching cost → mult < 1.
    final switchingCostMult =
        _bias(1.0 - traits.attentionSwitchingEfficiency).clamp(0.55, 1.65);

    return ArchetypeBiasFactors(
      fixationProbabilityMult: fixationMult,
      confidenceErosionMult: erosionMult,
      scanNeglectMult: scanNeglectMult,
      recoverySpeedMult: recoverySpeedMult,
      surpriseCostMult: surpriseCostMult,
      memoryDecayMult: memoryDecayMult,
      cascadeAmplificationMult: cascadeMult,
      switchingCostMult: switchingCostMult,
    );
  }

  // ── Signal accumulation ───────────────────────────────────────────────────

  void _accumulate({
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required CognitiveCascadeState cascade,
    required MetaCognitionState metaCognition,
    required ArchetypeBiasFactors biasFactors,
  }) {
    // Attribute fixation to the trait only when the bias is meaningfully
    // above neutral (>1.04) and fixation is actually occurring.
    final inFixation = attention.riskLevel.index >= 2;
    if (inFixation && biasFactors.fixationProbabilityMult > 1.04) {
      _fixationContributionTicks += 1;
    }

    final memoryFailing = workingMemory.forgottenIntentionCount > 0 ||
        workingMemory.stressRecoveryLoad >= 0.4;
    if (memoryFailing && biasFactors.memoryDecayMult > 1.04) {
      _memoryFailureContributionTicks += 1;
    }

    final cascadeActive = cascade.activeChainId != null;
    if (cascadeActive && biasFactors.cascadeAmplificationMult > 1.04) {
      _cascadeAmplificationTicks += 1;
    }

    final poorRecovery = metaCognition.recentRecoveryActions.isEmpty &&
        metaCognition.latestAssessment.degradationBlindness;
    if (poorRecovery && biasFactors.recoverySpeedMult < 0.96) {
      _recoveryDelayTicks += 1;
    }
  }

  // ── Debrief builder ───────────────────────────────────────────────────────

  /// Produces archetype debrief lines suitable for the result screen.
  List<String> buildDebriefLines() {
    final lines = <String>[];

    lines.add('Archetype: ${archetypeLabel.displayName}.');
    lines.addAll(_traitStrengthLines());
    lines.addAll(_traitVulnerabilityLines());
    lines.addAll(_degradationTendencyLines());
    lines.addAll(_recoveryTendencyLines());

    return List.unmodifiable(lines);
  }

  List<String> _traitStrengthLines() {
    final strengths = <String>[];
    if (traits.scanDiscipline >= 0.68) {
      strengths.add('Scan discipline: strong baseline scan coverage.');
    }
    if (traits.memoryStability >= 0.68) {
      strengths.add('Memory stability: intentions well-retained under pressure.');
    }
    if (traits.recoveryDiscipline >= 0.68) {
      strengths.add('Recovery discipline: structured recovery after degradation.');
    }
    if (traits.surpriseResilience >= 0.68) {
      strengths.add('Surprise resilience: low disruption cost from expectation violations.');
    }
    if (traits.attentionSwitchingEfficiency >= 0.72) {
      strengths.add('Attention switching: low transition cost, rapid re-orientation.');
    }
    if (traits.confidenceBias <= 0.35) {
      strengths.add('Confidence calibration: good alignment between self-estimate and reality.');
    }
    if (strengths.isEmpty) {
      strengths.add('No dominant trait strengths observed.');
    }
    return strengths.map((s) => 'Strength — $s').toList();
  }

  List<String> _traitVulnerabilityLines() {
    final vulns = <String>[];
    if (traits.fixationSusceptibility >= 0.65) {
      vulns.add('Fixation susceptibility: attention tends to lock during peak workload.');
    }
    if (traits.confidenceBias >= 0.72) {
      vulns.add('Confidence bias: slow to recognise own cognitive degradation.');
    }
    if (traits.scanDiscipline <= 0.38) {
      vulns.add('Scan discipline: irregular scan coverage; neglect windows likely.');
    }
    if (traits.recoveryDiscipline <= 0.38) {
      vulns.add('Recovery discipline: unstructured recovery; may chase problems reactively.');
    }
    if (traits.surpriseResilience <= 0.38) {
      vulns.add('Surprise resilience: unexpected events produce significant attention cost.');
    }
    if (traits.memoryStability <= 0.42) {
      vulns.add('Memory stability: pending intentions at risk under elevated workload.');
    }
    if (traits.riskTolerance >= 0.70) {
      vulns.add('Risk tolerance: comfortable with tight margins; may underestimate risk accumulation.');
    }
    if (traits.riskTolerance <= 0.28) {
      vulns.add('Risk tolerance: conservative margins generate extra cognitive overhead.');
    }
    if (vulns.isEmpty) {
      vulns.add('No dominant trait vulnerabilities identified.');
    }
    return vulns.map((v) => 'Vulnerability — $v').toList();
  }

  List<String> _degradationTendencyLines() {
    final lines = <String>[];
    if (_fixationContributionTicks > 10) {
      lines.add(
        'Degradation tendency — fixation-linked attention narrowing observed '
        '($_fixationContributionTicks ticks contributed).',
      );
    }
    if (_memoryFailureContributionTicks > 8) {
      lines.add(
        'Degradation tendency — memory instability contributed to intention '
        'loss ($_memoryFailureContributionTicks ticks).',
      );
    }
    if (_cascadeAmplificationTicks > 6) {
      lines.add(
        'Degradation tendency — trait profile amplified cascade propagation '
        '($_cascadeAmplificationTicks ticks).',
      );
    }
    return lines;
  }

  List<String> _recoveryTendencyLines() {
    final lines = <String>[];
    if (_recoveryDelayTicks > 8) {
      lines.add(
        'Recovery tendency — trait profile delayed recovery initiation '
        '($_recoveryDelayTicks ticks of degradation blindness with low recovery bias).',
      );
    }
    if (traits.recoveryDiscipline >= 0.68 && _recoveryDelayTicks == 0) {
      lines.add(
        'Recovery tendency — disciplined recovery patterns maintained '
        'throughout session.',
      );
    }
    if (traits.attentionSwitchingEfficiency >= 0.72 &&
        _cascadeAmplificationTicks == 0) {
      lines.add(
        'Recovery tendency — efficient attention switching prevented cascade '
        'escalation.',
      );
    }
    return lines;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static ControllerTraits _traitsForLabel(ControllerArchetypeLabel label) =>
      switch (label) {
        ControllerArchetypeLabel.calmStabilizer =>
          ControllerTraits.calmStabilizer,
        ControllerArchetypeLabel.reactiveFirefighter =>
          ControllerTraits.reactiveFirefighter,
        ControllerArchetypeLabel.overconfidentSpeedController =>
          ControllerTraits.overconfidentSpeedController,
        ControllerArchetypeLabel.scanDisciplinedVeteran =>
          ControllerTraits.scanDisciplinedVeteran,
        ControllerArchetypeLabel.highCapacityButFragile =>
          ControllerTraits.highCapacityButFragile,
        ControllerArchetypeLabel.conservativeLowRisk =>
          ControllerTraits.conservativeLowRisk,
        ControllerArchetypeLabel.neutral || ControllerArchetypeLabel.custom =>
          ControllerTraits.neutral,
      };
}
