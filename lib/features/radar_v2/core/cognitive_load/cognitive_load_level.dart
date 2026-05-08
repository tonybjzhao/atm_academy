/// Discrete cognitive load levels experienced by an air traffic controller.
///
/// Maps to physiological and operational research on ATC workload:
/// - [calm]       < 30% capacity — routine scan, proactive interventions easy
/// - [busy]       30–65% capacity — active management, limited spare attention
/// - [overloaded] 65–85% capacity — reactive mode, errors more likely
/// - [saturated]  > 85% capacity — breakdown risk, critical errors probable
enum CognitiveLoadLevel {
  calm,
  busy,
  overloaded,
  saturated;

  /// Human-readable label for display.
  String get label => switch (this) {
        CognitiveLoadLevel.calm => 'CALM',
        CognitiveLoadLevel.busy => 'BUSY',
        CognitiveLoadLevel.overloaded => 'OVERLOADED',
        CognitiveLoadLevel.saturated => 'SATURATED',
      };

  /// Maps a raw load score (0–10) to a level.
  static CognitiveLoadLevel fromScore(double score) {
    if (score < 2.5) return CognitiveLoadLevel.calm;
    if (score < 5.5) return CognitiveLoadLevel.busy;
    if (score < 8.0) return CognitiveLoadLevel.overloaded;
    return CognitiveLoadLevel.saturated;
  }
}
