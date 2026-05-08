/// Represents a controller distraction or attention-management challenge event.
///
/// These events occur during high-pressure periods and challenge the controller's
/// ability to focus and maintain situational awareness. Examples include:
/// - Distraction events (radio chatter, irrelevant alerts)
/// - Simultaneous conflicts (multiple alerts at once)
/// - Runway change requests (must reassign operations mid-scenario)
/// - Weather escalation (conditions worsen unexpectedly)
class AttentionManagementEvent {
  /// Unique identifier for this event.
  final String id;

  /// Type of event: distraction, simultaneous_alerts, runway_change, weather_escalation
  final String type;

  /// Time at which this event should fire.
  final Duration scheduledAt;

  /// Duration for which the distraction persists (e.g., radio chatter duration).
  final Duration? duration;

  /// For runway_change events: the runway to reassign to.
  final String? targetRunwayId;

  /// For weather_escalation events: the additional severity to apply.
  final int? severityIncrease;

  /// Event description for logging/debugging.
  final String description;

  const AttentionManagementEvent({
    required this.id,
    required this.type,
    required this.scheduledAt,
    this.duration,
    this.targetRunwayId,
    this.severityIncrease,
    this.description = '',
  });

  @override
  String toString() => 'AttentionManagementEvent($type @ $scheduledAt)';
}

/// Event type constants.
class AttentionEventTypes {
  static const String distraction = 'distraction';
  static const String simultaneousAlerts = 'simultaneous_alerts';
  static const String runwayChange = 'runway_change';
  static const String weatherEscalation = 'weather_escalation';
}
