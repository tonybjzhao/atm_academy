/// Represents an active alert competing for controller attention.
///
/// In real terminal operations, multiple alerts can fire simultaneously
/// (conflict warning, weather escalation, runway occupancy, departure queue).
/// Controllers must prioritize and respond to the most urgent alert first.
/// This system simulates that cognitive competition for focus.
class ControllerAlert {
  /// Unique identifier for this alert.
  final String id;

  /// Type of alert affecting priority and escalation behavior.
  final AlertType type;

  /// Current severity of the alert (1–10, escalates over time).
  final int severity;

  /// Time at which this alert was generated.
  final Duration createdAt;

  /// Time until loss of separation or critical failure.
  /// If null, this is an informational alert (not time-critical).
  final Duration? timeToLoss;

  /// Aircraft involved (for separation, go-around, stability alerts).
  final List<String> aircraftIds;

  /// Runway involved (for runway occupancy, closure, mode change alerts).
  final String? runwayId;

  /// Whether the controller has acknowledged this alert.
  /// Acknowledged alerts don't escalate as aggressively.
  final bool acknowledged;

  /// Number of times this alert has escalated (visual/audio intensification).
  final int escalationCount;

  const ControllerAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.createdAt,
    this.timeToLoss,
    this.aircraftIds = const [],
    this.runwayId,
    this.acknowledged = false,
    this.escalationCount = 0,
  });

  /// Returns effective priority used for alert ordering.
  /// Higher = more urgent, should be addressed first.
  int get effectivePriority {
    var priority = _baseTypeWeight(type) * 10;
    priority += severity; // 1–10 points for severity
    if (timeToLoss != null) {
      final seconds = timeToLoss!.inSeconds;
      if (seconds < 30)
        priority += 50; // Imminent
      else if (seconds < 60)
        priority += 30; // Soon
      else if (seconds < 120) priority += 15; // Moderate urgency
    }
    if (!acknowledged) priority += 10; // Unacknowledged adds urgency
    return priority;
  }

  /// Base weight for alert type (0–10 scale, used in priority calc).
  int _baseTypeWeight(AlertType type) {
    switch (type) {
      case AlertType.separationLoss:
        return 10; // Highest: immediate loss
      case AlertType.goAround:
        return 9; // Near-highest: runway blocked
      case AlertType.unstableApproach:
        return 8;
      case AlertType.weatherEscalation:
        return 6;
      case AlertType.runwayOccupancy:
        return 7;
      case AlertType.departureQueueBacklog:
        return 5;
      case AlertType.lowFuelWarning:
        return 7;
      case AlertType.medicalEmergency:
        return 9;
      case AlertType.distractionEvent:
        return 3; // Lowest priority
    }
  }

  ControllerAlert copyWith({
    String? id,
    AlertType? type,
    int? severity,
    Duration? createdAt,
    Duration? timeToLoss,
    List<String>? aircraftIds,
    String? runwayId,
    bool? acknowledged,
    int? escalationCount,
  }) =>
      ControllerAlert(
        id: id ?? this.id,
        type: type ?? this.type,
        severity: severity ?? this.severity,
        createdAt: createdAt ?? this.createdAt,
        timeToLoss: timeToLoss ?? this.timeToLoss,
        aircraftIds: aircraftIds ?? this.aircraftIds,
        runwayId: runwayId ?? this.runwayId,
        acknowledged: acknowledged ?? this.acknowledged,
        escalationCount: escalationCount ?? this.escalationCount,
      );

  @override
  String toString() =>
      'ControllerAlert($type, severity=$severity, priority=$effectivePriority)';
}

/// Types of alerts that compete for controller attention.
enum AlertType {
  /// Imminent loss of separation between two aircraft.
  separationLoss,

  /// Go-around required (runway occupied, unstable pair, etc).
  goAround,

  /// Aircraft not stabilized on final approach.
  unstableApproach,

  /// Weather intensity increasing or expanding.
  weatherEscalation,

  /// Runway occupied and aircraft approaching.
  runwayOccupancy,

  /// Too many departures queued, release rate behind.
  departureQueueBacklog,

  /// Aircraft fuel critically low.
  lowFuelWarning,

  /// Medical emergency requiring priority handling.
  medicalEmergency,

  /// Distraction event (radio chatter, false alert, etc).
  distractionEvent,
}
