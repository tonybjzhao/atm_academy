import '../../models/simulation_snapshot.dart';
import '../attention/attention_focus_state.dart';
import 'cognitive_cascade_state.dart';
import 'controller_archetype.dart';
import 'controller_archetype_state.dart';
import 'meta_cognition_state.dart';
import 'predictive_mental_model_state.dart';
import 'scenario_pressure_topology.dart';
import 'trait_scenario_interaction_state.dart';
import 'working_memory_state.dart';

/// Measures how a controller's trait profile interacts with a scenario's
/// natural pressure topology each tick.
///
/// This engine does NOT steer scenarios toward specific archetypes.
/// It observes what is happening and accumulates:
/// - which pressure patterns coincided with cognitive degradation
/// - which cognitive systems destabilised first
/// - which traits showed unexpected resilience or vulnerability
class TraitScenarioInteractionEngine {
  final ScenarioPressureTopology topology;
  final ControllerTraits traits;

  // ── Per-pattern accumulators ───────────────────────────────────────────────
  final Map<ScenarioPressurePattern, _PatternAccumulator> _accumulators = {};

  // ── First-destabilisation tracking ────────────────────────────────────────
  FirstDestabilisedSystem _firstSystem = FirstDestabilisedSystem.none;
  Duration? _firstDestabilisedAt;

  TraitScenarioInteractionEngine({
    required this.topology,
    required this.traits,
  }) {
    for (final pattern in topology.patterns) {
      _accumulators[pattern] = _PatternAccumulator(
        pattern: pattern,
        traitVulnerable: _isTraitVulnerable(pattern, traits),
      );
    }
  }

  // ── Debrief injection helpers (used by RadarTrainingResultBuilder) ─────────

  void injectDegradationTick(ScenarioPressurePattern pattern) {
    _accumulators.putIfAbsent(
      pattern,
      () => _PatternAccumulator(
        pattern: pattern,
        traitVulnerable: _isTraitVulnerable(pattern, traits),
      ),
    ).degradationTicks++;
  }

  void injectResilientTick(ScenarioPressurePattern pattern) {
    _accumulators.putIfAbsent(
      pattern,
      () => _PatternAccumulator(
        pattern: pattern,
        traitVulnerable: _isTraitVulnerable(pattern, traits),
      ),
    ).resilientTicks++;
  }

  void injectFirstDestabilisation({
    required FirstDestabilisedSystem system,
    required Duration at,
  }) {
    if (_firstSystem == FirstDestabilisedSystem.none) {
      _firstSystem = system;
      _firstDestabilisedAt = at;
    }
  }

  // ── Per-tick evaluation ───────────────────────────────────────────────────

  TraitScenarioInteractionState evaluate({
    required SimulationSnapshot snapshot,
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required PredictiveMentalModelState predictive,
    required CognitiveCascadeState cascade,
    required MetaCognitionState metaCognition,
    required ControllerArchetypeState archetypeState,
  }) {
    final elapsed = snapshot.elapsed;
    final degradationSignal = _computeDegradationSignal(
      attention: attention,
      workingMemory: workingMemory,
      predictive: predictive,
      cascade: cascade,
      metaCognition: metaCognition,
    );

    // Accumulate per pattern
    for (final acc in _accumulators.values) {
      acc.record(degraded: degradationSignal.anyDegraded);
    }

    // Track first destabilisation
    if (_firstSystem == FirstDestabilisedSystem.none &&
        degradationSignal.anyDegraded) {
      _firstSystem = degradationSignal.firstSystem;
      _firstDestabilisedAt = elapsed;
    }

    return _buildState(elapsed: elapsed);
  }

  // ── State construction ────────────────────────────────────────────────────

  TraitScenarioInteractionState _buildState({required Duration elapsed}) {
    final records = _accumulators.values
        .map((acc) => acc.toRecord())
        .toList(growable: false);

    final amplifyingPatterns = records
        .where((r) => r.degradationRatio >= 0.30 && r.degradationTicks >= 5)
        .map((r) => r.pattern)
        .toList(growable: false);

    final handledWellTraits = _computeHandledWellTraits(records);
    final reportLines = <String>[];

    return TraitScenarioInteractionState(
      topology: topology,
      patternRecords: records,
      firstDestabilisedSystem: _firstSystem,
      firstDestabilisationAt: _firstDestabilisedAt,
      amplifyingPatterns: amplifyingPatterns,
      handledWellTraits: handledWellTraits,
      reportLines: List.unmodifiable(reportLines),
    );
  }

  // ── Debrief builder ───────────────────────────────────────────────────────

