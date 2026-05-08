import '../commands/controller_command.dart';
import '../models/controller_alert.dart';
import '../models/simulation_snapshot.dart';

/// A single recorded controller action: command issued at a specific simulation time.
class ControllerAction {
  final Duration elapsed;
  final ControllerCommand command;
  final String aircraftId;
  final AlertType? respondingToAlert;
  final double sectorPressureAtTime;

  const ControllerAction({
    required this.elapsed,
    required this.command,
    required this.aircraftId,
    this.respondingToAlert,
    this.sectorPressureAtTime = 0,
  });
}

/// Tracks a single alert lifecycle for replay analysis.
class AlertLifecycle {
  final String alertId;
  final AlertType alertType;
  final Duration firedAt;
  final double priorityAtFire;
  final List<String> involvedAircraftIds;
  Duration? firstCommandAt;
  Duration? resolvedAt;
  int commandsIssuedDuringAlert = 0;

  AlertLifecycle({
    required this.alertId,
    required this.alertType,
    required this.firedAt,
    required this.priorityAtFire,
    required this.involvedAircraftIds,
  });

  /// Time from alert fire to first controller action (null if no action taken).
  Duration? get reactionLatency =>
      firstCommandAt != null ? firstCommandAt! - firedAt : null;

  /// Whether alert was resolved (null = unresolved, Duration = how long it was active).
  Duration? get activeDuration =>
      resolvedAt != null ? resolvedAt! - firedAt : null;

  bool get wasResolved => resolvedAt != null;
  bool get hadNoResponse => firstCommandAt == null;
}

/// Summary of controller behavior patterns from a completed session.
class CognitiveReplayReport {
  /// Total commands issued during the session.
  final int totalCommands;

  /// Average reaction latency from alert to first command (seconds).
  final double averageReactionLatencySeconds;

  /// Number of alerts that received no controller response.
  final int unaddressedAlerts;

  /// Number of alerts resolved before worst-case timeline.
  final int proactiveResolutions;

  /// Peak command rate (commands per minute) — high values indicate panic.
  final double peakCommandRatePerMinute;

  /// Average commands per alert episode.
  final double averageCommandsPerAlert;

  /// Longest gap (seconds) between commands when alerts were active.
  final double longestInactivityWithAlertSeconds;

  /// Ordered breakdown of alert types and how quickly controller responded.
  final List<AlertReactionRecord> alertBreakdown;

  /// Detected pressure spikes (seconds into session) where behavior changed.
  final List<Duration> pressureSpikes;

  /// Overall controller quality score (0–100).
  final int compositeScore;

  const CognitiveReplayReport({
    required this.totalCommands,
    required this.averageReactionLatencySeconds,
    required this.unaddressedAlerts,
    required this.proactiveResolutions,
    required this.peakCommandRatePerMinute,
    required this.averageCommandsPerAlert,
    required this.longestInactivityWithAlertSeconds,
    required this.alertBreakdown,
    required this.pressureSpikes,
    required this.compositeScore,
  });

  String get compositeGrade {
    if (compositeScore >= 90) return 'A';
    if (compositeScore >= 75) return 'B';
    if (compositeScore >= 60) return 'C';
    return 'D';
  }
}

/// Record of controller response to a specific alert type.
class AlertReactionRecord {
  final AlertType alertType;
  final int count;
  final double averageReactionSeconds;
  final int unresponsiveCount;

  const AlertReactionRecord({
    required this.alertType,
    required this.count,
    required this.averageReactionSeconds,
    required this.unresponsiveCount,
  });
}

/// Collects behavioral data during a simulation session and generates
/// a post-session cognitive replay report.
class CognitiveReplayTracker {
  final List<ControllerAction> _actions = [];
  final Map<String, AlertLifecycle> _alertLifecycles = {};
  final List<Duration> _commandTimestamps = [];

