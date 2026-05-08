import 'cognitive_load_level.dart';

/// A recorded spike in cognitive load above the [overloaded] threshold.
class CognitiveLoadSpike {
  /// When the spike occurred (simulation elapsed time).
  final Duration occurredAt;

  /// Load score at the peak of the spike.
  final double peakScore;

  /// The load level at the peak.
  final CognitiveLoadLevel level;

  const CognitiveLoadSpike({
    required this.occurredAt,
    required this.peakScore,
    required this.level,
  });
}

/// Snapshot of the controller's cognitive workload at a single point in time.
///
/// Produced each tick by [CognitiveLoadEngine]. Immutable — each tick creates
/// a new state object rather than mutating the previous one.
class CognitiveLoadState {
  /// Composite workload score (0.0–10.0).
  final double totalLoadScore;

  /// Discrete level derived from [totalLoadScore].
  final CognitiveLoadLevel currentLevel;

  /// Human-readable descriptions of what is driving the load.
  /// Up to 5 entries, most significant first.
  final List<String> activeStressors;

  /// Recent spikes above [CognitiveLoadLevel.overloaded] within the last 90s.
  final List<CognitiveLoadSpike> recentSpikes;

  const CognitiveLoadState({
    required this.totalLoadScore,
    required this.currentLevel,
    required this.activeStressors,
    required this.recentSpikes,
  });

  /// Default state representing a controller at rest.
  static const CognitiveLoadState idle = CognitiveLoadState(
    totalLoadScore: 0,
    currentLevel: CognitiveLoadLevel.calm,
    activeStressors: [],
    recentSpikes: [],
  );

  bool get isOverloaded =>
      currentLevel == CognitiveLoadLevel.overloaded ||
      currentLevel == CognitiveLoadLevel.saturated;

  bool get isSaturated => currentLevel == CognitiveLoadLevel.saturated;

  @override
  String toString() =>
      'CognitiveLoadState(score=${totalLoadScore.toStringAsFixed(1)}, '
      'level=${currentLevel.label}, stressors=${activeStressors.length})';
}
