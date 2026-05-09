import 'controller_archetype.dart';

/// Immutable snapshot of the archetype engine output for a given tick.
class ControllerArchetypeState {
  /// The trait profile active this session.
  final ControllerTraits traits;

  /// Resolved label for the active archetype (may be [ControllerArchetypeLabel.custom]).
  final ControllerArchetypeLabel archetypeLabel;

  /// Bias multipliers consumed by other engines this tick.
  final ArchetypeBiasFactors biasFactors;

  /// Cumulative ticks where a trait vulnerability contributed to observed
  /// degradation (best-effort estimate, not causal).
  final int fixationContributionTicks;
  final int memoryFailureContributionTicks;
  final int cascadeAmplificationTicks;
  final int recoveryDelayTicks;

  /// Trait-level debrief sentences produced after scenario end.
  final List<String> reportLines;

  const ControllerArchetypeState({
    required this.traits,
    required this.archetypeLabel,
    required this.biasFactors,
    this.fixationContributionTicks = 0,
    this.memoryFailureContributionTicks = 0,
    this.cascadeAmplificationTicks = 0,
    this.recoveryDelayTicks = 0,
    this.reportLines = const [],
  });

  static const ControllerArchetypeState idle = ControllerArchetypeState(
    traits: ControllerTraits.neutral,
    archetypeLabel: ControllerArchetypeLabel.neutral,
    biasFactors: ArchetypeBiasFactors.neutral,
  );
}

/// Per-tick bias multipliers that each cognitive engine reads to adjust its
/// own probability parameters.  All values centre around 1.0 (no bias).
/// Values > 1.0 increase the named tendency; values < 1.0 decrease it.
class ArchetypeBiasFactors {
  /// Multiplier on fixation-start probability.
  final double fixationProbabilityMult;

  /// Multiplier on confidence erosion rate (>1 → erodes slower).
  final double confidenceErosionMult;

  /// Multiplier on scan-neglect interval probability.
  final double scanNeglectMult;

  /// Multiplier on recovery-curve speed (>1 → recovers faster).
  final double recoverySpeedMult;

  /// Multiplier on surprise-induced attention reallocation cost.
  final double surpriseCostMult;

  /// Multiplier on intention-decay rate under workload.
  final double memoryDecayMult;

  /// Multiplier on cascade-start probability.
  final double cascadeAmplificationMult;

  /// Multiplier on attention-switch cost (>1 → more residual distraction).
  final double switchingCostMult;

  const ArchetypeBiasFactors({
    required this.fixationProbabilityMult,
    required this.confidenceErosionMult,
    required this.scanNeglectMult,
    required this.recoverySpeedMult,
    required this.surpriseCostMult,
    required this.memoryDecayMult,
    required this.cascadeAmplificationMult,
    required this.switchingCostMult,
  });

  static const ArchetypeBiasFactors neutral = ArchetypeBiasFactors(
    fixationProbabilityMult: 1.0,
    confidenceErosionMult: 1.0,
    scanNeglectMult: 1.0,
    recoverySpeedMult: 1.0,
    surpriseCostMult: 1.0,
    memoryDecayMult: 1.0,
    cascadeAmplificationMult: 1.0,
    switchingCostMult: 1.0,
  );
}
