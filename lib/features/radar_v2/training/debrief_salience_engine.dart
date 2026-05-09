import 'debrief_insight.dart';

class DebriefSalienceEngine {
  const DebriefSalienceEngine();

  DebriefSalienceResult rank({
    List<String> workloadReports = const [],
    List<String> attentionReports = const [],
    List<String> workingMemoryReports = const [],
    List<String> predictiveModelReports = const [],
    List<String> cascadeReports = const [],
    List<String> metaCognitionReports = const [],
    List<String> archetypeReports = const [],
    List<String> traitScenarioReports = const [],
    String? scenarioLearningGoal,
  }) {
    final insights = <DebriefInsight>[
      ..._fromReports(
        workloadReports,
        sourceSystem: 'workload',
        category: DebriefInsightCategory.workload,
      ),
      ..._fromReports(
        attentionReports,
        sourceSystem: 'attention',
        category: DebriefInsightCategory.attention,
      ),
      ..._fromReports(
        workingMemoryReports,
        sourceSystem: 'working-memory',
        category: DebriefInsightCategory.workingMemory,
      ),
      ..._fromReports(
        predictiveModelReports,
        sourceSystem: 'predictive-model',
        category: DebriefInsightCategory.predictiveModel,
      ),
      ..._fromReports(
        cascadeReports,
        sourceSystem: 'cascade',
        category: DebriefInsightCategory.cascade,
      ),
      ..._fromReports(
        metaCognitionReports,
        sourceSystem: 'meta-cognition',
        category: DebriefInsightCategory.metaCognition,
      ),
      ..._fromReports(
        archetypeReports,
        sourceSystem: 'archetype',
        category: DebriefInsightCategory.archetype,
        baseConfidence: 0.5,
      ),
      ..._fromReports(
        traitScenarioReports,
        sourceSystem: 'trait-scenario',
        category: DebriefInsightCategory.traitScenario,
        baseConfidence: 0.48,
      ),
    ];

    return rankInsights(
      insights,
      scenarioLearningGoal: scenarioLearningGoal,
    );
  }

  DebriefSalienceResult rankInsights(
    List<DebriefInsight> insights, {
    String? scenarioLearningGoal,
  }) {
    if (insights.isEmpty) return DebriefSalienceResult.empty;

    final deduped = _dedupe(insights);
    deduped.sort((a, b) {
      final scoreB = _score(b, scenarioLearningGoal);
      final scoreA = _score(a, scenarioLearningGoal);
      final byScore = scoreB.compareTo(scoreA);
      if (byScore != 0) return byScore;
      return _timestampSeconds(a).compareTo(_timestampSeconds(b));
    });

    final eligiblePrimary = <DebriefInsight>[];
    final detailPool = <DebriefInsight>[];
    for (final insight in deduped) {
      if (insight.confidence < 0.45 ||
          insight.severity == DebriefInsightSeverity.low ||
          _isMostlyAbstract(insight)) {
        detailPool.add(insight);
      } else {
        eligiblePrimary.add(insight);
      }
    }

    final primary = eligiblePrimary.take(3).toList(growable: false);
    final primaryIds = primary.map((insight) => insight.id).toSet();
    final remaining = [
      ...eligiblePrimary.where((insight) => !primaryIds.contains(insight.id)),
      ...detailPool,
    ];
    final secondary = remaining.take(3).toList(growable: false);
    final secondaryIds = secondary.map((insight) => insight.id).toSet();
    final hidden = remaining
        .where((insight) => !secondaryIds.contains(insight.id))
        .take(12)
        .toList(growable: false);

    return DebriefSalienceResult(
      primaryInsights: List.unmodifiable(primary),
      secondaryInsights: List.unmodifiable(secondary),
      hiddenInsights: List.unmodifiable(hidden),
    );
  }

  List<DebriefInsight> _fromReports(
    List<String> reports, {
    required String sourceSystem,
    required DebriefInsightCategory category,
    double baseConfidence = 0.72,
  }) {
    final insights = <DebriefInsight>[];
    for (var i = 0; i < reports.length; i++) {
      final body = _safeWording(reports[i].trim());
      if (body.isEmpty) continue;
      final severity = _severityFor(body, category);
      final resolvedCategory = _categoryFor(body, category);
      insights.add(
        DebriefInsight(
          id: '$sourceSystem-$i-${body.hashCode}',
          title: _titleFor(body, resolvedCategory),
          body: body,
          category: resolvedCategory,
          severity: severity,
          timestamp: _firstTimestamp(body),
          confidence: _confidenceFor(body, baseConfidence, resolvedCategory),
          sourceSystem: sourceSystem,
          relatedAircraftIds: _aircraftIds(body),
        ),
      );
    }
    return insights;
  }

