import '../../scenario/scenario_definition.dart';

/// Classifies the natural pressure patterns present in a scenario.
///
/// Topologies are derived from the scenario's structural properties —
/// traffic count, weather mode, sector personality, pressure multiplier,
/// duration, etc.  They do NOT target any specific archetype.  The
/// cognitive interaction engine separately measures how a controller's
/// trait profile interacts with these patterns.
enum ScenarioPressurePattern {
  /// Frequent unexpected aircraft behaviour (weather, speed instability,
  /// go-arounds), violating pre-formed mental models.
  surpriseHeavy,

  /// Multiple simultaneous conflicts requiring wide scan coverage.
  multiConflictScan,

  /// Extended duration with a high-density traffic queue that must be
  /// managed sequentially — stresses prospective memory.
  longDurationBacklog,

  /// Fast-escalating conflict chains requiring rapid recovery pivoting.
  rapidEscalation,

  /// Aircraft spacing targets close to minimum, raising the cognitive
  /// overhead of managing margins.
  tightSpacing,
}

extension ScenarioPressurePatternName on ScenarioPressurePattern {
  String get displayName => switch (this) {
        ScenarioPressurePattern.surpriseHeavy => 'Surprise-Heavy',
        ScenarioPressurePattern.multiConflictScan => 'Multi-Conflict Scan',
        ScenarioPressurePattern.longDurationBacklog => 'Long-Duration Backlog',
        ScenarioPressurePattern.rapidEscalation => 'Rapid Escalation',
        ScenarioPressurePattern.tightSpacing => 'Tight-Spacing Traffic',
      };

  /// Which controller trait is most stressed by this pressure pattern.
  /// Used in debrief to link patterns to trait vulnerabilities.
  String get stressedTraitLabel => switch (this) {
        ScenarioPressurePattern.surpriseHeavy => 'surprise resilience',
        ScenarioPressurePattern.multiConflictScan => 'scan discipline',
        ScenarioPressurePattern.longDurationBacklog => 'memory stability',
        ScenarioPressurePattern.rapidEscalation => 'recovery discipline',
        ScenarioPressurePattern.tightSpacing => 'risk tolerance',
      };
}

/// Immutable pressure profile derived from a [ScenarioDefinition].
class ScenarioPressureTopology {
  /// Set of pressure patterns present in this scenario.
  final Set<ScenarioPressurePattern> patterns;

  /// Aggregate intensity of the scenario's pressure: [0.0, 1.0].
  /// Combines aircraft count, pressure multiplier, weather, and duration.
  final double overallIntensity;

  /// Number of distinct simultaneous conflict windows inferred from
  /// traffic density and scenario duration.
  final int estimatedConflictWindows;

  const ScenarioPressureTopology({
    required this.patterns,
    required this.overallIntensity,
    required this.estimatedConflictWindows,
  });

  static const ScenarioPressureTopology empty = ScenarioPressureTopology(
    patterns: {},
    overallIntensity: 0.0,
    estimatedConflictWindows: 0,
  );

  bool get hasSurprisePressure =>
      patterns.contains(ScenarioPressurePattern.surpriseHeavy);
  bool get hasScanPressure =>
      patterns.contains(ScenarioPressurePattern.multiConflictScan);
  bool get hasBacklogPressure =>
      patterns.contains(ScenarioPressurePattern.longDurationBacklog);
  bool get hasEscalationPressure =>
      patterns.contains(ScenarioPressurePattern.rapidEscalation);
  bool get hasTightSpacingPressure =>
      patterns.contains(ScenarioPressurePattern.tightSpacing);

  // ── Factory ─────────────────────────────────────────────────────────────

  factory ScenarioPressureTopology.fromDefinition(
    ScenarioDefinition definition,
  ) {
    final patterns = <ScenarioPressurePattern>{};

    final aircraftCount = definition.aircraft.length;
    final durationMinutes = definition.duration.inMinutes.toDouble();
    final pressureMultiplier = definition.workloadPressureMultiplier;
    final isLowVisibility = definition.weatherMode == 'low_visibility';
    final personality = definition.sectorPersonality;
    final difficulty = definition.difficulty;

    // ── Surprise-Heavy ──────────────────────────────────────────────────────
    // Low-visibility weather creates frequent expectation violations.
    // Weather-disruption personality implies abnormal events.
    // High difficulty amplifies surprise frequency.
    if (isLowVisibility ||
        personality == 'weather_disruption' ||
        (pressureMultiplier >= 1.25 && difficulty >= 4)) {
      patterns.add(ScenarioPressurePattern.surpriseHeavy);
    }

    // ── Multi-Conflict Scan ─────────────────────────────────────────────────
    // More aircraft in a short time → higher probability of simultaneous
    // conflicts needing wide scan.
    final trafficDensity =
        aircraftCount / (durationMinutes.clamp(1.0, double.infinity));
    if (aircraftCount >= 4 ||
        trafficDensity >= 0.5 ||
        personality == 'arrival_rush' ||
        personality == 'busy_terminal') {
      patterns.add(ScenarioPressurePattern.multiConflictScan);
    }

    // ── Long-Duration Backlog ───────────────────────────────────────────────
    // Long scenarios with steady traffic create growing intention queues.
    if (durationMinutes >= 6.0 && aircraftCount >= 4) {
      patterns.add(ScenarioPressurePattern.longDurationBacklog);
    }

    // ── Rapid Escalation ───────────────────────────────────────────────────
    // High pressure multiplier + high difficulty implies fast conflict build-up.
    if (pressureMultiplier >= 1.2 && difficulty >= 3) {
      patterns.add(ScenarioPressurePattern.rapidEscalation);
    }

    // ── Tight Spacing ───────────────────────────────────────────────────────
    // Low-visibility spacing multiplier > 1 means closer actual targets.
    // Busy terminal sectors inherently require tighter sequencing.
    if (isLowVisibility ||
        definition.lowVisibilitySpacingMultiplier > 1.0 ||
        personality == 'busy_terminal' ||
        aircraftCount >= 5) {
      patterns.add(ScenarioPressurePattern.tightSpacing);
    }

    // ── Overall intensity ───────────────────────────────────────────────────
    final normalizedDifficulty = ((difficulty - 1) / 4.0).clamp(0.0, 1.0);
    final normalizedPressure =
        ((pressureMultiplier - 1.0) / 0.5).clamp(0.0, 1.0);
    final normalizedDensity = (trafficDensity / 1.5).clamp(0.0, 1.0);
    final patternLoad = (patterns.length / 5.0).clamp(0.0, 1.0);
    final overallIntensity = (normalizedDifficulty * 0.35 +
            normalizedPressure * 0.25 +
            normalizedDensity * 0.2 +
            patternLoad * 0.2)
        .clamp(0.0, 1.0);

    // Estimate simultaneous conflict windows from density × patterns
    final estimatedConflictWindows =
        ((aircraftCount / 2).floor() + (patterns.length >= 2 ? 1 : 0))
            .clamp(0, 8);

    return ScenarioPressureTopology(
      patterns: Set.unmodifiable(patterns),
      overallIntensity: overallIntensity,
      estimatedConflictWindows: estimatedConflictWindows,
    );
  }
}
