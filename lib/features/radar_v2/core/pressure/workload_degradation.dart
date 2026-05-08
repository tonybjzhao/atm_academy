import '../cognitive_load/cognitive_load_level.dart';

/// Multipliers and deltas applied to simulation behaviour based on the
/// controller's current cognitive load level.
///
/// All values are [0..∞] unless otherwise documented.
/// A factor of 1.0 means "no change from baseline".
class WorkloadDegradation {
  /// Scalar applied to pilot read-back / acknowledgement delay.
  /// >1.0 = pilots take longer to respond to instructions.
  final double pilotAckDelayFactor;

  /// Added probability (0–1) that an unresolved alert escalates this tick.
  final double alertEscalationBias;

  /// Stability penalty applied to runway sequencing decisions.
  /// Larger = sequences may be disturbed by late insertions.
  final double runwaySequencingInstability;

  /// Probability bonus (0–1) of a spacing compression event per active arrival.
  final double spacingCompressionRisk;

  /// Factor applied to auto-spawning delay — slows the pace of new arrivals
  /// when controller is overwhelmed (engine-level relief valve).
  final double spawnPaceRelief;

  /// Minimum separation standard reduction (fraction 0–1).
  /// At 0 the standard is fully enforced; at 0.15 it is relaxed by 15%.
  final double separationStandardErosion;

  const WorkloadDegradation({
    required this.pilotAckDelayFactor,
    required this.alertEscalationBias,
    required this.runwaySequencingInstability,
    required this.spacingCompressionRisk,
    required this.spawnPaceRelief,
    required this.separationStandardErosion,
  });

  /// Baseline: no degradation at calm load.
  static const WorkloadDegradation none = WorkloadDegradation(
    pilotAckDelayFactor: 1.0,
    alertEscalationBias: 0.0,
    runwaySequencingInstability: 0.0,
    spacingCompressionRisk: 0.0,
    spawnPaceRelief: 1.0,
    separationStandardErosion: 0.0,
  );

  /// Builds a [WorkloadDegradation] interpolated from load score (0–10).
  /// Uses level thresholds to blend between presets.
  factory WorkloadDegradation.fromLoadScore(double score) {
    if (score < 2.5) return none;
    if (score < 5.5) {
      // calm → busy interpolation
      final t = (score - 2.5) / 3.0;
      return WorkloadDegradation._lerp(none, _busy, t);
    }
    if (score < 8.0) {
      // busy → overloaded
      final t = (score - 5.5) / 2.5;
      return WorkloadDegradation._lerp(_busy, _overloaded, t);
    }
    // overloaded → saturated
    final t = ((score - 8.0) / 2.0).clamp(0.0, 1.0);
    return WorkloadDegradation._lerp(_overloaded, _saturated, t);
  }

  /// Named preset for the busy tier.
  static const _busy = WorkloadDegradation(
    pilotAckDelayFactor: 1.3,
    alertEscalationBias: 0.05,
    runwaySequencingInstability: 0.1,
    spacingCompressionRisk: 0.08,
    spawnPaceRelief: 0.9,
    separationStandardErosion: 0.03,
  );

  /// Named preset for the overloaded tier.
  static const _overloaded = WorkloadDegradation(
    pilotAckDelayFactor: 1.8,
    alertEscalationBias: 0.15,
    runwaySequencingInstability: 0.3,
    spacingCompressionRisk: 0.18,
    spawnPaceRelief: 0.7,
    separationStandardErosion: 0.08,
  );

  /// Named preset for the saturated tier — cascading instability range.
  static const _saturated = WorkloadDegradation(
    pilotAckDelayFactor: 2.5,
    alertEscalationBias: 0.30,
    runwaySequencingInstability: 0.55,
    spacingCompressionRisk: 0.35,
    spawnPaceRelief: 0.5,
    separationStandardErosion: 0.15,
  );

  static WorkloadDegradation _lerp(
    WorkloadDegradation a,
    WorkloadDegradation b,
    double t,
  ) {
    double l(double av, double bv) => av + (bv - av) * t;
    return WorkloadDegradation(
      pilotAckDelayFactor: l(a.pilotAckDelayFactor, b.pilotAckDelayFactor),
      alertEscalationBias: l(a.alertEscalationBias, b.alertEscalationBias),
      runwaySequencingInstability:
          l(a.runwaySequencingInstability, b.runwaySequencingInstability),
      spacingCompressionRisk:
          l(a.spacingCompressionRisk, b.spacingCompressionRisk),
      spawnPaceRelief: l(a.spawnPaceRelief, b.spawnPaceRelief),
      separationStandardErosion:
          l(a.separationStandardErosion, b.separationStandardErosion),
    );
  }

  /// Returns true when the degradation is non-trivial (busy or above).
  bool get isActive => pilotAckDelayFactor > 1.0;

  /// Maps a [CognitiveLoadLevel] to its canonical preset for display purposes.
  static WorkloadDegradation forLevel(CognitiveLoadLevel level) =>
      switch (level) {
        CognitiveLoadLevel.calm => none,
        CognitiveLoadLevel.busy => _busy,
        CognitiveLoadLevel.overloaded => _overloaded,
        CognitiveLoadLevel.saturated => _saturated,
      };
}
