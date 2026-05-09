enum DebriefInsightCategory {
  safety,
  workload,
  attention,
  workingMemory,
  predictiveModel,
  cascade,
  metaCognition,
  archetype,
  traitScenario,
  recovery,
  flow,
}

enum DebriefInsightSeverity {
  low,
  medium,
  high,
  critical,
}

class DebriefInsight {
  final String id;
  final String title;
  final String body;
  final DebriefInsightCategory category;
  final DebriefInsightSeverity severity;
  final Duration? timestamp;
  final double confidence;
  final String sourceSystem;
  final List<String> relatedAircraftIds;

  const DebriefInsight({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.severity,
    required this.timestamp,
    required this.confidence,
    required this.sourceSystem,
    this.relatedAircraftIds = const [],
  });

  DebriefInsight copyWith({
    String? id,
    String? title,
    String? body,
    DebriefInsightCategory? category,
    DebriefInsightSeverity? severity,
    Duration? timestamp,
    double? confidence,
    String? sourceSystem,
    List<String>? relatedAircraftIds,
  }) {
    return DebriefInsight(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      sourceSystem: sourceSystem ?? this.sourceSystem,
      relatedAircraftIds: relatedAircraftIds ?? this.relatedAircraftIds,
    );
  }
}

class DebriefSalienceResult {
  final List<DebriefInsight> primaryInsights;
  final List<DebriefInsight> secondaryInsights;
  final List<DebriefInsight> hiddenInsights;

  const DebriefSalienceResult({
    required this.primaryInsights,
    required this.secondaryInsights,
    required this.hiddenInsights,
  });

  static const empty = DebriefSalienceResult(
    primaryInsights: [],
    secondaryInsights: [],
    hiddenInsights: [],
  );
}
