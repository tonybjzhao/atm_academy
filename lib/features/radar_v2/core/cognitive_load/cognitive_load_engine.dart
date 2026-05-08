import 'dart:collection';

import 'cognitive_load_level.dart';
import 'cognitive_load_state.dart';

/// Input data for a single cognitive load calculation.
///
/// All values are counts or scores derived from the current simulation
/// snapshot. The engine does not hold references to mutable objects.
class CognitiveLoadInputs {
  /// Number of active separation conflicts (actual or predicted ≤ 90s).
  final int unresolvedConflicts;

  /// Number of alerts currently active (any type).
  final int simultaneousAlerts;

  /// Active aircraft under control in the sector.
  final int activeAircraftCount;

  /// Departures queued and waiting for release.
  final int departureQueueSize;

  /// Runways currently occupied.
  final int occupiedRunwayCount;

  /// Sum of severity values across all active weather zones.
  final int weatherSeverityTotal;

  /// Aircraft that have executed a go-around this session.
  final int goAroundCount;

  /// Commands issued in the last 30 simulation seconds.
  final int recentCommandCount;

  /// Total escalation count across all active alerts.
  final int alertEscalationCount;

  const CognitiveLoadInputs({
    required this.unresolvedConflicts,
    required this.simultaneousAlerts,
    required this.activeAircraftCount,
    required this.departureQueueSize,
    required this.occupiedRunwayCount,
    required this.weatherSeverityTotal,
    required this.goAroundCount,
    required this.recentCommandCount,
    required this.alertEscalationCount,
  });

  static const CognitiveLoadInputs empty = CognitiveLoadInputs(
    unresolvedConflicts: 0,
    simultaneousAlerts: 0,
    activeAircraftCount: 0,
    departureQueueSize: 0,
    occupiedRunwayCount: 0,
    weatherSeverityTotal: 0,
    goAroundCount: 0,
    recentCommandCount: 0,
    alertEscalationCount: 0,
  );
}

/// Calculates controller cognitive workload from simulation inputs.
///
/// Stateless across calculations but maintains spike history between ticks.
/// Call [calculate] each tick, passing the current [CognitiveLoadInputs].
class CognitiveLoadEngine {
  static const int _maxSpikes = 10;
  static const Duration _spikeRetentionWindow = Duration(seconds: 90);

  final Queue<CognitiveLoadSpike> _spikeHistory = Queue();
  CognitiveLoadState _lastState = CognitiveLoadState.idle;

  CognitiveLoadState get lastState => _lastState;

  /// Calculates a new [CognitiveLoadState] from current simulation inputs.
  /// Retains spike history between calls.
  CognitiveLoadState calculate(
    CognitiveLoadInputs inputs,
    Duration elapsed,
  ) {
    double score = 0;
    final stressors = <String>[];

    // Conflicts — highest weight, each active conflict demands focus
    final conflictScore = inputs.unresolvedConflicts * 1.8;
    if (conflictScore > 0) {
      score += conflictScore;
      stressors.add(
        '${inputs.unresolvedConflicts} conflict${inputs.unresolvedConflicts > 1 ? 's' : ''}',
      );
    }

    // Simultaneous alerts compete for attention
    final alertScore = inputs.simultaneousAlerts * 0.8;
    if (alertScore > 0) {
      score += alertScore;
      stressors.add(
        '${inputs.simultaneousAlerts} active alert${inputs.simultaneousAlerts > 1 ? 's' : ''}',
      );
    }

    // Aircraft count relative to capacity (max load 6 is baseline neutral)
    final capacityRatio = inputs.activeAircraftCount / 6.0;
    final aircraftScore = (capacityRatio - 0.5).clamp(0.0, 2.5) * 1.6;
    if (aircraftScore > 0) {
      score += aircraftScore;
      stressors.add('${inputs.activeAircraftCount} aircraft on frequency');
    }

    // Departure queue backlog
    final queueScore = (inputs.departureQueueSize - 1).clamp(0, 4) * 0.5;
    if (queueScore > 0) {
      score += queueScore;
      stressors.add('${inputs.departureQueueSize} departures queued');
    }

    // Runway occupancy pressure
    final runwayScore = inputs.occupiedRunwayCount * 0.6;
    if (runwayScore > 0) {
      score += runwayScore;
      stressors.add(
        '${inputs.occupiedRunwayCount} runway${inputs.occupiedRunwayCount > 1 ? 's' : ''} occupied',
      );
    }

    // Weather complexity
    final weatherScore = (inputs.weatherSeverityTotal * 0.25).clamp(0.0, 2.0);
    if (weatherScore > 0) {
      score += weatherScore;
      stressors.add('Weather severity ${inputs.weatherSeverityTotal}');
    }

    // Go-arounds represent compound failures and spike attention cost
    final goAroundScore = inputs.goAroundCount * 0.9;
    if (goAroundScore > 0) {
      score += goAroundScore;
      stressors.add(
        '${inputs.goAroundCount} go-around${inputs.goAroundCount > 1 ? 's' : ''}',
      );
    }

    // Command burst indicates reactive scrambling, not proactive management
    final commandBurstScore =
        (inputs.recentCommandCount - 3).clamp(0, 5) * 0.35;
    if (commandBurstScore > 0) {
      score += commandBurstScore;
      stressors.add('${inputs.recentCommandCount} recent commands (burst)');
    }

    // Alert escalations: each escalation means unresolved urgency
    final escalationScore = inputs.alertEscalationCount * 0.4;
    if (escalationScore > 0) {
      score += escalationScore;
      stressors.add(
          '${inputs.alertEscalationCount} alert escalation${inputs.alertEscalationCount > 1 ? 's' : ''}');
    }

    score = score.clamp(0.0, 10.0);
    final level = CognitiveLoadLevel.fromScore(score);

    // Trim stressors list to top 5 most significant
    final topStressors = stressors.take(5).toList(growable: false);

    // Record spike if transitioning to/staying at overloaded+
    if (level.index >= CognitiveLoadLevel.overloaded.index) {
      _recordSpike(elapsed, score, level);
    }

    // Evict spikes outside retention window
    final cutoff = elapsed > _spikeRetentionWindow
        ? elapsed - _spikeRetentionWindow
        : Duration.zero;
    while (
        _spikeHistory.isNotEmpty && _spikeHistory.first.occurredAt < cutoff) {
      _spikeHistory.removeFirst();
    }

    _lastState = CognitiveLoadState(
      totalLoadScore: score,
      currentLevel: level,
      activeStressors: topStressors,
      recentSpikes: List<CognitiveLoadSpike>.unmodifiable(_spikeHistory),
    );
    return _lastState;
  }

  void _recordSpike(Duration elapsed, double score, CognitiveLoadLevel level) {
    // Merge with previous spike if within 5s to avoid flooding
    if (_spikeHistory.isNotEmpty) {
      final last = _spikeHistory.last;
      final gap = elapsed - last.occurredAt;
      if (gap.inSeconds < 5) {
        _spikeHistory.removeLast();
        _spikeHistory.addLast(CognitiveLoadSpike(
          occurredAt: last.occurredAt,
          peakScore: score > last.peakScore ? score : last.peakScore,
          level: level.index > last.level.index ? level : last.level,
        ));
        return;
      }
    }
    _spikeHistory.addLast(CognitiveLoadSpike(
        occurredAt: elapsed, peakScore: score, level: level));
    if (_spikeHistory.length > _maxSpikes) _spikeHistory.removeFirst();
  }

  /// Resets spike history (e.g., on scenario restart).
  void reset() {
    _spikeHistory.clear();
    _lastState = CognitiveLoadState.idle;
  }
}