  /// Records a command issued by the controller.
  void recordCommand(
    ControllerCommand command,
    SimulationSnapshot snapshot,
  ) {
    final elapsed = snapshot.elapsed;
    _commandTimestamps.add(elapsed);

    // Find which alert (if any) this command is responding to
    AlertType? respondingTo;
    for (final alert in snapshot.activeAlerts) {
      if (alert.aircraftIds.contains(command.aircraftId)) {
        respondingTo = alert.type;
        final lifecycle = _alertLifecycles[alert.id];
        if (lifecycle != null) {
          lifecycle.firstCommandAt ??= elapsed;
          lifecycle.commandsIssuedDuringAlert += 1;
        }
        break;
      }
    }

    _actions.add(ControllerAction(
      elapsed: elapsed,
      command: command,
      aircraftId: command.aircraftId,
      respondingToAlert: respondingTo,
      sectorPressureAtTime: snapshot.sectorPressureIndex,
    ));
  }

  /// Observes a simulation snapshot to track alert lifecycles.
  void observe(SimulationSnapshot snapshot) {
    // Track new alerts
    for (final alert in snapshot.activeAlerts) {
      if (!_alertLifecycles.containsKey(alert.id)) {
        _alertLifecycles[alert.id] = AlertLifecycle(
          alertId: alert.id,
          alertType: alert.type,
          firedAt: snapshot.elapsed,
          priorityAtFire: alert.effectivePriority.toDouble(),
          involvedAircraftIds: List<String>.from(alert.aircraftIds),
        );
      }
    }

    // Detect resolved alerts (no longer in active alerts)
    final activeIds = snapshot.activeAlerts.map((a) => a.id).toSet();
    for (final lifecycle in _alertLifecycles.values) {
      if (!lifecycle.wasResolved && !activeIds.contains(lifecycle.alertId)) {
        lifecycle.resolvedAt = snapshot.elapsed;
      }
    }
  }

  /// Generates the cognitive replay report from collected data.
  CognitiveReplayReport generateReport() {
    final totalCommands = _commandTimestamps.length;
    final lifecycles = _alertLifecycles.values.toList();

    // Reaction latency
    final latencies = lifecycles
        .map((l) => l.reactionLatency?.inMilliseconds.toDouble())
        .whereType<double>()
        .toList();
    final avgReactionSecs = latencies.isEmpty
        ? 0.0
        : latencies.reduce((a, b) => a + b) / latencies.length / 1000.0;

    // Unaddressed alerts
    final unaddressed = lifecycles.where((l) => l.hadNoResponse).length;

    // Proactive resolutions (resolved within 45 seconds of firing)
    final proactive = lifecycles
        .where(
            (l) => l.wasResolved && (l.activeDuration?.inSeconds ?? 999) <= 45)
        .length;

    // Peak command rate (60-second sliding window)
    final peakRate = _calculatePeakCommandRate();

    // Average commands per alert
    final alertsWithCommands = lifecycles.where((l) => !l.hadNoResponse);
    final avgCmdsPerAlert = alertsWithCommands.isEmpty
        ? 0.0
        : alertsWithCommands
                .map((l) => l.commandsIssuedDuringAlert.toDouble())
                .reduce((a, b) => a + b) /
            alertsWithCommands.length;

    // Longest inactivity with active alerts
    final longestInactivity = _calculateLongestInactivity();

    // Alert breakdown by type
    final alertBreakdown = _buildAlertBreakdown(lifecycles);

    // Pressure spikes (periods where pressure > 3.0 and commands accelerated)
    final pressureSpikes = _detectPressureSpikes();

    // Composite score
    final compositeScore = _calculateCompositeScore(
        avgReactionSecs, unaddressed, proactive, peakRate);

    return CognitiveReplayReport(
      totalCommands: totalCommands,
      averageReactionLatencySeconds: avgReactionSecs,
      unaddressedAlerts: unaddressed,
      proactiveResolutions: proactive,
      peakCommandRatePerMinute: peakRate,
      averageCommandsPerAlert: avgCmdsPerAlert,
      longestInactivityWithAlertSeconds: longestInactivity,
      alertBreakdown: alertBreakdown,
      pressureSpikes: pressureSpikes,
      compositeScore: compositeScore,
    );
  }

