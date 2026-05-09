/// Trait profile for a controller archetype.
///
/// Each trait is a continuous value in [0.0, 1.0].
/// 0.5 is the neutral baseline for an average controller.
/// Values do NOT hard-script behaviour; they bias probabilities and
/// recovery-curve parameters used by the cognitive engines.
class ControllerTraits {
  /// Likelihood of attention becoming stuck on a single aircraft or problem.
  /// High → prolonged fixation windows; Low → shorter dwell times.
  final double fixationSusceptibility;

  /// Tendency to maintain high confidence even when evidence deteriorates.
  /// High → slower confidence erosion, over-estimates own performance;
  /// Low → calibrates quickly, may over-correct under surprise.
  final double confidenceBias;

  /// Baseline scan breadth and regularity discipline.
  /// High → wider scan, shorter neglect intervals;
  /// Low → narrower scan, longer neglect periods.
  final double scanDiscipline;

  /// Tendency to implement deliberate recovery strategies after degradation.
  /// High → faster structured recovery; Low → slower, less organised.
  final double recoveryDiscipline;

  /// Resistance to cognitive disruption when expectations are violated.
  /// High → absorbs surprises with little load spike;
  /// Low → surprise events produce larger attention reallocations.
  final double surpriseResilience;

  /// Stability of pending-intention retention under increased workload.
  /// High → fewer forgotten tasks; Low → higher prospective-memory failure rate.
  final double memoryStability;

  /// Comfort operating close to minimum separation margins.
  /// High → accepts tighter margins; Low → builds in larger buffers (adds
  ///  cognitive overhead to maintain them).
  final double riskTolerance;

  /// Efficiency of shifting attention between competing demands.
  /// High → rapid re-orientation, lower switching cost;
  /// Low → higher transition cost, residual distraction after switch.
  final double attentionSwitchingEfficiency;

  const ControllerTraits({
    required this.fixationSusceptibility,
    required this.confidenceBias,
    required this.scanDiscipline,
    required this.recoveryDiscipline,
    required this.surpriseResilience,
    required this.memoryStability,
    required this.riskTolerance,
    required this.attentionSwitchingEfficiency,
  });

  /// Neutral baseline – no trait bias applied.
  static const ControllerTraits neutral = ControllerTraits(
    fixationSusceptibility: 0.5,
    confidenceBias: 0.5,
    scanDiscipline: 0.5,
    recoveryDiscipline: 0.5,
    surpriseResilience: 0.5,
    memoryStability: 0.5,
    riskTolerance: 0.5,
    attentionSwitchingEfficiency: 0.5,
  );

  // ── Named archetypes ────────────────────────────────────────────────────────

  /// Methodical, low-volatility controller. Recovers steadily.
  /// Strengths: scan discipline, recovery, memory stability.
  /// Vulnerabilities: slightly slow to react under surprise; lower risk tolerance.
  static const ControllerTraits calmStabilizer = ControllerTraits(
    fixationSusceptibility: 0.30,
    confidenceBias: 0.45,
    scanDiscipline: 0.80,
    recoveryDiscipline: 0.78,
    surpriseResilience: 0.58,
    memoryStability: 0.75,
    riskTolerance: 0.35,
    attentionSwitchingEfficiency: 0.62,
  );

  /// Reactive, high-tempo controller who runs hot under pressure.
  /// Strengths: fast switching, high surprise resilience initially.
  /// Vulnerabilities: fixation during peak load, irregular scan, poor recovery structure.
  static const ControllerTraits reactiveFirefighter = ControllerTraits(
    fixationSusceptibility: 0.72,
    confidenceBias: 0.55,
    scanDiscipline: 0.40,
    recoveryDiscipline: 0.35,
    surpriseResilience: 0.65,
    memoryStability: 0.42,
    riskTolerance: 0.68,
    attentionSwitchingEfficiency: 0.78,
  );

  /// Fast, high-confidence operator who underestimates cognitive load.
  /// Strengths: efficiency at low workload; decisive.
  /// Vulnerabilities: overconfidence bias, late recognition, assumption errors.
  static const ControllerTraits overconfidentSpeedController = ControllerTraits(
    fixationSusceptibility: 0.48,
    confidenceBias: 0.82,
    scanDiscipline: 0.52,
    recoveryDiscipline: 0.48,
    surpriseResilience: 0.45,
    memoryStability: 0.60,
    riskTolerance: 0.76,
    attentionSwitchingEfficiency: 0.70,
  );

  /// Experience-forged scan habits; well-calibrated; notices threats early.
  /// Strengths: scan discipline, surprise resilience, memory, calibration.
  /// Vulnerabilities: conservative (high cognitive overhead at margins).
  static const ControllerTraits scanDisciplinedVeteran = ControllerTraits(
    fixationSusceptibility: 0.25,
    confidenceBias: 0.40,
    scanDiscipline: 0.88,
    recoveryDiscipline: 0.72,
    surpriseResilience: 0.74,
    memoryStability: 0.80,
    riskTolerance: 0.40,
    attentionSwitchingEfficiency: 0.68,
  );

  /// High-capacity peak performance but narrow margin before degradation cascades.
  /// Strengths: switching efficiency, memory, confidence at low load.
  /// Vulnerabilities: cascade fragility, poor recovery discipline once degraded.
  static const ControllerTraits highCapacityButFragile = ControllerTraits(
    fixationSusceptibility: 0.38,
    confidenceBias: 0.62,
    scanDiscipline: 0.65,
    recoveryDiscipline: 0.28,
    surpriseResilience: 0.36,
    memoryStability: 0.72,
    riskTolerance: 0.52,
    attentionSwitchingEfficiency: 0.85,
  );

  /// Builds wide buffers; rarely degraded but generates conservative workload.
  /// Strengths: low fixation, good calibration, steady recovery.
  /// Vulnerabilities: extra cognitive overhead of maintaining large margins.
  static const ControllerTraits conservativeLowRisk = ControllerTraits(
    fixationSusceptibility: 0.28,
    confidenceBias: 0.38,
    scanDiscipline: 0.72,
    recoveryDiscipline: 0.70,
    surpriseResilience: 0.60,
    memoryStability: 0.68,
    riskTolerance: 0.22,
    attentionSwitchingEfficiency: 0.55,
  );
}

/// Identifies which named archetype a [ControllerTraits] profile maps to,
/// or [ControllerArchetypeLabel.custom] for non-preset profiles.
enum ControllerArchetypeLabel {
  calmStabilizer,
  reactiveFirefighter,
  overconfidentSpeedController,
  scanDisciplinedVeteran,
  highCapacityButFragile,
  conservativeLowRisk,
  neutral,
  custom,
}

extension ControllerArchetypeLabelName on ControllerArchetypeLabel {
  String get displayName => switch (this) {
        ControllerArchetypeLabel.calmStabilizer => 'Calm Stabilizer',
        ControllerArchetypeLabel.reactiveFirefighter => 'Reactive Firefighter',
        ControllerArchetypeLabel.overconfidentSpeedController =>
          'Overconfident Speed Controller',
        ControllerArchetypeLabel.scanDisciplinedVeteran =>
          'Scan-Disciplined Veteran',
        ControllerArchetypeLabel.highCapacityButFragile =>
          'High-Capacity but Fragile',
        ControllerArchetypeLabel.conservativeLowRisk =>
          'Conservative Low-Risk Controller',
        ControllerArchetypeLabel.neutral => 'Neutral',
        ControllerArchetypeLabel.custom => 'Custom Profile',
      };
}
