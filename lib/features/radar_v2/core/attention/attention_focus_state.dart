import '../alerts/alert_priority.dart';

enum AttentionRiskLevel {
  normal,
  fixationRisk,
  tunnelVision,
  criticalFixation,
}

class IgnoredAlertSnapshot {
  final String alertId;
  final String alertType;
  final AlertPriority priority;
  final Duration ignoredFor;
  final int severity;
  final List<String> relatedAircraftIds;
  final String? relatedRunwayId;

  const IgnoredAlertSnapshot({
    required this.alertId,
    required this.alertType,
    required this.priority,
    required this.ignoredFor,
    required this.severity,
    this.relatedAircraftIds = const [],
    this.relatedRunwayId,
  });

  bool get isCritical => priority == AlertPriority.critical || severity >= 4;
}

class AttentionFocusState {
  final String? currentFocusTarget;
  final Duration focusDuration;
  final List<IgnoredAlertSnapshot> ignoredAlerts;
  final int competingHighPriorityAlertCount;
  final int recentFocusedCommandCount;
  final Duration overloadDuration;
  final AttentionRiskLevel riskLevel;
  final List<String> reportLines;

  const AttentionFocusState({
    this.currentFocusTarget,
    this.focusDuration = Duration.zero,
    this.ignoredAlerts = const [],
    this.competingHighPriorityAlertCount = 0,
    this.recentFocusedCommandCount = 0,
    this.overloadDuration = Duration.zero,
    this.riskLevel = AttentionRiskLevel.normal,
    this.reportLines = const [],
  });

  static const AttentionFocusState idle = AttentionFocusState();

  IgnoredAlertSnapshot? get topIgnoredAlert {
    if (ignoredAlerts.isEmpty) return null;
    return ignoredAlerts.reduce((a, b) {
      if (a.severity != b.severity) {
        return a.severity > b.severity ? a : b;
      }
      return a.ignoredFor > b.ignoredFor ? a : b;
    });
  }

  int get ignoredCriticalCount =>
      ignoredAlerts.where((alert) => alert.isCritical).length;

  bool get suppressLowPriorityAlerts =>
      riskLevel == AttentionRiskLevel.tunnelVision ||
      riskLevel == AttentionRiskLevel.criticalFixation;

  String get riskLabel => switch (riskLevel) {
        AttentionRiskLevel.normal => 'normal',
        AttentionRiskLevel.fixationRisk => 'fixation risk',
        AttentionRiskLevel.tunnelVision => 'tunnel vision',
        AttentionRiskLevel.criticalFixation => 'critical fixation',
      };
}
