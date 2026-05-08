import 'alert_priority.dart';

/// A single operational alert in the controller's attention queue.
///
/// [OperationalAlert] is the richer, higher-level alert abstraction used by
/// the Decision Pressure Engine. It carries workload impact, expiry semantics,
/// and a type-safe priority tier distinct from the legacy [ControllerAlert].
class OperationalAlert {
  /// Unique identifier for this alert instance.
  final String id;

  /// Alert type string — use [OperationalAlertType] constants.
  final String type;

  /// Urgency tier driving sort order, visual treatment, and audio cues.
  final AlertPriority priority;

  /// Simulation elapsed time when this alert was created.
  final Duration createdAt;

  /// Optional expiry time — null means the alert persists until manually cleared.
  final Duration? expiresAt;

  /// Workload contribution score (1–10) added to the cognitive load calculation.
  final int workloadImpact;

  /// Whether the controller has acknowledged this alert.
  final bool acknowledged;

  /// IDs of aircraft involved in or related to this alert.
  final List<String> relatedAircraftIds;

  /// Optional runway identifier relevant to the alert.
  final String? relatedRunwayId;

  const OperationalAlert({
    required this.id,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.expiresAt,
    required this.workloadImpact,
    this.acknowledged = false,
    this.relatedAircraftIds = const [],
    this.relatedRunwayId,
  });

  /// Returns true if this alert has passed its expiry time.
  bool isExpiredAt(Duration elapsed) =>
      expiresAt != null && elapsed >= expiresAt!;

  /// Composite urgency value for sorting — higher = more urgent.
  /// Combines priority weight, workload impact, and acknowledgement state.
  int get urgencyScore {
    var score = priority.sortWeight * 100;
    score += workloadImpact * 5;
    if (!acknowledged) score += 20;
    return score;
  }

  OperationalAlert copyWith({
    String? id,
    String? type,
    AlertPriority? priority,
    Duration? createdAt,
    Duration? expiresAt,
    int? workloadImpact,
    bool? acknowledged,
    List<String>? relatedAircraftIds,
    String? relatedRunwayId,
  }) =>
      OperationalAlert(
        id: id ?? this.id,
        type: type ?? this.type,
        priority: priority ?? this.priority,
        createdAt: createdAt ?? this.createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        workloadImpact: workloadImpact ?? this.workloadImpact,
        acknowledged: acknowledged ?? this.acknowledged,
        relatedAircraftIds: relatedAircraftIds ?? this.relatedAircraftIds,
        relatedRunwayId: relatedRunwayId ?? this.relatedRunwayId,
      );

  @override
  String toString() =>
      'OperationalAlert($type, ${priority.label}, impact=$workloadImpact)';
}
