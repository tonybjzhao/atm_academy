import 'scenario_pressure_topology.dart';

/// Per-pattern record of how a scenario pressure pattern interacted with
/// the controller's trait profile during the session.
class PatternTraitInteractionRecord {
  /// The scenario pressure pattern that was active.
  final ScenarioPressurePattern pattern;

  /// Ticks where this pattern coincided with measurable cognitive degradation.
  final int degradationTicks;

  /// Ticks where the controller handled the pattern without notable degradation.
  final int resilientTicks;

  /// Whether the vulnerable trait was below 0.45 (disadvantaged).
  final bool traitVulnerable;

  /// Whether the controller showed resilience despite a vulnerable trait.
  final bool traitResilientDespiteVulnerability;

  const PatternTraitInteractionRecord({
    required this.pattern,
    required this.degradationTicks,
    required this.resilientTicks,
    required this.traitVulnerable,
    required this.traitResilientDespiteVulnerability,
  });

  /// Ratio of degraded ticks to total observed ticks. [0.0, 1.0].
  double get degradationRatio {
    final total = degradationTicks + resilientTicks;
    if (total == 0) return 0.0;
    return (degradationTicks / total).clamp(0.0, 1.0);
  }
}

/// Which cognitive system destabilised first under the scenario pressure.
enum FirstDestabilisedSystem {
  none,
  attention,
  workingMemory,
  predictiveModel,
  cognitiveCascade,
  metaCognition,
}

extension FirstDestabilisedSystemName on FirstDestabilisedSystem {
  String get displayName => switch (this) {
        FirstDestabilisedSystem.none => 'None',
        FirstDestabilisedSystem.attention => 'Attention & Scan',
        FirstDestabilisedSystem.workingMemory => 'Working Memory',
        FirstDestabilisedSystem.predictiveModel => 'Predictive Mental Model',
        FirstDestabilisedSystem.cognitiveCascade => 'Cognitive Cascade',
        FirstDestabilisedSystem.metaCognition => 'Meta-Cognition',
      };
}

/// Immutable snapshot of the interaction engine output for a given tick.
class TraitScenarioInteractionState {
  /// The topology that was computed for this scenario at startup.
  final ScenarioPressureTopology topology;

  /// Per-pattern records accumulated across the session.
  final List<PatternTraitInteractionRecord> patternRecords;

  /// The first cognitive system observed to destabilise.
  final FirstDestabilisedSystem firstDestabilisedSystem;

  /// Ticks elapsed when the first destabilisation was detected.
  final Duration? firstDestabilisationAt;

  /// Which patterns amplified degradation (degradationRatio >= threshold).
  final List<ScenarioPressurePattern> amplifyingPatterns;

  /// Which traits handled their stress well (resilientTicks dominant).
  final List<String> handledWellTraits;

  /// Debrief lines.
  final List<String> reportLines;

  const TraitScenarioInteractionState({
    required this.topology,
    required this.patternRecords,
    required this.firstDestabilisedSystem,
    this.firstDestabilisationAt,
    required this.amplifyingPatterns,
    required this.handledWellTraits,
    required this.reportLines,
  });

  static const TraitScenarioInteractionState idle =
      TraitScenarioInteractionState(
    topology: ScenarioPressureTopology.empty,
    patternRecords: [],
    firstDestabilisedSystem: FirstDestabilisedSystem.none,
    amplifyingPatterns: [],
    handledWellTraits: [],
    reportLines: [],
  );
}