  double _calculatePeakCommandRate() {
    if (_commandTimestamps.length < 2) return 0;
    var peak = 0.0;
    for (var i = 0; i < _commandTimestamps.length; i++) {
      final windowStart = _commandTimestamps[i];
      final windowEnd = windowStart + const Duration(seconds: 60);
      var count = 0;
      for (var j = i; j < _commandTimestamps.length; j++) {
        if (_commandTimestamps[j] > windowEnd) break;
        count++;
      }
      final rate = count.toDouble();
      if (rate > peak) peak = rate;
    }
    return peak; // commands per 60s window = per minute
  }

  double _calculateLongestInactivity() {
    if (_commandTimestamps.length < 2) return 0;
    var longestMs = 0;
    for (var i = 1; i < _commandTimestamps.length; i++) {
      final prev = _commandTimestamps[i - 1];
      final curr = _commandTimestamps[i];
      final gapMs = (curr - prev).inMilliseconds;

      // Only count gaps where there were active alerts during the period
      final alertsActiveDuringGap = _alertLifecycles.values.any((l) =>
          l.firedAt <= curr && (l.resolvedAt == null || l.resolvedAt! >= prev));

      if (alertsActiveDuringGap && gapMs > longestMs) {
        longestMs = gapMs;
      }
    }
    return longestMs / 1000.0;
  }

  List<AlertReactionRecord> _buildAlertBreakdown(
      List<AlertLifecycle> lifecycles) {
    final Map<AlertType, List<AlertLifecycle>> byType = {};
    for (final lifecycle in lifecycles) {
      byType.putIfAbsent(lifecycle.alertType, () => []).add(lifecycle);
    }
    return byType.entries.map((entry) {
      final ls = entry.value;
      final responded = ls.where((l) => !l.hadNoResponse).toList();
      final avgLatency = responded.isEmpty
          ? 0.0
          : responded
                  .map((l) =>
                      l.reactionLatency!.inMilliseconds.toDouble() / 1000.0)
                  .reduce((a, b) => a + b) /
              responded.length;
      return AlertReactionRecord(
        alertType: entry.key,
        count: ls.length,
        averageReactionSeconds: avgLatency,
        unresponsiveCount: ls.where((l) => l.hadNoResponse).length,
      );
    }).toList()
      ..sort((a, b) => a.alertType.index.compareTo(b.alertType.index));
  }

  List<Duration> _detectPressureSpikes() {
    // Find time windows where command rate suddenly increased (> 5 cmds in 15s)
    final spikes = <Duration>[];
    for (var i = 0; i < _commandTimestamps.length; i++) {
      final windowStart = _commandTimestamps[i];
      final windowEnd = windowStart + const Duration(seconds: 15);
      var count = 0;
      for (var j = i; j < _commandTimestamps.length; j++) {
        if (_commandTimestamps[j] > windowEnd) break;
        count++;
      }
      if (count >= 5 &&
          (spikes.isEmpty ||
              windowStart - spikes.last > const Duration(seconds: 30))) {
        spikes.add(windowStart);
      }
    }
    return spikes;
  }

  int _calculateCompositeScore(
    double avgReactionSecs,
    int unaddressed,
    int proactive,
    double peakRate,
  ) {
    var score = 100;

    // Penalize slow average reaction
    if (avgReactionSecs > 30) {
      score -= 20;
    } else if (avgReactionSecs > 20) {
      score -= 10;
    } else if (avgReactionSecs > 10) {
      score -= 5;
    }

    // Penalize unaddressed alerts
    score -= unaddressed * 8;

    // Reward proactive resolutions
    score += (proactive * 3).clamp(0, 15);

    // Penalize panic command clusters
    if (peakRate > 15) {
      score -= 15;
    } else if (peakRate > 10) {
      score -= 8;
    } else if (peakRate > 6) {
      score -= 3;
    }

    return score.clamp(0, 100);
  }
}