  List<DebriefInsight> _dedupe(List<DebriefInsight> insights) {
    final byKey = <String, DebriefInsight>{};
    for (final insight in insights) {
      final key = _dedupeKey(insight);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = insight;
        continue;
      }
      final better =
          _score(insight, null) > _score(existing, null) ? insight : existing;
      final ids = {
        ...existing.relatedAircraftIds,
        ...insight.relatedAircraftIds,
      }.toList()
        ..sort();
      byKey[key] = better.copyWith(
        confidence: existing.confidence > insight.confidence
            ? existing.confidence
            : insight.confidence,
        relatedAircraftIds: ids,
      );
    }
    return byKey.values.toList();
  }

  double _score(DebriefInsight insight, String? learningGoal) {
    final lower = '${insight.title} ${insight.body}'.toLowerCase();
    var score = switch (insight.severity) {
      DebriefInsightSeverity.critical => 90.0,
      DebriefInsightSeverity.high => 68.0,
      DebriefInsightSeverity.medium => 42.0,
      DebriefInsightSeverity.low => 16.0,
    };
    score += insight.confidence.clamp(0.0, 1.0) * 18;

    if (_hasAny(lower, ['separation', 'loss', 'runway', 'critical'])) {
      score += 28;
    }
    if (_hasAny(lower, ['first', 'began', 'onset', 'destabil'])) {
      score += 16;
    }
    if (_hasAny(lower, ['repeated', 'burst', 'again', 'count'])) {
      score += 10;
    }
    if (_hasAny(lower, [
      'intervene',
      'scan',
      'stabilize',
      'maintain',
      'keep',
      'earlier',
      'recover',
    ])) {
      score += 12;
    }
    if (learningGoal != null && _overlapsLearningGoal(lower, learningGoal)) {
      score += 14;
    }
    if (insight.category == DebriefInsightCategory.traitScenario) {
      score -= 28;
    } else if (insight.category == DebriefInsightCategory.archetype) {
      score -= 18;
    } else if (insight.category == DebriefInsightCategory.metaCognition) {
      score -= 4;
    }
    if (_isMostlyAbstract(insight)) score -= 24;
    return score;
  }

  DebriefInsightCategory _categoryFor(
    String body,
    DebriefInsightCategory fallback,
  ) {
    final lower = body.toLowerCase();
    if (_hasAny(lower, ['separation', 'runway', 'go-around', 'critical'])) {
      return DebriefInsightCategory.safety;
    }
    if (_hasAny(lower, ['recovery', 'recovered', 'stabilized'])) {
      return DebriefInsightCategory.recovery;
    }
    if (_hasAny(lower, ['spacing', 'flow', 'arrival', 'sequence', 'merge'])) {
      return DebriefInsightCategory.flow;
    }
    return fallback;
  }

  DebriefInsightSeverity _severityFor(
    String body,
    DebriefInsightCategory category,
  ) {
    final lower = body.toLowerCase();
    if (_hasAny(lower, ['separation loss', 'lost separation', 'critical'])) {
      return DebriefInsightSeverity.critical;
    }
    if (_hasAny(lower, [
      'ignored',
      'tunnel vision',
      'overload',
      'runway',
      'late',
      'unattended',
      'unstable',
      'go-around',
    ])) {
      return DebriefInsightSeverity.high;
    }
    if (_hasAny(lower, [
      'drift',
      'mismatch',
      'forgotten',
      'interrupted',
      'fixation',
      'surprise',
      'cascade',
      'command',
      'spacing',
    ])) {
      return DebriefInsightSeverity.medium;
    }
    if (category == DebriefInsightCategory.traitScenario ||
        category == DebriefInsightCategory.archetype) {
      return DebriefInsightSeverity.low;
    }
    return DebriefInsightSeverity.medium;
  }

  double _confidenceFor(
    String body,
    double base,
    DebriefInsightCategory category,
  ) {
    final lower = body.toLowerCase();
    var confidence = base;
    if (_hasAny(lower, ['detected', 'recorded', 'observed', 'count', 't+'])) {
      confidence += 0.12;
    }
    if (_hasAny(lower, ['likely', 'may', 'tendency', 'profile', 'trait'])) {
      confidence -= 0.22;
    }
    if (category == DebriefInsightCategory.traitScenario ||
        category == DebriefInsightCategory.archetype) {
      confidence -= 0.12;
    }
    return confidence.clamp(0.2, 0.98).toDouble();
  }

  String _titleFor(String body, DebriefInsightCategory category) {
    final lower = body.toLowerCase();
    if (_hasAny(lower, ['separation loss', 'lost separation'])) {
      return 'Separation Risk';
    }
    if (_hasAny(lower, ['ignored', 'unattended'])) return 'Ignored Alert';
    if (lower.contains('tunnel')) return 'Attention Fixation';
    if (lower.contains('overload')) return 'Workload Spike';
    if (_hasAny(lower, ['runway', 'go-around'])) return 'Runway Flow Risk';
    if (_hasAny(lower, ['drift', 'mismatch', 'expectation'])) {
      return 'Expectation Drift';
    }
    if (_hasAny(lower, ['cascade', 'destabil'])) return 'Destabilisation';
    if (_hasAny(lower, ['forgotten', 'interrupted', 'follow-through'])) {
      return 'Task Follow-Through';
    }
    return switch (category) {
      DebriefInsightCategory.safety => 'Safety Insight',
      DebriefInsightCategory.workload => 'Workload Insight',
      DebriefInsightCategory.attention => 'Attention Insight',
      DebriefInsightCategory.workingMemory => 'Memory Insight',
      DebriefInsightCategory.predictiveModel => 'Prediction Insight',
      DebriefInsightCategory.cascade => 'Cascade Insight',
      DebriefInsightCategory.metaCognition => 'Self-Monitoring Insight',
      DebriefInsightCategory.archetype => 'Controller Profile',
      DebriefInsightCategory.traitScenario => 'Training Pattern',
      DebriefInsightCategory.recovery => 'Recovery Insight',
      DebriefInsightCategory.flow => 'Traffic Flow Insight',
    };
  }

  String _safeWording(String text) {
    return text
        .replaceAll(
            RegExp('caused by', caseSensitive: false), 'contributed to by')
        .replaceAll(RegExp('caused', caseSensitive: false), 'contributed to')
        .replaceAll(RegExp('cause', caseSensitive: false), 'contribute to');
  }

  String _dedupeKey(DebriefInsight insight) {
    final text = insight.body.toLowerCase();
    final normalized = text
        .replaceAll(RegExp(r'\bt\+\d+s\b'), '')
        .replaceAll(RegExp(r'\b\d+(\.\d+)?\b'), '')
        .replaceAll(RegExp(r'\b[A-Z]{2,}\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z ]'), ' ');
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 3 && !_stopWords.contains(word))
        .take(6)
        .join('-');
    return '${insight.category.name}:$words';
  }

  bool _isMostlyAbstract(DebriefInsight insight) {
    final lower = '${insight.title} ${insight.body}'.toLowerCase();
    return _hasAny(lower, [
          'archetype',
          'trait profile',
          'vulnerability',
          'confidence calibration',
          'degradation tendency',
        ]) &&
        !_hasAny(lower, ['separation', 'critical', 'runway']);
  }

  bool _overlapsLearningGoal(String lower, String learningGoal) {
    final terms = learningGoal
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((word) => word.length >= 5)
        .toSet();
    return terms.any(lower.contains);
  }

  Duration? _firstTimestamp(String body) {
    final match = RegExp(r'(?:T\+)?(\d+)s').firstMatch(body);
    if (match == null) return null;
    final seconds = int.tryParse(match.group(1)!);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  int _timestampSeconds(DebriefInsight insight) {
    return insight.timestamp?.inSeconds ?? 999999;
  }

  List<String> _aircraftIds(String body) {
    final matches = RegExp(r'\b[A-Z]{2,}\d{2,4}\b').allMatches(body);
    return matches.map((match) => match.group(0)!).toSet().toList()..sort();
  }

  bool _hasAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }
}

const _stopWords = {
  'after',
  'before',
  'during',
  'while',
  'with',
  'from',
  'that',
  'this',
  'were',
  'was',
  'into',
  'under',
  'detected',
  'observed',
};
