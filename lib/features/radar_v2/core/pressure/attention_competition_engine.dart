import 'dart:math' as math;

import '../alerts/alert_priority.dart';
import '../alerts/operational_alert.dart';

/// Outcome of an attention competition evaluation for a single tick.
class AttentionCompetitionResult {
  /// Alerts that should escalate faster this tick due to competition.
  final List<String> escalatingAlertIds;

  /// Alert types effectively being ignored due to attention overload.
  final List<String> ignoredAlertTypes;

  /// True when low-priority tasks are being suppressed by high-priority demand.
  final bool lowPrioritySuppressionActive;

  /// Estimated queue build-up acceleration factor (≥1.0).
  /// 1.0 = normal pace, >1.0 = departures queue faster.
  final double queueBuildupAcceleration;

  /// Aggregate attention budget (0–1).
  /// 0 = fully saturated, 1 = full capacity available.
  final double remainingAttentionBudget;

  const AttentionCompetitionResult({
    required this.escalatingAlertIds,
    required this.ignoredAlertTypes,
    required this.lowPrioritySuppressionActive,
    required this.queueBuildupAcceleration,
    required this.remainingAttentionBudget,
  });

  static const AttentionCompetitionResult idle = AttentionCompetitionResult(
    escalatingAlertIds: [],
    ignoredAlertTypes: [],
    lowPrioritySuppressionActive: false,
    queueBuildupAcceleration: 1.0,
    remainingAttentionBudget: 1.0,
  );
}

/// Simulates how simultaneous high-priority alerts compete for the controller's
/// limited attention bandwidth.
///
/// When attention is saturated:
///  - unresolved high/critical alerts escalate at an accelerated rate
///  - low-priority tasks are suppressed (ignored)
///  - departure queue buildup accelerates
///
/// This engine is stateless per tick — call [evaluate] with the current alert
/// list each simulation step.
class AttentionCompetitionEngine {
  /// Maximum simultaneous alerts a controller can fully attend to.
  static const int _fullAttentionCapacity = 3;

  /// Weight consumed per alert priority level.
  static const Map<AlertPriority, double> _attentionWeight = {
    AlertPriority.critical: 0.40,
    AlertPriority.high: 0.25,
    AlertPriority.medium: 0.12,
    AlertPriority.low: 0.05,
  };

  /// Evaluates attention competition from the current list of active alerts.
  ///
  /// [activeAlerts] should be ordered by urgency (most urgent first).
  /// [recentCommandCount] is the number of commands in the last 30s.
  AttentionCompetitionResult evaluate({
    required List<OperationalAlert> activeAlerts,
    required int recentCommandCount,
  }) {
    if (activeAlerts.isEmpty) return AttentionCompetitionResult.idle;

    // Calculate consumed attention budget
    double consumed = 0;
    for (final alert in activeAlerts) {
      consumed += _attentionWeight[alert.priority] ?? 0.05;
    }
    // Command burst adds cognitive overhead
    consumed += (recentCommandCount * 0.04).clamp(0, 0.3);
    consumed = consumed.clamp(0, 1.0);
    final remaining = 1.0 - consumed;

    final escalatingIds = <String>[];
    final ignoredTypes = <String>{};
    var lowPrioritySuppressionActive = false;

    if (remaining < 0.5) {
      // Attention is strained — unresolved high/critical alerts escalate
      for (final alert in activeAlerts) {
        if (!alert.acknowledged &&
            (alert.priority == AlertPriority.critical ||
                alert.priority == AlertPriority.high)) {
          escalatingIds.add(alert.id);
        }
      }
    }

    if (remaining < 0.25) {
      // Critically low — low-priority tasks get dropped
      lowPrioritySuppressionActive = true;
      for (final alert in activeAlerts) {
        if (alert.priority == AlertPriority.low ||
            alert.priority == AlertPriority.medium) {
          ignoredTypes.add(alert.type);
        }
      }
    }

    // Queue acceleration scales from 1.0 (no pressure) to 2.5 (saturated)
    final criticalCount = activeAlerts
        .where((a) => a.priority == AlertPriority.critical && !a.acknowledged)
        .length;
    final highCount = activeAlerts
        .where((a) => a.priority == AlertPriority.high && !a.acknowledged)
        .length;
    final queueAcceleration = 1.0 +
        (criticalCount * 0.4) +
        (highCount * 0.15) +
        math.max(0, activeAlerts.length - _fullAttentionCapacity) * 0.1;

    return AttentionCompetitionResult(
      escalatingAlertIds: escalatingIds,
      ignoredAlertTypes: List<String>.unmodifiable(ignoredTypes.toList()),
      lowPrioritySuppressionActive: lowPrioritySuppressionActive,
      queueBuildupAcceleration: queueAcceleration.clamp(1.0, 3.0),
      remainingAttentionBudget: remaining,
    );
  }
}