  /// Produces debrief lines from the session-end accumulated state.
  List<String> buildDebriefLines() {
    final records = _accumulators.values.map((a) => a.toRecord()).toList();
    final lines = <String>[];

    // Scenario topology summary
    if (topology.patterns.isNotEmpty) {
      final patternNames =
          topology.patterns.map((p) => p.displayName).join(', ');
      lines.add(
        'Scenario pressure patterns: $patternNames '
        '(intensity ${topology.overallIntensity.toStringAsFixed(2)}).',
      );
    }

    // Which patterns amplified degradation
    final amplifying = records
        .where((r) => r.degradationRatio >= 0.30 && r.degradationTicks >= 5)
        .toList();
    if (amplifying.isNotEmpty) {
      for (final r in amplifying) {
        lines.add(
          'Pattern amplified degradation — ${r.pattern.displayName}: '
          '${(r.degradationRatio * 100).round()}% of observed ticks showed '
          'cognitive degradation (stressed ${r.pattern.stressedTraitLabel}).',
        );
      }
    }

    // Which traits handled their stress well
    final handled = _computeHandledWellTraits(records);
    for (final trait in handled) {
      lines.add('Trait handled well under pressure — $trait.');
    }

    // Surprise resilience under surprise-heavy pattern
    _addSurpriseInteractionLine(records, lines);

    // First destabilisation system
    if (_firstSystem != FirstDestabilisedSystem.none &&
        _firstDestabilisedAt != null) {
      lines.add(
        'First cognitive system to destabilise: '
        '${_firstSystem.displayName} '
        '(T+${_firstDestabilisedAt!.inSeconds}s).',
      );
    }

    return List.unmodifiable(lines);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  _DegradationSignal _computeDegradationSignal({
    required AttentionFocusState attention,
    required WorkingMemoryState workingMemory,
    required PredictiveMentalModelState predictive,
    required CognitiveCascadeState cascade,
    required MetaCognitionState metaCognition,
  }) {
    var firstSystem = FirstDestabilisedSystem.none;

    // Attention: fixation or tunnel vision
    if (attention.riskLevel.index >= 2) {
      firstSystem = FirstDestabilisedSystem.attention;
    }

    // Working memory: forgotten intentions
    if (firstSystem == FirstDestabilisedSystem.none &&
        workingMemory.forgottenIntentionCount > 0) {
      firstSystem = FirstDestabilisedSystem.workingMemory;
    }

    // Predictive model: surprise overload moments accumulated
    if (firstSystem == FirstDestabilisedSystem.none &&
        predictive.surpriseOverloadMoments > 0) {
      firstSystem = FirstDestabilisedSystem.predictiveModel;
    }

    // Cascade: active chain
    if (firstSystem == FirstDestabilisedSystem.none &&
        cascade.activeChainId != null) {
      firstSystem = FirstDestabilisedSystem.cognitiveCascade;
    }

    // Meta-cognition: degradation blindness
    if (firstSystem == FirstDestabilisedSystem.none &&
        metaCognition.latestAssessment.degradationBlindness) {
      firstSystem = FirstDestabilisedSystem.metaCognition;
    }

    return _DegradationSignal(
      anyDegraded: firstSystem != FirstDestabilisedSystem.none,
      firstSystem: firstSystem,
    );
  }

  List<String> _computeHandledWellTraits(
    List<PatternTraitInteractionRecord> records,
  ) {
    final handled = <String>[];
    for (final r in records) {
      // Handled well = trait was vulnerable but degradation ratio is low
      if (r.traitVulnerable && r.degradationRatio < 0.15 && r.resilientTicks >= 5) {
        handled.add(r.pattern.stressedTraitLabel);
      }
      // Also: trait not vulnerable and they sailed through
      if (!r.traitVulnerable && r.degradationRatio < 0.10 && r.resilientTicks >= 5) {
        handled.add('${r.pattern.stressedTraitLabel} (trait strength)');
      }
    }
    return handled;
  }

  void _addSurpriseInteractionLine(
    List<PatternTraitInteractionRecord> records,
    List<String> lines,
  ) {
    final surpriseRecord = records
        .where((r) => r.pattern == ScenarioPressurePattern.surpriseHeavy)
        .firstOrNull;
    if (surpriseRecord == null) return;

    if (surpriseRecord.traitVulnerable &&
        surpriseRecord.degradationRatio >= 0.25) {
      lines.add(
        'Surprise resilience vulnerability amplified by surprise-heavy '
        'scenario pattern.',
      );
    } else if (!surpriseRecord.traitVulnerable &&
        surpriseRecord.degradationRatio < 0.15) {
      lines.add(
        'Surprise resilience strength absorbed the surprise-heavy scenario '
        'pattern effectively.',
      );
    }
  }

  static bool _isTraitVulnerable(
    ScenarioPressurePattern pattern,
    ControllerTraits traits,
  ) =>
      switch (pattern) {
        ScenarioPressurePattern.surpriseHeavy => traits.surpriseResilience < 0.45,
        ScenarioPressurePattern.multiConflictScan => traits.scanDiscipline < 0.45,
        ScenarioPressurePattern.longDurationBacklog => traits.memoryStability < 0.45,
        ScenarioPressurePattern.rapidEscalation => traits.recoveryDiscipline < 0.45,
        ScenarioPressurePattern.tightSpacing =>
          traits.riskTolerance > 0.70 || traits.riskTolerance < 0.28,
      };
}

// ── Internal accumulators ──────────────────────────────────────────────────

class _PatternAccumulator {
  final ScenarioPressurePattern pattern;
  final bool traitVulnerable;
  int degradationTicks = 0;
  int resilientTicks = 0;

  _PatternAccumulator({
    required this.pattern,
    required this.traitVulnerable,
  });

  void record({required bool degraded}) {
    if (degraded) {
      degradationTicks++;
    } else {
      resilientTicks++;
    }
  }

  PatternTraitInteractionRecord toRecord() {
    final total = degradationTicks + resilientTicks;
    final ratio = total > 0 ? degradationTicks / total : 0.0;
    return PatternTraitInteractionRecord(
      pattern: pattern,
      degradationTicks: degradationTicks,
      resilientTicks: resilientTicks,
      traitVulnerable: traitVulnerable,
      traitResilientDespiteVulnerability:
          traitVulnerable && ratio < 0.15 && resilientTicks >= 5,
    );
  }
}

class _DegradationSignal {
  final bool anyDegraded;
  final FirstDestabilisedSystem firstSystem;

  const _DegradationSignal({
    required this.anyDegraded,
    required this.firstSystem,
  });
}
